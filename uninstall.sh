#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./uninstall.sh"
  exit 1
fi

echo "Stopping and disabling auto-ip service..."
systemctl stop auto-ip-rotator.service 2>/dev/null || true
systemctl disable auto-ip-rotator.service 2>/dev/null || true
systemctl stop change-tor-ip.service 2>/dev/null || true
systemctl disable change-tor-ip.service 2>/dev/null || true
rm -f /etc/systemd/system/auto-ip-rotator.service
rm -f /etc/systemd/system/change-tor-ip.service
systemctl daemon-reload

echo "Removing firewall rules..."
if [[ -x /opt/auto-ip/firewall/remove_killswitch.sh ]]; then
  /opt/auto-ip/firewall/remove_killswitch.sh || true
fi

echo "Removing installed files..."
rm -f /usr/local/bin/auto-ip /usr/local/bin/ip-changer /usr/local/bin/auto-ip-rotate /usr/local/bin/auto-ip-health /usr/local/bin/auto-ip-leaktest
rm -rf /opt/auto-ip
rm -rf /etc/auto-ip
rm -f /etc/tor/torrc.d/auto-ip.conf /etc/tor/torrc.d/auto-ip-country.conf
rm -f /etc/sysctl.d/99-auto-ip-ipv6.conf

if [[ -f /etc/proxychains4.conf.bak.auto-ip ]]; then
  echo "Restoring proxychains backup..."
  mv /etc/proxychains4.conf.bak.auto-ip /etc/proxychains4.conf
fi

echo "Reloading sysctl..."
sysctl --system >/dev/null || true

echo "Uninstall complete."
