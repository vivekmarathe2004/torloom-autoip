# TorLoom AutoIP - Operator Manual

## 1. What This Tool Is

`TorLoom AutoIP` is a Tor circuit rotation toolkit for Kali Linux that focuses on:

- Better privacy hygiene
- Fewer accidental leaks
- Recoverable long-running behavior
- Friendly operator workflow

It is not a guarantee of anonymity.

## 2. Quick Start

Install:

```bash
sudo chmod +x *.sh firewall/*.sh
sudo ./setup.sh
```

Open interactive console:

```bash
auto-ip
```

Run one manual rotation:

```bash
auto-ip-rotate --once
```

Validate config:

```bash
auto-ip-rotate --validate-config
```

Start daemon:

```bash
sudo systemctl start auto-ip-rotator
```

## 3. Root Mode vs User Mode

- Root mode:
  - Can apply IPv6 runtime disable
  - Can restart Tor
  - Can run network recovery actions
  - Can manage service/firewall
- User mode:
  - Can request `NEWNYM` through Tor control cookie (if group access is present)
  - Can run status checks and leak tests
  - Cannot apply privileged recovery actions

If user mode cannot rotate:

```bash
sudo usermod -aG debian-tor $USER
newgrp debian-tor
```

## 4. Privacy Controls Included

- DNS leak protection in Tor:
  - `DNSPort 9053`
  - `AutomapHostsOnResolve 1`
- Tor control auth via cookie
- Optional country exit pinning
- IPv6 leak mitigation
- nftables kill switch to reduce direct egress leakage
- Proxychains integration

## 5. Interactive Console (auto-ip)

Menu actions:

1. Health status
2. Rotate Tor IP now
3. Start auto-rotation service
4. Stop auto-rotation service
5. Show recent logs
6. Run leak tests
7. Open manual
8. Launch private browser
9. Run doctor diagnostics
10. Exit

Non-interactive diagnostics:

```bash
auto-ip doctor
```

Legacy compatibility:

```bash
ip-changer doctor
```

## 6. Configuration

System config:

```text
/etc/auto-ip/auto-ip.conf
```

User fallback config:

```text
~/.config/auto-ip/auto-ip.conf
```

Main settings:

- `INTERVAL_MIN`
- `INTERVAL_MAX`
- `MAX_CHANGE_RETRIES`
- `NEWNYM_MIN_COOLDOWN`
- `EXIT_COUNTRY`
- `ENABLE_FIREWALL`

## 7. Logs

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

Tail logs:

```bash
sudo tail -f /var/log/auto-ip/rotations.log
```

## 8. Leak Test Routine

Run:

```bash
auto-ip-leaktest
```

Checks:

- Tor connectivity through SOCKS
- DNS endpoint reachability through Tor proxy
- IPv6 disable state

## 9. Troubleshooting

Tor inactive:

```bash
sudo systemctl restart tor
sudo systemctl restart tor@default
```

Rotation unchanged:

- This can happen naturally in Tor
- Increase interval range
- Retry with `auto-ip-rotate --once`
- Respect `NEWNYM_MIN_COOLDOWN` (minimum 10 seconds)

Permission denied on auth cookie:

- Ensure `CookieAuthFileGroupReadable 1`
- Ensure your user is in Tor group
- Re-login after group change

No internet after kill switch:

```bash
sudo /opt/auto-ip/firewall/remove_killswitch.sh
sudo systemctl restart nftables
```

## 10. Operational Safety Notes

- Keep realistic expectations: rotation does not erase browser fingerprinting.
- Avoid logging into personal accounts while expecting unlinkability.
- Use legal, authorized, and policy-compliant contexts only.
