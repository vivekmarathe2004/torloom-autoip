#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

main() {
  load_config
  ensure_runtime_dirs

  if ! validate_config; then
    log_error "Configuration validation failed."
    exit 1
  fi

  disable_ipv6_runtime
  ensure_tor_running || true

  if tor_is_active; then
    log_status "Tor service is active."
  else
    log_error "Tor service is inactive."
    exit 1
  fi

  local ip
  ip="$(get_ip || true)"
  if [[ -z "${ip}" ]]; then
    log_error "No Tor IP detected. Attempting recovery."
    network_recover
    ensure_tor_running || true
    ip="$(get_ip || true)"
  fi

  if [[ -z "${ip}" ]]; then
    log_error "Healthcheck failed: unable to fetch Tor IP."
    exit 1
  fi

  local geo
  geo="$(get_geo_ip "${ip}")"
  log_status "Healthcheck OK: ip=${ip} | ${geo}"
}

main "$@"
