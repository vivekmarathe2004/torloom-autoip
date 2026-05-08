#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

dns_leak_test() {
  if check_dns_via_tor; then
    echo "DNS test endpoint reachable through Tor proxy."
  else
    echo "DNS test endpoint did not respond through Tor proxy."
  fi
}

ipv6_leak_test() {
  if is_ipv6_runtime_disabled; then
    echo "IPv6 leak protection enabled (kernel IPv6 disabled)."
  else
    echo "WARNING: IPv6 still enabled."
  fi
}

tor_connectivity_test() {
  local ip
  ip="$(get_ip || true)"
  if [[ -n "${ip}" ]]; then
    echo "Tor connectivity OK: ${ip}"
  else
    echo "Tor connectivity FAILED."
    return 1
  fi
}

main() {
  load_config
  ensure_runtime_dirs

  if ! validate_config; then
    echo "Configuration validation failed."
    exit 1
  fi

  echo "Running leak checks..."
  tor_connectivity_test
  dns_leak_test
  ipv6_leak_test
}

main "$@"
