# Main dispatch — called after all libs are loaded

usage() {
  echo -e "${BOLD}nxc${NC} — NixOS Config Utility"
  echo ""
  echo -e "${BOLD}Usage:${NC} nxc <command> [args]"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo "  info      System summary (ports, packages, services)"
  echo "  mut       Mutable state management"
  echo "  theme     Theme hot-swap"
  echo "  health    Config hygiene check (lint, dead code, staleness)"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  nxc info                  System overview"
  echo "  nxc info --packages       List all system packages"
  echo "  nxc mut status            Show mutable state overview"
  echo "  nxc mut edit hyprland     Edit Hyprland overrides"
  echo "  nxc theme set catppuccin  Switch theme colors"
  echo "  nxc health                Run all checks"
}

case "${1:-}" in
  info) shift; cmd_info "$@" ;;
  mut) shift; cmd_mut "$@" ;;
  theme) shift; cmd_theme "$@" ;;
  health) shift; cmd_health "$@" ;;
  -h|--help|help|"") usage ;;
  *) echo -e "${RED}Unknown command:${NC} $1" >&2; usage >&2; exit 1 ;;
esac
