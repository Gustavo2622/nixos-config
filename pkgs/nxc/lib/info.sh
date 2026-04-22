# nxc info — system summary from evaluated flake config

cmd_info() {
  local json_flag=false
  local cached_flag=false
  local packages_flag=false
  local services_flag=false
  local home_flag=false
  local search_term=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_flag=true; shift ;;
      --cached) cached_flag=true; shift ;;
      --packages) packages_flag=true; shift ;;
      --services) services_flag=true; shift ;;
      --home) home_flag=true; shift ;;
      --search) search_term="$2"; shift 2 ;;
      *) echo -e "${RED}Unknown flag:${NC} $1" >&2; return 1 ;;
    esac
  done

  local data
  local cache_file="$NXC_STATE_DIR/last-info.json"

  if $cached_flag && [[ -f "$cache_file" ]]; then
    data=$(cat "$cache_file")
  else
    local raw_data=""
    run_with_spinner "Evaluating config" raw_data nix eval --json "$NXC_FLAKE_ROOT#configData.\"$NXC_HOSTNAME\""
    # Strip nix warnings (non-JSON lines) from output
    data=$(echo "$raw_data" | grep -v "^warning:" | head -1)
    if [[ -z "$data" ]]; then
      echo -e "${RED}Error:${NC} Failed to evaluate configData for $NXC_HOSTNAME" >&2
      echo -e "Make sure ${CYAN}configData${NC} is defined in flake.nix" >&2
      return 1
    fi
    # Cache the result
    mkdir -p "$NXC_STATE_DIR"
    echo "$data" > "$cache_file"
  fi

  if $json_flag; then
    echo "$data" | jq .
    return
  fi

  # Drill-down modes
  if $packages_flag; then
    local pkg_path=".packages.system.names[]"
    if $home_flag; then
      pkg_path=".packages.home.names[]"
    fi
    if [[ -n "$search_term" ]]; then
      echo "$data" | jq -r "$pkg_path" 2>/dev/null | grep -i "$search_term"
    else
      echo "$data" | jq -r "$pkg_path" 2>/dev/null | sort | less
    fi
    return
  fi

  if $services_flag; then
    echo "$data" | jq -r '.services.names[]' | sort | less
    return
  fi

  # Default: summary view
  local hostname
  hostname=$(echo "$data" | jq -r '.networking.hostname // "unknown"')
  local version
  version=$(echo "$data" | jq -r '.system.nixosVersion // "unknown"')
  local state_version
  state_version=$(echo "$data" | jq -r '.system.stateVersion // "unknown"')

  echo -e "${BOLD}Host:${NC} $hostname"
  echo -e "${BOLD}System:${NC} NixOS $version (state $state_version)"
  echo ""

  # Ports (skip if null — darwin)
  local tcp
  tcp=$(echo "$data" | jq -r 'if .networking.tcpPorts then (.networking.tcpPorts | join(", ")) else empty end' 2>/dev/null)
  local udp
  udp=$(echo "$data" | jq -r 'if .networking.udpPorts then (.networking.udpPorts | join(", ")) else empty end' 2>/dev/null)
  if [[ -n "$tcp" ]]; then
    echo -e "${BOLD}TCP ports:${NC} $tcp"
  fi
  if [[ -n "$udp" ]]; then
    echo -e "${BOLD}UDP ports:${NC} $udp"
  fi
  echo ""

  # Counts with drill-down hints
  local pkg_count
  pkg_count=$(echo "$data" | jq -r '.packages.system.count // 0')
  local svc_count
  svc_count=$(echo "$data" | jq -r '.services.count // 0')
  echo -e "${BOLD}System packages:${NC} $pkg_count  ${DIM}(nxc info --packages)${NC}"
  echo -e "${BOLD}Services:${NC} $svc_count  ${DIM}(nxc info --services)${NC}"
}
