#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f configs/auto-ip.conf.template ]]; then
  echo "Missing configs/auto-ip.conf.template"
  exit 1
fi

if [[ ! -f configs/torrc.template ]]; then
  echo "Missing configs/torrc.template"
  exit 1
fi

# shellcheck disable=SC1091
source configs/auto-ip.conf.template

[[ "${INTERVAL_MIN:-}" =~ ^[0-9]+$ ]] || { echo "INTERVAL_MIN invalid"; exit 1; }
[[ "${INTERVAL_MAX:-}" =~ ^[0-9]+$ ]] || { echo "INTERVAL_MAX invalid"; exit 1; }
[[ "${MAX_CHANGE_RETRIES:-}" =~ ^[0-9]+$ ]] || { echo "MAX_CHANGE_RETRIES invalid"; exit 1; }
[[ "${NEWNYM_MIN_COOLDOWN:-}" =~ ^[0-9]+$ ]] || { echo "NEWNYM_MIN_COOLDOWN invalid"; exit 1; }
(( INTERVAL_MIN <= INTERVAL_MAX )) || { echo "INTERVAL_MIN > INTERVAL_MAX"; exit 1; }
(( NEWNYM_MIN_COOLDOWN >= 10 )) || { echo "NEWNYM_MIN_COOLDOWN < 10"; exit 1; }

grep -q '^DNSPort 9053$' configs/torrc.template || { echo "torrc.template missing DNSPort 9053"; exit 1; }
grep -q '^AutomapHostsOnResolve 1$' configs/torrc.template || { echo "torrc.template missing AutomapHostsOnResolve 1"; exit 1; }
grep -q '^CookieAuthentication 1$' configs/torrc.template || { echo "torrc.template missing CookieAuthentication 1"; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cat > "${tmpdir}/canonical.conf" <<'EOF'
INTERVAL_MIN=30
INTERVAL_MAX=90
MAX_CHANGE_RETRIES=3
TOR_SOCKS_ADDR=127.0.0.1:9050
TOR_CONTROL_PORT=9051
NEWNYM_MIN_COOLDOWN=10
EOF

cat > "${tmpdir}/alias.conf" <<'EOF'
MIN_INTERVAL=35
MAX_INTERVAL=95
MAX_CHANGE_RETRIES=2
TOR_SOCKS_PORT=9050
CONTROL_PORT=9051
NEWNYM_MIN_COOLDOWN=10
EOF

cat > "${tmpdir}/invalid.conf" <<'EOF'
INTERVAL_MIN=100
INTERVAL_MAX=20
MAX_CHANGE_RETRIES=0
TOR_SOCKS_ADDR=127.0.0.1:99999
TOR_CONTROL_PORT=0
NEWNYM_MIN_COOLDOWN=5
EOF

CONFIG_FILE="${tmpdir}/canonical.conf" LOG_DIR="${tmpdir}" bash ./change_tor_ip.sh --validate-config
CONFIG_FILE="${tmpdir}/alias.conf" LOG_DIR="${tmpdir}" bash ./change_tor_ip.sh --validate-config

if CONFIG_FILE="${tmpdir}/invalid.conf" LOG_DIR="${tmpdir}" bash ./change_tor_ip.sh --validate-config; then
  echo "invalid config unexpectedly passed validation"
  exit 1
fi
