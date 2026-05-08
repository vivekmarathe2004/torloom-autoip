#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"

ONCE=0
VALIDATE_ONLY=0
LOCK_MODE=""
LOCK_FD=""
LOCK_FALLBACK_OWNER=0

usage() {
  cat <<'EOF'
Usage: change_tor_ip.sh [--once] [--interval-min N] [--interval-max N] [--validate-config]

Options:
  --once            Rotate once and exit.
  --interval-min N  Minimum sleep interval in seconds (default: from config or 30).
  --interval-max N  Maximum sleep interval in seconds (default: from config or 90).
  --validate-config Validate effective configuration and exit.
  -h, --help        Show this help.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --once)
        ONCE=1
        shift
        ;;
      --interval-min)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --interval-min"
          exit 1
        fi
        INTERVAL_MIN="$2"
        shift 2
        ;;
      --interval-max)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --interval-max"
          exit 1
        fi
        INTERVAL_MAX="$2"
        shift 2
        ;;
      --validate-config)
        VALIDATE_ONLY=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

acquire_lock() {
  mkdir -p "$(dirname "${LOCK_FILE}")" >/dev/null 2>&1 || true

  if command_exists flock; then
    exec {LOCK_FD}>"${LOCK_FILE}"
    if ! flock -n "${LOCK_FD}"; then
      log_error "Another instance already running (lock: ${LOCK_FILE})."
      exit 1
    fi
    LOCK_MODE="flock"
    return 0
  fi

  LOCK_MODE="pid"
  if [[ -f "${LOCK_FILE}" ]]; then
    local existing_pid
    existing_pid="$(cat "${LOCK_FILE}" 2>/dev/null || true)"
    if is_integer "${existing_pid}" && kill -0 "${existing_pid}" 2>/dev/null; then
      log_error "Another instance already running (PID ${existing_pid})."
      exit 1
    fi
  fi
  printf "%s\n" "$$" > "${LOCK_FILE}"
  LOCK_FALLBACK_OWNER=1
}

release_lock() {
  if [[ "${LOCK_MODE}" == "pid" && "${LOCK_FALLBACK_OWNER}" -eq 1 ]]; then
    rm -f "${LOCK_FILE}"
  fi
}

rotate_once() {
  local retries=0
  local old_ip=""
  local new_ip=""
  local geo=""

  ensure_tor_running || true
  disable_ipv6_runtime

  old_ip="$(get_ip || true)"
  if [[ -z "${old_ip}" ]]; then
    log_error "Could not fetch old Tor IP. Attempting network recovery."
    network_recover
  fi

  while (( retries < MAX_CHANGE_RETRIES )); do
    if ! request_newnym_with_cooldown; then
      log_error "Failed to request NEWNYM on attempt $((retries + 1))."
      network_recover
      ((retries++))
      continue
    fi
    sleep "${NEWNYM_MIN_COOLDOWN}"
    new_ip="$(get_ip || true)"

    if [[ -z "${new_ip}" ]]; then
      log_error "Failed to fetch new IP after renewal attempt $((retries + 1))."
      network_recover
      ((retries++))
      continue
    fi

    if [[ "${new_ip}" != "${old_ip}" && -n "${old_ip}" ]]; then
      break
    fi

    if [[ -z "${old_ip}" ]]; then
      break
    fi

    log_status "IP did not change on attempt $((retries + 1)): ${new_ip}. Retrying..."
    ((retries++))
  done

  if [[ -n "${new_ip}" ]]; then
    geo="$(get_geo_ip "${new_ip}")"
  else
    geo="country=?, asn=?"
  fi

  if [[ -n "${old_ip}" && -n "${new_ip}" && "${old_ip}" != "${new_ip}" ]]; then
    log_info "Rotation successful: ${old_ip} -> ${new_ip} | ${geo}"
  elif [[ -n "${new_ip}" ]]; then
    log_status "Rotation completed but IP unchanged: ${new_ip} | ${geo}"
  else
    log_error "Rotation failed. No Tor IP available."
    return 1
  fi

  return 0
}

main() {
  load_config
  parse_args "$@"
  ensure_runtime_dirs

  if ! validate_config; then
    log_error "Configuration validation failed. Fix config and retry."
    exit 1
  fi

  if (( VALIDATE_ONLY == 1 )); then
    log_status "Configuration validation passed."
    exit 0
  fi

  acquire_lock
  trap release_lock EXIT INT TERM

  if is_root; then
    log_status "Auto-IP rotation started in root mode (min=${INTERVAL_MIN}s, max=${INTERVAL_MAX}s, once=${ONCE})."
  else
    log_status "Auto-IP rotation started in user mode (min=${INTERVAL_MIN}s, max=${INTERVAL_MAX}s, once=${ONCE})."
  fi

  while true; do
    if ! rotate_once; then
      log_error "Rotation cycle ended with errors."
    fi

    if (( ONCE == 1 )); then
      log_status "One-shot mode complete."
      break
    fi

    local next_sleep
    next_sleep="$(random_interval "${INTERVAL_MIN}" "${INTERVAL_MAX}")"
    log_status "Sleeping ${next_sleep}s before next rotation."
    sleep "${next_sleep}"
  done
}

main "$@"
