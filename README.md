# TorLoom AutoIP

`TorLoom AutoIP` is a Bash-first Tor IP rotator for Kali Linux with privacy hardening, health checks, leak resistance, and interactive operations.

## Unique Repo Identity

- Suggested GitHub repo name: `torloom-autoip-kali`
- One-line description:
  - `Interactive Tor IP rotation toolkit for Kali with DNS/IPv6 leak protection, kill switch, health checks, and systemd automation.`

## Core Features

- Randomized rotation intervals
- Tor health monitoring and auto-restart
- IP-change verification after each rotation
- DNS leak mitigation in Tor config
- IPv6 leak mitigation (persistent + runtime)
- nftables kill switch
- Proxychains auto-configuration
- User mode and root mode support
- Geo-IP logging (IP, country, ASN)
- Network auto-recovery hooks
- Hardened systemd service
- Country exit-node selection (US/DE/NL/JP/random)
- Interactive command center (`auto-ip`)
- Legacy compatibility entrypoint (`ip-changer.sh`) and service alias (`change-tor-ip`)

## Project Layout

```text
torloom-autoip-kali/
├── setup.sh
├── auto_ip_cli.sh
├── ip-changer.sh
├── change_tor_ip.sh
├── healthcheck.sh
├── leak_test.sh
├── uninstall.sh
├── configs/
│   ├── auto-ip.conf.template
│   ├── proxychains4.conf.template
│   └── torrc.template
├── firewall/
│   ├── apply_killswitch.sh
│   ├── remove_killswitch.sh
│   └── tor-killswitch.nft
├── lib/
│   └── common.sh
├── docs/
│   └── MANUAL.md
├── systemd/
│   └── auto-ip-rotator.service
└── README.md
```

## Install

```bash
sudo chmod +x *.sh firewall/*.sh
sudo ./setup.sh
```

## Daily Use

Open interactive console:

```bash
auto-ip
```

Legacy command (compatible):

```bash
ip-changer
```

Legacy doctor command:

```bash
ip-changer doctor
```

Manual rotation:

```bash
auto-ip-rotate --once
```

Validate config only:

```bash
auto-ip-rotate --validate-config
```

Run diagnostics:

```bash
auto-ip doctor
```

Leak test:

```bash
auto-ip-leaktest
```

Service control:

```bash
sudo systemctl start auto-ip-rotator
sudo systemctl stop auto-ip-rotator
sudo systemctl status auto-ip-rotator
```

Legacy service alias:

```bash
sudo systemctl start change-tor-ip
sudo systemctl status change-tor-ip
```

Private browser launch:

```bash
proxychains4 firefox --private-window
```

## Configuration

System config:

```text
/etc/auto-ip/auto-ip.conf
```

User config fallback:

```text
~/.config/auto-ip/auto-ip.conf
```

Tor drop-ins managed by setup:

```text
/etc/tor/torrc.d/auto-ip.conf
/etc/tor/torrc.d/auto-ip-country.conf
```

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

## Full Manual

Read the complete interactive and operational manual:

```text
docs/MANUAL.md
```

## Legal and Safety

Use this project only in legal and authorized environments. Tor IP rotation does not by itself prevent fingerprinting or account-linkage mistakes.
