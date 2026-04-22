# nxc health — config hygiene check

cmd_health() {
  local verbose=false
  local strict=false
  local exit_code=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose) verbose=true; shift ;;
      --strict) strict=true; shift ;;
      *) echo -e "${RED}Unknown flag:${NC} $1" >&2; return 1 ;;
    esac
  done

  echo -e "${BOLD}nxc health${NC}"
  echo ""

  # Statix — run per-directory for progress
  local check_dirs=("modules/nixos" "modules/home" "modules/mutable" "modules/theme" "modules/variables" "overlays" "pkgs")
  local total_warnings=0
  local total_errors=0
  local all_statix_out=""

  echo -e "${BOLD}Lint (statix):${NC}"
  for dir in "${check_dirs[@]}"; do
    local full_path="$NXC_FLAKE_ROOT/$dir"
    if [[ ! -d "$full_path" ]]; then
      continue
    fi

    local dir_out=""
    run_with_spinner "Checking $dir" dir_out statix check "$full_path"

    local dir_warnings=0
    local dir_errors=0
    dir_warnings=$(echo "$dir_out" | grep -c "Warning:" || true)
    dir_errors=$(echo "$dir_out" | grep -c "Error:" || true)
    total_warnings=$((total_warnings + dir_warnings))
    total_errors=$((total_errors + dir_errors))
    all_statix_out+="$dir_out"

    if [[ "$dir_errors" -gt 0 ]]; then
      echo -e "  ${RED}✗${NC} $dir/  ${RED}$dir_errors errors${NC}, $dir_warnings warnings"
    elif [[ "$dir_warnings" -gt 0 ]]; then
      echo -e "  ${YELLOW}!${NC} $dir/  ${YELLOW}$dir_warnings warnings${NC}"
    else
      echo -e "  ${GREEN}✔${NC} $dir/  clean"
    fi
  done

  # Also check flake.nix
  local flake_out=""
  run_with_spinner "Checking flake.nix" flake_out statix check "$NXC_FLAKE_ROOT/flake.nix"
  local flake_warnings=0
  local flake_errors=0
  flake_warnings=$(echo "$flake_out" | grep -c "Warning:" || true)
  flake_errors=$(echo "$flake_out" | grep -c "Error:" || true)
  total_warnings=$((total_warnings + flake_warnings))
  total_errors=$((total_errors + flake_errors))
  all_statix_out+="$flake_out"

  if [[ "$flake_errors" -gt 0 ]]; then
    echo -e "  ${RED}✗${NC} flake.nix  ${RED}$flake_errors errors${NC}, $flake_warnings warnings"
  elif [[ "$flake_warnings" -gt 0 ]]; then
    echo -e "  ${YELLOW}!${NC} flake.nix  ${YELLOW}$flake_warnings warnings${NC}"
  else
    echo -e "  ${GREEN}✔${NC} flake.nix  clean"
  fi

  if [[ "$total_errors" -gt 0 ]]; then
    echo -e "  ${RED}Total: $total_errors errors, $total_warnings warnings${NC}"
    exit_code=1
  elif [[ "$total_warnings" -gt 0 ]]; then
    echo -e "  ${YELLOW}Total: $total_warnings warnings${NC}"
    $strict && exit_code=1
  else
    echo -e "  ${GREEN}All clean${NC}"
  fi

  if $verbose && [[ -n "$all_statix_out" ]]; then
    echo ""
    echo "$all_statix_out"
  fi
  echo ""

  # Deadnix
  echo -e "${BOLD}Dead code (deadnix):${NC}"
  local deadnix_out=""
  run_with_spinner "Scanning for unused bindings" deadnix_out deadnix "$NXC_FLAKE_ROOT"

  local deadnix_count=0
  deadnix_count=$(echo "$deadnix_out" | grep -c "Unused" || true)

  if [[ "$deadnix_count" -gt 0 ]]; then
    echo -e "  ${YELLOW}!${NC} $deadnix_count unused bindings"
    $strict && exit_code=1
  else
    echo -e "  ${GREEN}✔${NC} clean"
  fi

  if $verbose && [[ -n "$deadnix_out" ]]; then
    echo ""
    echo "$deadnix_out"
  fi
  echo ""

  # Mutable staleness
  echo -e "${BOLD}Mutable state:${NC}"
  if [[ -f "$NXC_REGISTRY" ]]; then
    local stale_count=0
    local stale_progs=""
    local active_count=0

    for prog in $(list_programs); do
      local dir ext
      dir=$(get_mutable_dir "$prog")
      ext=$(get_extension "$prog")

      if [[ -d "$dir" ]] && ls "$dir"/*."$ext" &>/dev/null; then
        local total_size
        total_size=$(cat "$dir"/*."$ext" 2>/dev/null | wc -c)
        if [[ "$total_size" -gt 0 ]]; then
          active_count=$((active_count + 1))
          # Check mtime of newest fragment
          local newest
          newest=$(find "$dir" -name "*.$ext" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
          if [[ -n "$newest" ]]; then
            local now
            now=$(date +%s)
            local age_days=$(( (now - ${newest%.*}) / 86400 ))
            if [[ "$age_days" -ge "$NXC_STALE_DAYS" ]]; then
              stale_count=$((stale_count + 1))
              stale_progs+="    $prog: ${age_days}d old\n"
            fi
          fi
        fi
      fi
    done

    if [[ "$stale_count" -gt 0 ]]; then
      echo -e "  ${YELLOW}!${NC} $active_count active, $stale_count stale (>${NXC_STALE_DAYS}d)"
      printf '%b' "$stale_progs"
    elif [[ "$active_count" -gt 0 ]]; then
      echo -e "  ${BLUE}i${NC} $active_count active, none stale"
    else
      echo -e "  ${GREEN}✔${NC} no active overrides"
    fi
  else
    echo -e "  ${DIM}(registry not found — run a rebuild)${NC}"
  fi

  return $exit_code
}
