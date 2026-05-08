#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
APP_DIR="${ROOT_DIR}/app"

usage() {
  cat <<'EOF'
TorLoom AutoIP Command Router

Usage:
  torloom [menu]
  torloom doctor
  torloom rotate [--once|--validate-config|--interval-min N|--interval-max N]
  torloom health
  torloom leaktest
  torloom setup
  torloom uninstall

Compatibility:
  auto-ip       -> torloom menu
  ip-changer    -> torloom menu
EOF
}

dispatch_by_alias() {
  local alias_name
  alias_name="$(basename "$0")"
  case "${alias_name}" in
    auto-ip|ip-changer)
      if [[ "${1:-}" == "doctor" ]]; then
        exec "${APP_DIR}/auto_ip_cli.sh" doctor
      fi
      if [[ $# -eq 0 ]]; then
        exec "${APP_DIR}/auto_ip_cli.sh"
      fi
      exec "${APP_DIR}/change_tor_ip.sh" "$@"
      ;;
    auto-ip-rotate)
      exec "${APP_DIR}/change_tor_ip.sh" "$@"
      ;;
    auto-ip-health)
      exec "${APP_DIR}/healthcheck.sh" "$@"
      ;;
    auto-ip-leaktest)
      exec "${APP_DIR}/leak_test.sh" "$@"
      ;;
  esac
}

main() {
  dispatch_by_alias "$@"

  case "${1:-menu}" in
    menu)
      exec "${APP_DIR}/auto_ip_cli.sh"
      ;;
    doctor)
      exec "${APP_DIR}/auto_ip_cli.sh" doctor
      ;;
    rotate)
      shift
      exec "${APP_DIR}/change_tor_ip.sh" "$@"
      ;;
    health)
      shift
      exec "${APP_DIR}/healthcheck.sh" "$@"
      ;;
    leaktest)
      shift
      exec "${APP_DIR}/leak_test.sh" "$@"
      ;;
    setup)
      exec "${ROOT_DIR}/setup.sh"
      ;;
    uninstall)
      exec "${ROOT_DIR}/uninstall.sh"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Unknown command: $1"
      usage
      exit 1
      ;;
  esac
}

main "$@"
