#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
INSTALL_DIR="/opt/auto-ip"
CONFIG_DIR="/etc/auto-ip"
LOG_DIR="/var/log/auto-ip"
TOR_DROPIN_DIR="/etc/tor/torrc.d"
TOR_DROPIN_FILE="${TOR_DROPIN_DIR}/auto-ip.conf"
COUNTRY_FILE="${TOR_DROPIN_DIR}/auto-ip-country.conf"
SYSCTL_FILE="/etc/sysctl.d/99-auto-ip-ipv6.conf"
SERVICE_TARGET="/etc/systemd/system/auto-ip-rotator.service"
CLI_TARGET="/usr/local/bin/auto-ip"
MAIN_TARGET="/usr/local/bin/torloom"
DEPS=(tor curl jq proxychains4 nftables netcat-openbsd)

step() {
  echo "[$1/9] $2"
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./setup.sh"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer currently supports apt-based distros (Kali/Debian)."
  exit 1
fi

pick_country() {
  echo >&2
  echo "Select exit country profile:" >&2
  echo "1) USA" >&2
  echo "2) Germany" >&2
  echo "3) Netherlands" >&2
  echo "4) Japan" >&2
  echo "5) Random (default Tor behavior)" >&2
  read -r -p "Choice [1-5]: " selection

  case "${selection:-5}" in
    1) printf "%s\n" "US" ;;
    2) printf "%s\n" "DE" ;;
    3) printf "%s\n" "NL" ;;
    4) printf "%s\n" "JP" ;;
    *) printf "%s\n" "RANDOM" ;;
  esac
}

write_country_file() {
  local code="$1"
  if [[ "${code}" == "RANDOM" ]]; then
    cat >"${COUNTRY_FILE}" <<'EOF'
# Managed by auto-ip setup
# Country pinning disabled (random Tor exit nodes)
EOF
  else
    cat >"${COUNTRY_FILE}" <<EOF
# Managed by auto-ip setup
ExitNodes {${code,,}}
StrictNodes 1
EOF
  fi
}

detect_tor_service() {
  if systemctl is-active --quiet tor@default 2>/dev/null; then
    echo "tor@default"
  elif systemctl is-active --quiet tor 2>/dev/null; then
    echo "tor"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^tor@default.service"; then
    echo "tor@default"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^tor.service"; then
    echo "tor"
  else
    echo "tor"
  fi
}

detect_tor_group() {
  if getent group debian-tor >/dev/null 2>&1; then
    echo "debian-tor"
  elif getent group tor >/dev/null 2>&1; then
    echo "tor"
  else
    echo "debian-tor"
  fi
}

resolve_home_dir() {
  local user_name="$1"
  local home_dir
  home_dir="$(getent passwd "${user_name}" | cut -d: -f6 || true)"
  if [[ -n "${home_dir}" && -d "${home_dir}" ]]; then
    printf "%s\n" "${home_dir}"
    return 0
  fi
  return 1
}

run_verify_check() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "    [OK] ${description}"
    return 0
  fi
  echo "    [FAIL] ${description}"
  return 1
}

wait_for_tor_socks() {
  local timeout=30
  local elapsed=0
  while (( elapsed < timeout )); do
    if curl --socks5-hostname 127.0.0.1:9050 -fsS --max-time 10 https://api.ipify.org >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    ((elapsed++))
  done
  return 1
}

install_dependencies() {
  local missing=()
  local dep
  for dep in "${DEPS[@]}"; do
    if ! dpkg -s "${dep}" >/dev/null 2>&1; then
      missing+=("${dep}")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    echo "All dependencies already installed."
    return 0
  fi

  echo "Installing missing packages: ${missing[*]}"
  apt-get update
  apt-get install -y "${missing[@]}"
}

install_project_files() {
  install -d -m 0755 "${INSTALL_DIR}/app" "${INSTALL_DIR}/lib" "${INSTALL_DIR}/firewall" "${INSTALL_DIR}/configs" "${INSTALL_DIR}/systemd" "${INSTALL_DIR}/docs" "${INSTALL_DIR}/docs/assets"

  install -m 0755 "${ROOT_DIR}/setup.sh" "${INSTALL_DIR}/setup.sh"
  install -m 0755 "${ROOT_DIR}/torloom.sh" "${INSTALL_DIR}/torloom.sh"
  install -m 0755 "${ROOT_DIR}/app/change_tor_ip.sh" "${INSTALL_DIR}/app/change_tor_ip.sh"
  install -m 0755 "${ROOT_DIR}/app/healthcheck.sh" "${INSTALL_DIR}/app/healthcheck.sh"
  install -m 0755 "${ROOT_DIR}/app/leak_test.sh" "${INSTALL_DIR}/app/leak_test.sh"
  install -m 0755 "${ROOT_DIR}/app/auto_ip_cli.sh" "${INSTALL_DIR}/app/auto_ip_cli.sh"
  install -m 0755 "${ROOT_DIR}/app/ip-changer.sh" "${INSTALL_DIR}/app/ip-changer.sh"
  install -m 0755 "${ROOT_DIR}/uninstall.sh" "${INSTALL_DIR}/uninstall.sh"

  install -m 0644 "${ROOT_DIR}/lib/common.sh" "${INSTALL_DIR}/lib/common.sh"
  install -m 0755 "${ROOT_DIR}/firewall/apply_killswitch.sh" "${INSTALL_DIR}/firewall/apply_killswitch.sh"
  install -m 0755 "${ROOT_DIR}/firewall/remove_killswitch.sh" "${INSTALL_DIR}/firewall/remove_killswitch.sh"
  install -m 0644 "${ROOT_DIR}/firewall/tor-killswitch.nft" "${INSTALL_DIR}/firewall/tor-killswitch.nft"
  install -m 0644 "${ROOT_DIR}/configs/torrc.template" "${INSTALL_DIR}/configs/torrc.template"
  install -m 0644 "${ROOT_DIR}/configs/proxychains4.conf.template" "${INSTALL_DIR}/configs/proxychains4.conf.template"
  install -m 0644 "${ROOT_DIR}/configs/auto-ip.conf.template" "${INSTALL_DIR}/configs/auto-ip.conf.template"
  install -m 0644 "${ROOT_DIR}/systemd/auto-ip-rotator.service" "${INSTALL_DIR}/systemd/auto-ip-rotator.service"
  install -m 0644 "${ROOT_DIR}/README.md" "${INSTALL_DIR}/README.md"
  install -m 0644 "${ROOT_DIR}/docs/MANUAL.md" "${INSTALL_DIR}/docs/MANUAL.md"
  install -m 0644 "${ROOT_DIR}/docs/assets/autoip-sticker.svg" "${INSTALL_DIR}/docs/assets/autoip-sticker.svg"
}

verify_installation() {
  local failures=0
  local tor_service
  tor_service="$(detect_tor_service)"

  echo "[9/9] Running post-install verification..."
  run_verify_check "Tor service is active" systemctl is-active --quiet "${tor_service}" || failures=1
  run_verify_check "Config preflight passes" "${INSTALL_DIR}/app/change_tor_ip.sh" --validate-config || failures=1
  run_verify_check "Tor config syntax passes" tor --verify-config || failures=1
  run_verify_check "Tor SOCKS warm-up complete" wait_for_tor_socks || failures=1
  run_verify_check "Tor SOCKS proxy works" curl --socks5-hostname 127.0.0.1:9050 -fsS --max-time 20 https://api.ipify.org || failures=1
  run_verify_check "DNS path works via Tor" curl --socks5-hostname 127.0.0.1:9050 -fsS --max-time 20 https://dnsleaktest.com || failures=1
  if grep -q '^ENABLE_FIREWALL=1' "${CONFIG_DIR}/auto-ip.conf"; then
    run_verify_check "nftables kill switch loaded" nft list table inet auto_ip || failures=1
  else
    echo "    [SKIP] nftables kill switch check (ENABLE_FIREWALL=0)"
  fi

  if (( failures != 0 )); then
    echo "Post-install verification failed. Check logs and fix issues before production use."
    exit 1
  fi
}

step 1 "Installing dependencies..."
install_dependencies

step 2 "Creating runtime directories..."
mkdir -p "${LOG_DIR}" "${CONFIG_DIR}" "${INSTALL_DIR}"
touch "${LOG_DIR}/errors.log" "${LOG_DIR}/rotations.log" "${LOG_DIR}/tor-status.log"
chmod 770 "${LOG_DIR}"

step 3 "Installing repo files to ${INSTALL_DIR}..."
install_project_files

step 4 "Applying Tor DNS leak protection config..."
mkdir -p "${TOR_DROPIN_DIR}"
cp "${ROOT_DIR}/configs/torrc.template" "${TOR_DROPIN_FILE}"

EXIT_COUNTRY="$(pick_country)"
EXIT_COUNTRY="${EXIT_COUNTRY//$'\r'/}"
case "${EXIT_COUNTRY}" in
  US|DE|NL|JP|RANDOM) ;;
  *)
    echo "Invalid country selection output: ${EXIT_COUNTRY}"
    exit 1
    ;;
esac
write_country_file "${EXIT_COUNTRY}"

cp "${ROOT_DIR}/configs/auto-ip.conf.template" "${CONFIG_DIR}/auto-ip.conf"
sed -i "s/^EXIT_COUNTRY=.*/EXIT_COUNTRY=${EXIT_COUNTRY}/" "${CONFIG_DIR}/auto-ip.conf"

step 5 "Applying IPv6 leak protection..."
cat >"${SYSCTL_FILE}" <<'EOF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sysctl --system >/dev/null

step 6 "Configuring proxychains..."
if [[ -f /etc/proxychains4.conf ]]; then
  cp /etc/proxychains4.conf /etc/proxychains4.conf.bak.auto-ip
fi
cp "${ROOT_DIR}/configs/proxychains4.conf.template" /etc/proxychains4.conf

step 7 "Installing and enabling service..."
cp "${ROOT_DIR}/systemd/auto-ip-rotator.service" "${SERVICE_TARGET}"
ln -sf "${INSTALL_DIR}/torloom.sh" "${MAIN_TARGET}"
ln -sf "${INSTALL_DIR}/torloom.sh" "${CLI_TARGET}"
ln -sf "${INSTALL_DIR}/torloom.sh" /usr/local/bin/ip-changer
ln -sf "${INSTALL_DIR}/torloom.sh" /usr/local/bin/auto-ip-rotate
ln -sf "${INSTALL_DIR}/torloom.sh" /usr/local/bin/auto-ip-health
ln -sf "${INSTALL_DIR}/torloom.sh" /usr/local/bin/auto-ip-leaktest
systemctl daemon-reload
TOR_SERVICE="$(detect_tor_service)"
if ! tor --verify-config >/dev/null 2>&1; then
  echo "Invalid Tor configuration detected. Run: tor --verify-config"
  exit 1
fi
if systemctl is-active --quiet "${TOR_SERVICE}"; then
  systemctl restart "${TOR_SERVICE}"
else
  systemctl start "${TOR_SERVICE}"
fi
systemctl enable auto-ip-rotator.service

step 8 "Enabling firewall kill switch..."
if grep -q '^ENABLE_FIREWALL=1' "${CONFIG_DIR}/auto-ip.conf"; then
  systemctl enable nftables || true
  if ! systemctl is-active --quiet nftables; then
    systemctl start nftables || true
  fi
  "${ROOT_DIR}/firewall/apply_killswitch.sh"
else
  echo "Firewall kill switch disabled by config; skipping apply."
fi

TOR_GROUP="$(detect_tor_group)"
OWNER_USER="${SUDO_USER:-root}"
if [[ "${OWNER_USER}" != "root" ]]; then
  usermod -aG "${TOR_GROUP}" "${OWNER_USER}" || true
fi
if getent group "${TOR_GROUP}" >/dev/null 2>&1; then
  chgrp -R "${TOR_GROUP}" "${LOG_DIR}" || true
  chmod -R g+rwX "${LOG_DIR}" || true
fi

if OWNER_HOME="$(resolve_home_dir "${OWNER_USER}")"; then
  USER_CONF_DIR="${OWNER_HOME}/.config/auto-ip"
  mkdir -p "${USER_CONF_DIR}"
  cp "${CONFIG_DIR}/auto-ip.conf" "${USER_CONF_DIR}/auto-ip.conf"
  chown -R "${OWNER_USER}:${OWNER_USER}" "${USER_CONF_DIR}" || true
fi

verify_installation

echo
echo "Setup complete."
echo "Start service:  sudo systemctl start auto-ip-rotator"
echo "View logs:      sudo journalctl -u auto-ip-rotator -f"
echo "One-shot run:   torloom rotate --once"
echo "Interactive UI: auto-ip"
echo "Legacy UI:      ip-changer"
echo "Main command:   torloom"
echo "Proxy browser:  proxychains4 firefox --private-window"
