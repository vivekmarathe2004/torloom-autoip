#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

if ! command -v nft >/dev/null 2>&1; then
  echo "nftables is not installed."
  exit 0
fi

nft delete table inet auto_ip >/dev/null 2>&1 || true
echo "Kill switch removed."
