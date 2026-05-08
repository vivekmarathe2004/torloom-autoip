#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"

# Legacy compatibility entrypoint.
# If no args: open interactive UI.
# If args provided: forward to modern rotator.
if [[ $# -eq 0 ]]; then
  exec "${SCRIPT_DIR}/auto_ip_cli.sh"
fi

if [[ "${1:-}" == "doctor" ]]; then
  exec "${SCRIPT_DIR}/auto_ip_cli.sh" doctor
fi

exec "${SCRIPT_DIR}/change_tor_ip.sh" "$@"
