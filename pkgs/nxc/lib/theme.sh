# nxc theme — hot-swap theme colors without rebuild

cmd_theme() {
  require_registry
  local subcmd="current"
  if [[ $# -gt 0 ]]; then
    subcmd="$1"
    shift
  fi

  case "$subcmd" in
    list) theme_list "$@" ;;
    set) theme_set "$@" ;;
    current) theme_current "$@" ;;
    lock) theme_lock "$@" ;;
    reset) theme_reset "$@" ;;
    -h|--help|help) theme_usage ;;
    *) echo -e "${RED}Unknown theme subcommand:${NC} $subcmd" >&2; theme_usage >&2; return 1 ;;
  esac
}

theme_usage() {
  echo -e "${BOLD}nxc theme${NC} — theme hot-swap"
  echo ""
  echo -e "${BOLD}Usage:${NC} nxc theme <command> [args]"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo "  list                List available themes"
  echo "  current             Show active runtime theme"
  echo "  set <name>          Apply a theme (hot-swap, no rebuild)"
  echo "  lock                Make current runtime theme the declarative default"
  echo "  reset               Restore Nix-declared theme colors"
}

theme_list() {
  require_themes
  local current
  current=$(theme_current_name)
  local built="$NXC_THEME_NAME"

  echo -e "${BOLD}Available themes:${NC}"
  for t in $(jq -r 'keys[]' "$NXC_THEMES" | sort); do
    local marker=""
    if [[ "$t" == "$current" && "$t" == "$built" ]]; then
      marker=" ${GREEN}(active, built)${NC}"
    elif [[ "$t" == "$current" ]]; then
      marker=" ${CYAN}(active)${NC}"
    elif [[ "$t" == "$built" ]]; then
      marker=" ${DIM}(built)${NC}"
    fi
    echo -e "  $t$marker"
  done
}

theme_set() {
  require_themes
  local theme_name="${1:-}"
  if [[ -z "$theme_name" ]]; then
    # List available themes
    local themes
    themes=$(jq -r 'keys[]' "$NXC_THEMES")
    echo -e "${BOLD}Available themes:${NC}"
    echo "$themes"
    echo ""
    read -rp "Theme name: " theme_name
    [[ -z "$theme_name" ]] && return 0
  fi

  # Verify theme exists
  if ! jq -e --arg t "$theme_name" '.[$t]' "$NXC_THEMES" &>/dev/null; then
    echo -e "${RED}Theme not found:${NC} $theme_name" >&2
    echo -e "Available: $(jq -r 'keys | join(", ")' "$NXC_THEMES")" >&2
    return 1
  fi

  # List affected programs
  local affected
  affected=$(jq -r --arg t "$theme_name" '.[$t] | keys[]' "$NXC_THEMES")
  echo -e "Apply ${BOLD}$theme_name${NC} to: $affected"
  read -rp "Proceed? [Y/n] " choice
  case "$choice" in
    n|N) return 0 ;;
  esac

  # Apply to each program
  for prog in $affected; do
    local dir ext comment_start comment_end
    dir=$(get_mutable_dir "$prog")
    ext=$(get_extension "$prog")
    comment_start=$(get_field "$prog" "commentStart")
    comment_end=$(get_field "$prog" "commentEnd")

    mkdir -p "$dir"

    local theme_content
    theme_content=$(jq -r --arg t "$theme_name" --arg p "$prog" '.[$t][$p]' "$NXC_THEMES")

    # Write to the theme fragment (00-theme.<ext>)
    local theme_frag="$dir/00-theme.$ext"
    local header="${comment_start} --- nxc:owner=theme --- ${comment_end}"
    printf "%s\n%s\n" "$header" "$theme_content" > "$theme_frag"

    echo -e "  ${GREEN}$prog${NC} → 00-theme.$ext"
  done

  # Fire reload commands
  for prog in $affected; do
    local reload_cmd
    reload_cmd=$(get_field "$prog" "reloadCmd")
    if [[ -n "$reload_cmd" && "$reload_cmd" != "null" ]]; then
      eval "$reload_cmd" 2>/dev/null && echo -e "  ${GREEN}Reloaded $prog${NC}"
    fi
  done

  echo -e "${GREEN}Theme applied: $theme_name${NC}"
}

theme_current() {
  require_themes

  local all_themes
  all_themes=$(jq -r 'keys[]' "$NXC_THEMES")
  local detected_per_prog=""
  local detected_theme=""
  local all_agree=true

  for prog in $(list_programs); do
    local dir ext
    dir=$(get_mutable_dir "$prog")
    ext=$(get_extension "$prog")
    local theme_frag="$dir/00-theme.$ext"

    if [[ ! -f "$theme_frag" ]] || [[ ! -s "$theme_frag" ]]; then
      continue
    fi

    # Hash the theme fragment content (skip the header line)
    local frag_hash
    frag_hash=$(tail -n +2 "$theme_frag" | tr -d '[:space:]' | sha256sum | cut -d' ' -f1)

    local matched="custom"
    for t in $all_themes; do
      local expected
      expected=$(jq -r --arg t "$t" --arg p "$prog" '.[$t][$p] // empty' "$NXC_THEMES")
      if [[ -n "$expected" ]]; then
        local expected_hash
        expected_hash=$(echo "$expected" | tr -d '[:space:]' | sha256sum | cut -d' ' -f1)
        if [[ "$frag_hash" == "$expected_hash" ]]; then
          matched="$t"
          break
        fi
      fi
    done

    if [[ -z "$detected_theme" ]]; then
      detected_theme="$matched"
    elif [[ "$detected_theme" != "$matched" ]]; then
      all_agree=false
    fi
    detected_per_prog+="  $prog: $matched\n"
  done

  if [[ -z "$detected_theme" ]]; then
    echo -e "${BOLD}Runtime:${NC} ${DIM}no theme fragments${NC}"
  elif $all_agree; then
    echo -e "${BOLD}Runtime:${NC} $detected_theme"
  else
    echo -e "${BOLD}Runtime:${NC} ${YELLOW}mixed${NC}"
    echo -e "$detected_per_prog"
  fi

  # Compare with built theme
  local built_theme="$NXC_THEME_NAME"
  if [[ -n "$built_theme" && -n "$detected_theme" && "$detected_theme" != "$built_theme" ]]; then
    echo -e "${BOLD}Built:${NC} $built_theme ${DIM}(rebuild needed to fully apply)${NC}"
  elif [[ -n "$built_theme" ]]; then
    echo -e "${BOLD}Built:${NC} $built_theme"
  fi
}

theme_lock() {
  # Determine current runtime theme
  local current
  current=$(theme_current_name)

  if [[ -z "$current" || "$current" == "custom" || "$current" == "mixed" ]]; then
    echo -e "${RED}Cannot lock:${NC} runtime theme is '$current'" >&2
    echo -e "Use ${CYAN}nxc theme set <name>${NC} first." >&2
    return 1
  fi

  local override_file="$NXC_FLAKE_ROOT/state/theme-override.nix"
  cat > "$override_file" << EOF
# Generated by nxc theme lock — do not edit manually
{ theme = "$current"; }
EOF

  echo -e "${GREEN}Theme locked to $current.${NC}"
  echo -e "Rebuild to make permanent: ${CYAN}nh os switch /etc/nixos${NC}"
}

theme_reset() {
  require_themes
  local built_theme="$NXC_THEME_NAME"

  if [[ -z "$built_theme" ]]; then
    echo -e "${RED}No built theme name available${NC}" >&2
    return 1
  fi

  echo -e "Restoring Nix-declared theme: ${BOLD}$built_theme${NC}"
  theme_set "$built_theme"

  # Remove theme override if present
  local override_file="$NXC_FLAKE_ROOT/state/theme-override.nix"
  if [[ -f "$override_file" ]]; then
    rm "$override_file"
    echo -e "${GREEN}Removed theme-override.nix${NC}"
  fi
}

# Helper: get the single runtime theme name (or "mixed"/"custom")
theme_current_name() {
  require_themes

  local all_themes
  all_themes=$(jq -r 'keys[]' "$NXC_THEMES")
  local detected=""
  local all_agree=true

  for prog in $(list_programs); do
    local dir ext
    dir=$(get_mutable_dir "$prog")
    ext=$(get_extension "$prog")
    local theme_frag="$dir/00-theme.$ext"

    [[ ! -f "$theme_frag" || ! -s "$theme_frag" ]] && continue

    local frag_hash
    frag_hash=$(tail -n +2 "$theme_frag" | tr -d '[:space:]' | sha256sum | cut -d' ' -f1)

    local matched="custom"
    for t in $all_themes; do
      local expected
      expected=$(jq -r --arg t "$t" --arg p "$prog" '.[$t][$p] // empty' "$NXC_THEMES")
      if [[ -n "$expected" ]]; then
        local expected_hash
        expected_hash=$(echo "$expected" | tr -d '[:space:]' | sha256sum | cut -d' ' -f1)
        if [[ "$frag_hash" == "$expected_hash" ]]; then
          matched="$t"
          break
        fi
      fi
    done

    if [[ -z "$detected" ]]; then
      detected="$matched"
    elif [[ "$detected" != "$matched" ]]; then
      echo "mixed"
      return
    fi
  done

  echo "${detected:-none}"
}
