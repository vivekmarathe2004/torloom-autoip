#!/usr/bin/env bash
set -o pipefail

SYSTEM_CONFIG_FILE="/etc/auto-ip/auto-ip.conf"
USER_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/auto-ip/auto-ip.conf"
USER_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/auto-ip/logs"
SYSTEM_LOG_DIR="/var/log/auto-ip"
LOCK_FILE_DEFAULT="/tmp/auto-ip.lock"
NEWNYM_MIN_COOLDOWN_DEFAULT=10

CONFIG_FILE="${CONFIG_FILE:-${SYSTEM_CONFIG_FILE}}"
LOG_DIR="${LOG_DIR:-${SYSTEM_LOG_DIR}}"
TOR_SOCKS_ADDR="${TOR_SOCKS_ADDR:-127.0.0.1:9050}"
TOR_CONTROL_HOST="${TOR_CONTROL_HOST:-127.0.0.1}"
TOR_CONTROL_PORT="${TOR_CONTROL_PORT:-9051}"
TOR_CONTROL_COOKIE="${TOR_CONTROL_COOKIE:-/run/tor/control.authcookie}"
LOCK_FILE="${LOCK_FILE:-${LOCK_FILE_DEFAULT}}"
NEWNYM_MIN_COOLDOWN="${NEWNYM_MIN_COOLDOWN:-${NEWNYM_MIN_COOLDOWN_DEFAULT}}"
LAST_NEWNYM_TS=0
TOR_SERVICE_CACHE=""

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

ensure_runtime_dirs() {
  mkdir -p "${LOG_DIR}"
  touch "${LOG_DIR}/errors.log" "${LOG_DIR}/rotations.log" "${LOG_DIR}/tor-status.log"
}

log_to_file() {
  local file="$1"
  local level="$2"
  shift 2
  local msg="$*"
  local line
  line="$(timestamp) | ${level} | ${msg}"
  printf "%s\n" "${line}" >> "${LOG_DIR}/${file}"
  printf "%s\n" "${line}"
}

log_info() {
  log_to_file "rotations.log" "INFO" "$*"
}

log_status() {
  log_to_file "tor-status.log" "STATUS" "$*"
}

log_error() {
  log_to_file "errors.log" "ERROR" "$*" >&2
}

warn_stderr() {
  printf "WARN: %s\n" "$*" >&2
}

error_stderr() {
  printf "ERROR: %s\n" "$*" >&2
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "This script must run as root."
    exit 1
  fi
}

is_root() {
  [[ "${EUID}" -eq 0 ]]
}

resolve_runtime_paths() {
  # Allow explicit CONFIG_FILE overrides (for CI/tests and power users).
  if [[ -n "${CONFIG_FILE:-}" && "${CONFIG_FILE}" != "${SYSTEM_CONFIG_FILE}" && "${CONFIG_FILE}" != "${USER_CONFIG_FILE}" ]]; then
    return 0
  fi

  if ! is_root; then
    if [[ -f "${SYSTEM_CONFIG_FILE}" ]]; then
      CONFIG_FILE="${SYSTEM_CONFIG_FILE}"
    else
      CONFIG_FILE="${USER_CONFIG_FILE}"
    fi

    if [[ ! -d "${SYSTEM_LOG_DIR}" || ! -w "${SYSTEM_LOG_DIR}" ]]; then
      LOG_DIR="${USER_LOG_DIR}"
    fi
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

port_in_range() {
  local p="$1"
  (( p >= 1 && p <= 65535 ))
}

parse_port_from_addr() {
  local addr="$1"
  local port="${addr##*:}"
  printf "%s\n" "${port}"
}

detect_tor_service() {
  if [[ -n "${TOR_SERVICE_CACHE}" ]]; then
    printf "%s\n" "${TOR_SERVICE_CACHE}"
    return 0
  fi

  if systemctl is-active --quiet tor@default 2>/dev/null; then
    TOR_SERVICE_CACHE="tor@default"
  elif systemctl is-active --quiet tor 2>/dev/null; then
    TOR_SERVICE_CACHE="tor"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^tor@default.service"; then
    TOR_SERVICE_CACHE="tor@default"
  else
    TOR_SERVICE_CACHE="tor"
  fi

  printf "%s\n" "${TOR_SERVICE_CACHE}"
}

tor_is_active() {
  systemctl is-active --quiet tor@default 2>/dev/null || systemctl is-active --quiet tor 2>/dev/null
}

restart_tor() {
  local tor_service
  tor_service="$(detect_tor_service)"
  if is_root; then
    systemctl restart "${tor_service}" >/dev/null 2>&1 || systemctl restart tor >/dev/null 2>&1 || systemctl restart tor@default >/dev/null 2>&1
  else
    return 1
  fi
}

ensure_tor_running() {
  local tor_service
  tor_service="$(detect_tor_service)"
  if ! systemctl is-active --quiet "${tor_service}"; then
    if is_root; then
      log_status "Tor service was down. Restarting ${tor_service}..."
      systemctl restart "${tor_service}"
      sleep 3
    else
      log_error "Tor service is down and user mode cannot restart it. Run: sudo systemctl restart ${tor_service}"
      return 1
    fi
  fi
}

get_ip() {
  local ip
  ip="$(curl --socks5-hostname "${TOR_SOCKS_ADDR}" -fsS --max-time 25 https://api.ipify.org 2>/dev/null || true)"
  if [[ -n "${ip}" ]]; then
    printf "%s\n" "${ip}"
    return 0
  fi

  ip="$(curl --socks5-hostname "${TOR_SOCKS_ADDR}" -fsS --max-time 25 https://ifconfig.me/ip 2>/dev/null || true)"
  if [[ -n "${ip}" ]]; then
    printf "%s\n" "${ip}"
    return 0
  fi

  ip="$(curl --socks5-hostname "${TOR_SOCKS_ADDR}" -fsS --max-time 25 https://check.torproject.org/api/ip 2>/dev/null || true)"
  if [[ -n "${ip}" ]] && command_exists jq; then
    printf "%s\n" "$(printf "%s" "${ip}" | jq -r '.IP // empty' 2>/dev/null || true)"
    return 0
  fi

  printf "%s\n" "${ip}"
}

get_geo_ip() {
  local ip="$1"
  local geo
  geo="$(curl --socks5-hostname "${TOR_SOCKS_ADDR}" -fsS --max-time 25 "https://ipapi.co/${ip}/json/" 2>/dev/null || true)"
  if [[ -z "${geo}" ]]; then
    echo "country=?, asn=?"
    return 0
  fi

  if command_exists jq; then
    local country asn
    country="$(printf "%s" "${geo}" | jq -r '.country_name // .country // "?"' 2>/dev/null || echo "?")"
    asn="$(printf "%s" "${geo}" | jq -r '.asn // .org // "?"' 2>/dev/null || echo "?")"
    echo "country=${country}, asn=${asn}"
  else
    echo "country=?, asn=?"
  fi
}

disable_ipv6_runtime() {
  if is_root; then
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || log_status "Could not disable IPv6 (all) at runtime; continuing."
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || log_status "Could not disable IPv6 (default) at runtime; continuing."
  else
    log_status "User mode: skipping runtime IPv6 disable (requires root)."
  fi
}

network_recover() {
  log_status "Network recovery triggered."
  if ! is_root; then
    log_status "User mode: skipping network recovery (requires root)."
    return 0
  fi
  if command_exists dhclient; then
    dhclient -r >/dev/null 2>&1 || true
    dhclient >/dev/null 2>&1 || true
  fi
  if systemctl list-unit-files 2>/dev/null | grep -q "^NetworkManager.service"; then
    systemctl restart NetworkManager >/dev/null 2>&1 || true
  fi
}

load_config() {
  resolve_runtime_paths

  if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
  elif [[ -f "${USER_CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${USER_CONFIG_FILE}"
  fi

  normalize_config

  INTERVAL_MIN="${INTERVAL_MIN:-30}"
  INTERVAL_MAX="${INTERVAL_MAX:-90}"
  MAX_CHANGE_RETRIES="${MAX_CHANGE_RETRIES:-3}"
  ENABLE_FIREWALL="${ENABLE_FIREWALL:-1}"
  TOR_CONTROL_PORT="${TOR_CONTROL_PORT:-9051}"
  TOR_SOCKS_ADDR="${TOR_SOCKS_ADDR:-127.0.0.1:9050}"
  NEWNYM_MIN_COOLDOWN="${NEWNYM_MIN_COOLDOWN:-${NEWNYM_MIN_COOLDOWN_DEFAULT}}"
  LOCK_FILE="${LOCK_FILE:-${LOCK_FILE_DEFAULT}}"
}

normalize_config() {
  if [[ -z "${INTERVAL_MIN:-}" && -n "${MIN_INTERVAL:-}" ]]; then
    INTERVAL_MIN="${MIN_INTERVAL}"
    warn_stderr "MIN_INTERVAL is deprecated. Use INTERVAL_MIN."
  fi

  if [[ -z "${INTERVAL_MAX:-}" && -n "${MAX_INTERVAL:-}" ]]; then
    INTERVAL_MAX="${MAX_INTERVAL}"
    warn_stderr "MAX_INTERVAL is deprecated. Use INTERVAL_MAX."
  fi

  if [[ -z "${TOR_CONTROL_PORT:-}" && -n "${CONTROL_PORT:-}" ]]; then
    TOR_CONTROL_PORT="${CONTROL_PORT}"
    warn_stderr "CONTROL_PORT is deprecated. Use TOR_CONTROL_PORT."
  fi

  if [[ -z "${TOR_SOCKS_ADDR:-}" && -n "${TOR_SOCKS_PORT:-}" ]]; then
    TOR_SOCKS_ADDR="127.0.0.1:${TOR_SOCKS_PORT}"
    warn_stderr "TOR_SOCKS_PORT is deprecated. Use TOR_SOCKS_ADDR."
  fi
}

validate_config() {
  local socks_port
  socks_port="$(parse_port_from_addr "${TOR_SOCKS_ADDR}")"

  is_integer "${INTERVAL_MIN}" || { error_stderr "INTERVAL_MIN must be an integer."; return 1; }
  is_integer "${INTERVAL_MAX}" || { error_stderr "INTERVAL_MAX must be an integer."; return 1; }
  is_integer "${MAX_CHANGE_RETRIES}" || { error_stderr "MAX_CHANGE_RETRIES must be an integer."; return 1; }
  is_integer "${TOR_CONTROL_PORT}" || { error_stderr "TOR_CONTROL_PORT must be an integer."; return 1; }
  is_integer "${NEWNYM_MIN_COOLDOWN}" || { error_stderr "NEWNYM_MIN_COOLDOWN must be an integer."; return 1; }
  is_integer "${socks_port}" || { error_stderr "TOR_SOCKS_ADDR must end with a numeric port."; return 1; }

  (( INTERVAL_MIN >= 1 )) || { error_stderr "INTERVAL_MIN must be >= 1."; return 1; }
  (( INTERVAL_MAX >= 1 )) || { error_stderr "INTERVAL_MAX must be >= 1."; return 1; }
  (( INTERVAL_MIN <= INTERVAL_MAX )) || { error_stderr "INTERVAL_MIN must be <= INTERVAL_MAX."; return 1; }
  (( MAX_CHANGE_RETRIES >= 1 )) || { error_stderr "MAX_CHANGE_RETRIES must be >= 1."; return 1; }
  (( NEWNYM_MIN_COOLDOWN >= 10 )) || { error_stderr "NEWNYM_MIN_COOLDOWN must be >= 10."; return 1; }
  port_in_range "${TOR_CONTROL_PORT}" || { error_stderr "TOR_CONTROL_PORT must be between 1 and 65535."; return 1; }
  port_in_range "${socks_port}" || { error_stderr "TOR_SOCKS_ADDR port must be between 1 and 65535."; return 1; }

  return 0
}

random_interval() {
  local min="$1"
  local max="$2"
  if (( max < min )); then
    max="${min}"
  fi
  echo $(( RANDOM % (max - min + 1) + min ))
}

renew_tor_identity() {
  local auth_cookie="${TOR_CONTROL_COOKIE}"
  local response=""

  if [[ ! -f "${auth_cookie}" ]]; then
    auth_cookie="/var/run/tor/control.authcookie"
  fi

  if [[ -f "${auth_cookie}" ]] && command_exists xxd && command_exists nc; then
    local cookie_hex
    cookie_hex="$(xxd -p "${auth_cookie}" | tr -d '\n')"
    response="$(printf 'AUTHENTICATE "%s"\r\nSIGNAL NEWNYM\r\nQUIT\r\n' "${cookie_hex}" | nc -w 3 "${TOR_CONTROL_HOST}" "${TOR_CONTROL_PORT}" 2>/dev/null || true)"
    if grep -q "250 OK" <<<"${response}"; then
      return 0
    fi
  fi

  if is_root; then
    restart_tor
  else
    log_error "Could not authenticate to Tor ControlPort in user mode. Ensure user is in debian-tor group and CookieAuthFileGroupReadable 1 is set."
    return 1
  fi
}

wait_for_newnym_cooldown() {
  local now delta wait_for
  now="$(date +%s)"
  delta=$(( now - LAST_NEWNYM_TS ))
  wait_for=$(( NEWNYM_MIN_COOLDOWN - delta ))

  if (( LAST_NEWNYM_TS > 0 && wait_for > 0 )); then
    log_status "Respecting NEWNYM cooldown: waiting ${wait_for}s."
    sleep "${wait_for}"
  fi
}

request_newnym_with_cooldown() {
  wait_for_newnym_cooldown
  renew_tor_identity
  LAST_NEWNYM_TS="$(date +%s)"
}

verify_dependencies() {
  local missing=0
  local deps=(tor curl jq xxd nc systemctl nft)
  local dep
  for dep in "${deps[@]}"; do
    if ! command_exists "${dep}"; then
      error_stderr "Missing dependency: ${dep}"
      missing=1
    fi
  done
  return "${missing}"
}

check_tor_socks_reachable() {
  curl --socks5-hostname "${TOR_SOCKS_ADDR}" -fsS --max-time 20 https://api.ipify.org >/dev/null 2>&1
}

check_dns_via_tor() {
  curl --socks5-hostname "${TOR_SOCKS_ADDR}" -fsS --max-time 20 https://dnsleaktest.com >/dev/null 2>&1
}

check_nft_killswitch_loaded() {
  nft list table inet auto_ip >/dev/null 2>&1
}

check_control_port_reachable() {
  nc -z "${TOR_CONTROL_HOST}" "${TOR_CONTROL_PORT}" >/dev/null 2>&1
}

check_control_cookie_readable() {
  [[ -r "${TOR_CONTROL_COOKIE}" || -r /var/run/tor/control.authcookie ]]
}

is_ipv6_runtime_disabled() {
  [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo 0)" == "1" ]]
}
