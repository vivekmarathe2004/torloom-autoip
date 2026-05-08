<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&height=230&color=0:0B132B,40:1C2541,70:3A506B,100:5BC0BE&text=TorLoom%20AutoIP&fontColor=EAF4FF&fontSize=48&fontAlignY=38&desc=Interactive%20Tor%20IP%20Rotation%20Suite%20for%20Kali&descAlignY=59&animation=fadeIn" alt="TorLoom AutoIP Banner" />
</p>

<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&pause=1100&color=5BC0BE&center=true&vCenter=true&random=false&width=900&lines=Privacy+Rotation+%E2%80%A2+Leak+Guard+%E2%80%A2+Health+Ops;Dual+Mode+Support%3A+auto-ip+and+ip-changer;Doctor+Diagnostics+%E2%80%A2+Kill+Switch+%E2%80%A2+Systemd+Hardened" alt="Typing Animation" />
</p>

<p align="center">
  <img src="docs/assets/autoip-sticker.svg" width="120" alt="AutoIP Sticker" />
</p>

<p align="center">
  <a href="https://github.com/vivekmarathe2004/torloom-autoip/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/vivekmarathe2004/torloom-autoip/ci.yml?style=for-the-badge&label=CI&color=16a34a" alt="CI" /></a>
  <img src="https://img.shields.io/badge/Kali-Linux-0ea5e9?style=for-the-badge&logo=kalilinux&logoColor=white" alt="Kali Linux" />
  <img src="https://img.shields.io/badge/Language-Bash-f59e0b?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash" />
  <img src="https://img.shields.io/badge/Firewall-nftables-2563eb?style=for-the-badge" alt="nftables" />
  <img src="https://img.shields.io/badge/Mode-Root%20%2B%20User-a855f7?style=for-the-badge" alt="Root and User mode" />
  <img src="https://img.shields.io/badge/Status-Active-22c55e?style=for-the-badge" alt="Status" />
</p>

<p align="center">
  <b>TorLoom AutoIP</b> is a practical privacy automation project for Kali: rotate Tor identities safely, detect failures early, and keep operational controls simple.
</p>

## Why This Project

Most Tor IP changers stop at `NEWNYM` and `sleep`.  
TorLoom AutoIP adds operational safety layers:

- Config validation before runtime
- Single-instance lock protection
- NEWNYM cooldown awareness
- Service hardening with systemd
- Built-in doctor diagnostics
- DNS/IPv6 leak guard and kill-switch integration

## Feature Matrix

| Capability | Included | Notes |
|---|---|---|
| Randomized rotation interval | Yes | Default 30-90s |
| Config preflight (`--validate-config`) | Yes | Fails fast with clear error |
| Single-instance lock | Yes | `flock` + PID fallback |
| NEWNYM cooldown control | Yes | Minimum 10s enforced |
| Tor health monitoring | Yes | Auto-restart + checks |
| Leak tests | Yes | DNS + IPv6 + Tor connectivity |
| Kill switch | Yes | nftables policy |
| Doctor diagnostics | Yes | `auto-ip doctor` |
| Legacy compatibility | Yes | `ip-changer` + `change-tor-ip` alias |
| CI checks | Yes | ShellCheck + syntax + config sanity |

## Quick Start

```bash
git clone https://github.com/vivekmarathe2004/torloom-autoip.git
cd torloom-autoip
sudo chmod +x *.sh firewall/*.sh
sudo ./setup.sh
```

## Command Deck

```bash
# Interactive console
torloom

# Compatibility entries
auto-ip
ip-changer

# One-shot rotation
torloom rotate --once

# Validate config only
torloom rotate --validate-config

# Full diagnostics
torloom doctor

# Leak test
torloom leaktest
```

## Service Control

```bash
sudo systemctl start auto-ip-rotator
sudo systemctl stop auto-ip-rotator
sudo systemctl status auto-ip-rotator

# Legacy alias
sudo systemctl status change-tor-ip
```

## Architecture

```mermaid
flowchart TD
  A[setup.sh] --> B[Config + Tor drop-ins]
  A --> C[systemd unit install]
  C --> D[auto-ip-rotator.service]
  D --> E[app/change_tor_ip.sh]
  E --> F[lib/common.sh]
  E --> G[Tor ControlPort NEWNYM]
  E --> H[SOCKS IP verification]
  I[torloom.sh] --> I2[app/auto_ip_cli.sh]
  I2 --> J[app/healthcheck.sh]
  I2 --> K[app/leak_test.sh]
  I --> L[doctor diagnostics]
  M[firewall scripts] --> N[nftables kill switch]
```

## Project Layout

```text
torloom-autoip/
├── torloom.sh
├── setup.sh
├── uninstall.sh
├── app/
├── configs/
├── firewall/
├── lib/
├── docs/
├── scripts/ci/
└── systemd/
```

## Configuration

System config:

```text
/etc/auto-ip/auto-ip.conf
```

User fallback config:

```text
~/.config/auto-ip/auto-ip.conf
```

Key options:

- `INTERVAL_MIN`
- `INTERVAL_MAX`
- `MAX_CHANGE_RETRIES`
- `NEWNYM_MIN_COOLDOWN`
- `ENABLE_FIREWALL`

## Logs

System logs:

```text
/var/log/auto-ip/errors.log
/var/log/auto-ip/rotations.log
/var/log/auto-ip/tor-status.log
```

User fallback logs:

```text
~/.local/state/auto-ip/logs/
```

## Troubleshooting

<details>
<summary>Tor service inactive</summary>

```bash
sudo systemctl restart tor
sudo systemctl restart tor@default
```

</details>

<details>
<summary>Control cookie permission error</summary>

- Ensure `CookieAuthFileGroupReadable 1` is set in Tor config.
- Ensure user is in Tor group (`debian-tor` or `tor`).
- Re-login after group update.

</details>

<details>
<summary>No internet after kill switch</summary>

```bash
sudo /opt/auto-ip/firewall/remove_killswitch.sh
sudo systemctl restart nftables
```

</details>

## Docs

- Full operator manual: [`docs/MANUAL.md`](docs/MANUAL.md)

## Legal and Safety

Use only in legal and authorized environments.  
Tor rotation does not eliminate browser fingerprinting or account-linkage risk.
