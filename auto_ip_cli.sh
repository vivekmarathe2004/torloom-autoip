#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

pick_banner_message() {
  local messages=(
    "Stealth mode engaged. Rotate smart, not loud."
    "Operational privacy starts with predictable discipline."
    "Fresh circuits. Lower noise. Cleaner ops."
    "Defensive networking console ready."
    "Trust signals, verify routes, rotate safely."
    "Stay lawful. Stay careful. Stay anonymous."
  )
  local idx=$(( RANDOM % ${#messages[@]} ))
  printf "%s\n" "${messages[$idx]}"
}

render_style_matrix() {
  echo -e "${CYAN}"
  echo "  ████████╗ ██████╗ ██████╗ ██╗      ██████╗  ██████╗ ███╗   ███╗"
  echo "  ╚══██╔══╝██╔═══██╗██╔══██╗██║     ██╔═══██╗██╔═══██╗████╗ ████║"
  echo "     ██║   ██║   ██║██████╔╝██║     ██║   ██║██║   ██║██╔████╔██║"
  echo "     ██║   ██║   ██║██╔══██╗██║     ██║   ██║██║   ██║██║╚██╔╝██║"
  echo "     ██║   ╚██████╔╝██║  ██║███████╗╚██████╔╝╚██████╔╝██║ ╚═╝ ██║"
  echo "     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝"
  echo -e "${WHITE}                    AutoIP Control Console${NC}"
}

render_style_script() {
  echo -e "${MAGENTA}"
  echo "   _______              __                               ______    ____  "
  echo "  /_  __(_)___  ____ _ / /   ____  ____ ___            / ____/___/ / /__"
  echo "   / / / / __ \/ __ \`// /   / __ \/ __ \`__ \   ______ / /   / __  / //_/"
  echo "  / / / / / / / /_/ // /___/ /_/ / / / / / /  /_____// /___/ /_/ / ,<   "
  echo " /_/ /_/_/ /_/\__, //_____/\____/_/ /_/ /_/          \____/\__,_/_/|_|  "
  echo "             /____/                                                       "
}

render_style_block() {
  echo -e "${BLUE}"
  echo " ╔══════════════════════════════════════════════════════════════════════╗"
  echo " ║   ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄▄      ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄   ▄▄         ║"
  echo " ║  █       █       █       █   █    █       █       █  █ █  █        ║"
  echo " ║  █▄     ▄█   ▄   █    ▄▄▄█   █    █   ▄   █   ▄   █  █▄█  █        ║"
  echo " ║    █   █ █  █ █  █   █▄▄▄█   █    █  █ █  █  █ █  █       █        ║"
  echo " ║    █   █ █  █▄█  █    ▄▄▄█   █___ █  █▄█  █  █▄█  █       █        ║"
  echo " ║    █   █ █       █   █▄▄▄█       █       █       ██     ██        ║"
  echo " ║    █▄▄▄█ █▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█ █▄▄▄█          ║"
  echo " ╚══════════════════════════════════════════════════════════════════════╝"
}

render_style_neon() {
  echo -e "${GREEN}"
  echo "  ░▀█▀░▄▀▄░█▀▄░█░░░█▀█░█▀█░█▄█   ▄▀█░█░█░▀█▀░█▀█░█░█░█▀█"
  echo "  ░░█░░█░█░█▀▄░█░░░█░█░█░█░█░█   █▀█░█▄█░░█░░█▄█░█▀█░█▀▀"
  echo "  ░░▀░░░▀░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░▀   ▀░▀░▀░▀░░▀░░▀░▀░▀░▀░▀░░"
  echo -e "${CYAN}      Rotating identities with controlled cadence and safety rails${NC}"
}

render_style_frame() {
  echo -e "${YELLOW}"
  echo "  ┌────────────────────────────────────────────────────────────────────┐"
  echo "  │  TORLOOM AUTOIP                                                    │"
  echo "  │  Privacy Rotation | Leak Guard | Health Monitor | Kill Switch     │"
  echo "  └────────────────────────────────────────────────────────────────────┘"
}

banner() {
  clear || true
  local style=$(( RANDOM % 6 ))
  local msg
  msg="$(pick_banner_message)"

  case "${style}" in
    0) render_style_matrix ;;
    1) render_style_script ;;
    2) render_style_block ;;
    3) render_style_neon ;;
    4) render_style_frame ;;
    *) render_style_script; echo -e "${CYAN}                   TorLoom AutoIP - Interactive Console${NC}" ;;
  esac

  echo -e "${YELLOW}────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "${WHITE}  ${msg}${NC}"
  echo -e "${YELLOW}────────────────────────────────────────────────────────────────────────────${NC}"
}

run_privileged() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    if ! command -v sudo >/dev/null 2>&1; then
      echo -e "${RED}sudo is required for this action.${NC}"
      return 1
    fi
    sudo "$@"
  fi
}

show_status() {
  echo -e "${YELLOW}Running healthcheck...${NC}"
  "${SCRIPT_DIR}/healthcheck.sh" || true
}

rotate_once() {
  echo -e "${YELLOW}Triggering one rotation...${NC}"
  "${SCRIPT_DIR}/change_tor_ip.sh" --once || true
}

start_service() {
  run_privileged systemctl start auto-ip-rotator.service
  run_privileged systemctl status --no-pager auto-ip-rotator.service | head -n 20
}

stop_service() {
  run_privileged systemctl stop auto-ip-rotator.service
  echo -e "${GREEN}Service stopped.${NC}"
}

tail_logs() {
  if [[ -r /var/log/auto-ip/rotations.log ]]; then
    tail -n 30 /var/log/auto-ip/rotations.log
  else
    run_privileged tail -n 30 /var/log/auto-ip/rotations.log
  fi
}

run_leak_test() {
  "${SCRIPT_DIR}/leak_test.sh" || true
}

doctor_check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf "%b[PASS]%b %s\n" "${GREEN}" "${NC}" "${label}"
  else
    printf "%b[FAIL]%b %s\n" "${RED}" "${NC}" "${label}"
    return 1
  fi
}

run_doctor() {
  local failed=0
  echo "auto-ip doctor"
  echo "--------------"

  load_config

  doctor_check "Dependencies installed" verify_dependencies || failed=1
  doctor_check "Configuration valid" "${SCRIPT_DIR}/change_tor_ip.sh" --validate-config || failed=1
  doctor_check "Tor service active" tor_is_active || failed=1
  doctor_check "SOCKS reachable over Tor" check_tor_socks_reachable || failed=1
  doctor_check "DNS endpoint reachable via Tor" check_dns_via_tor || failed=1
  doctor_check "Outbound Tor IP retrievable" get_ip || failed=1
  doctor_check "Control port reachable" check_control_port_reachable || failed=1
  doctor_check "Control cookie readable" check_control_cookie_readable || failed=1
  doctor_check "IPv6 disabled (runtime)" is_ipv6_runtime_disabled || failed=1
  doctor_check "proxychains4 available" command -v proxychains4 || failed=1

  if [[ "${ENABLE_FIREWALL:-1}" == "1" ]]; then
    doctor_check "nftables kill switch loaded" check_nft_killswitch_loaded || failed=1
  else
    echo "[INFO] Kill switch disabled by config; skipping nftables check."
  fi

  if (( failed == 0 )); then
    echo
    printf "%bDoctor summary: all checks passed.%b\n" "${GREEN}" "${NC}"
    return 0
  fi

  echo
  printf "%bDoctor summary: one or more checks failed.%b\n" "${RED}" "${NC}"
  return 1
}

open_manual() {
  local manual="${SCRIPT_DIR}/docs/MANUAL.md"
  if [[ -f "${manual}" ]]; then
    ${PAGER:-less} "${manual}"
  else
    echo "Manual not found at ${manual}"
  fi
}

launch_private_browser() {
  if command -v proxychains4 >/dev/null 2>&1; then
    proxychains4 firefox --private-window >/dev/null 2>&1 &
    echo -e "${GREEN}Launched Firefox private window via proxychains4.${NC}"
  else
    echo -e "${RED}proxychains4 is not installed.${NC}"
  fi
}

pause_prompt() {
  echo
  read -r -p "Press Enter to return to menu..."
}

menu_loop() {
  while true; do
    banner
    echo "1) Health status"
    echo "2) Rotate Tor IP now"
    echo "3) Start auto-rotation service"
    echo "4) Stop auto-rotation service"
    echo "5) Show recent logs"
    echo "6) Run leak tests"
    echo "7) Open manual"
    echo "8) Launch private browser"
    echo "9) Run doctor diagnostics"
    echo "10) Exit"
    echo
    read -r -p "Choose an option [1-10]: " opt

    case "${opt}" in
      1) show_status ;;
      2) rotate_once ;;
      3) start_service ;;
      4) stop_service ;;
      5) tail_logs ;;
      6) run_leak_test ;;
      7) open_manual ;;
      8) launch_private_browser ;;
      9) run_doctor ;;
      10) exit 0 ;;
      *) echo -e "${RED}Invalid option.${NC}" ;;
    esac
    pause_prompt
  done
}

if [[ "${1:-}" == "doctor" ]]; then
  run_doctor
  exit $?
fi

menu_loop
