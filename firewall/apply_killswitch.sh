#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/tor-killswitch.nft"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

if ! command -v nft >/dev/null 2>&1; then
  echo "nftables is not installed."
  exit 1
fi

nft delete table inet auto_ip >/dev/null 2>&1 || true
nft -f "${RULES_FILE}"
echo "Kill switch applied (table: inet auto_ip)."
