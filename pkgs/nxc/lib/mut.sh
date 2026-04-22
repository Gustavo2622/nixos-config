# nxc mut — mutable state management

cmd_mut() {
  require_registry
  local subcmd="status"
  if [[ $# -gt 0 ]]; then
    subcmd="$1"
    shift
  fi

  case "$subcmd" in
    status) mut_status "$@" ;;
    show) mut_show "$@" ;;
    edit) mut_edit "$@" ;;
    reset) mut_reset "$@" ;;
    sync) mut_sync "$@" ;;
    -h|--help|help) mut_usage ;;
    *) echo -e "${RED}Unknown mut subcommand:${NC} $subcmd" >&2; mut_usage >&2; return 1 ;;
  esac
}

mut_usage() {
  echo -e "${BOLD}nxc mut${NC} — mutable state management"
  echo ""
  echo -e "${BOLD}Usage:${NC} nxc mut <command> [args]"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo "  status              Overview of all mutable state"
  echo "  show [program]      Display mutable fragment contents"
  echo "  edit <program>      Edit mutable fragments"
  echo "  reset <program>     Wipe all mutable state for a program"
  echo "  sync                Bidirectional sync disk ↔ state/"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  nxc mut status              Show all programs"
  echo "  nxc mut edit hyprland       Edit Hyprland overrides"
  echo "  nxc mut show nvim           Show nvim fragments"
  echo "  nxc mut reset waybar        Remove all waybar overrides"
}

mut_status() {
  local json_flag=false
  [[ "${1:-}" == "--json" ]] && json_flag=true

  local json_arr="["
  local first=true

  printf "${BOLD}%-15s %-10s %-8s %-15s${NC}\n" "PROGRAM" "OVERRIDE" "FRAGS" "SYNC"

  for prog in $(list_programs); do
    local dir ext frag_count override sync_status
    dir=$(get_mutable_dir "$prog")
    ext=$(get_extension "$prog")

    # Count fragments
    if [[ -d "$dir" ]]; then
      frag_count=$(find "$dir" -name "*.$ext" -type f 2>/dev/null | wc -l)
    else
      frag_count=0
    fi

    # Check if any fragment has content
    if [[ "$frag_count" -gt 0 ]]; then
      local total_size
      total_size=$(cat "$dir"/*."$ext" 2>/dev/null | wc -c)
      if [[ "$total_size" -gt 0 ]]; then
        override="active"
      else
        override="empty"
      fi
    else
      override="none"
    fi

    # Sync status: compare disk hash vs state/ hash vs stored hash
    local disk_hash state_hash stored_hash
    disk_hash=$(hash_dir "$dir" "$ext")
    state_hash=$(hash_dir "$NXC_FLAKE_ROOT/state/$prog" "$ext" 2>/dev/null || echo "empty")

    if [[ -f "$NXC_HASHES" ]]; then
      stored_hash=$(grep "^$prog " "$NXC_HASHES" 2>/dev/null | awk '{print $2}' || echo "none")
    else
      stored_hash="none"
    fi

    if [[ "$stored_hash" == "none" ]]; then
      sync_status="untracked"
    elif [[ "$disk_hash" == "$stored_hash" && "$state_hash" == "$stored_hash" ]]; then
      sync_status="clean"
    elif [[ "$disk_hash" != "$stored_hash" && "$state_hash" == "$stored_hash" ]]; then
      sync_status="disk-changed"
    elif [[ "$disk_hash" == "$stored_hash" && "$state_hash" != "$stored_hash" ]]; then
      sync_status="state-changed"
    else
      sync_status="conflict"
    fi

    # Color the status
    local override_color sync_color
    case "$override" in
      active) override_color="${GREEN}" ;;
      empty) override_color="${DIM}" ;;
      none) override_color="${DIM}" ;;
    esac
    case "$sync_status" in
      clean) sync_color="${GREEN}" ;;
      untracked) sync_color="${DIM}" ;;
      disk-changed) sync_color="${YELLOW}" ;;
      state-changed) sync_color="${CYAN}" ;;
      conflict) sync_color="${RED}" ;;
    esac

    printf "%-15s ${override_color}%-10s${NC} %-8s ${sync_color}%-15s${NC}\n" \
      "$prog" "$override" "$frag_count" "$sync_status"

    if $json_flag; then
      $first || json_arr+=","
      first=false
      json_arr+="{\"program\":\"$prog\",\"override\":\"$override\",\"fragments\":$frag_count,\"sync\":\"$sync_status\"}"
    fi
  done

  if $json_flag; then
    json_arr+="]"
    echo "$json_arr" | jq .
  fi
}

mut_show() {
  local prog="${1:-}"

  if [[ -n "$prog" ]]; then
    local check_dir
    check_dir=$(get_mutable_dir "$prog")
    if [[ -z "$check_dir" ]]; then
      echo -e "${RED}Unknown program:${NC} $prog" >&2
      echo -e "Registered: $(list_programs | tr '\n' ' ')" >&2
      return 1
    fi
  fi

  if [[ -z "$prog" ]]; then
    # Show all non-empty programs
    for p in $(list_programs); do
      local dir ext
      dir=$(get_mutable_dir "$p")
      ext=$(get_extension "$p")
      if [[ -d "$dir" ]] && ls "$dir"/*."$ext" &>/dev/null; then
        local total_size
        total_size=$(cat "$dir"/*."$ext" 2>/dev/null | wc -c)
        if [[ "$total_size" -gt 0 ]]; then
          echo -e "${BOLD}${CYAN}=== $p ===${NC}"
          for f in "$dir"/*."$ext"; do
            echo -e "${DIM}--- $(basename "$f") ---${NC}"
            cat "$f"
            echo ""
          done
        fi
      fi
    done
  else
    local dir ext
    dir=$(get_mutable_dir "$prog")
    ext=$(get_extension "$prog")
    if [[ ! -d "$dir" ]]; then
      echo -e "${YELLOW}No mutable directory for ${BOLD}$prog${NC}" >&2
      return 1
    fi
    if ! ls "$dir"/*."$ext" &>/dev/null; then
      echo -e "${DIM}$prog: no fragments${NC}"
      return
    fi
    for f in "$dir"/*."$ext"; do
      echo -e "${DIM}--- $(basename "$f") ---${NC}"
      cat "$f"
      echo ""
    done
  fi
}

mut_edit() {
  local prog="${1:-}"
  local fragment="${2:-}"

  if [[ -z "$prog" ]]; then
    echo -e "${RED}Usage:${NC} nxc mut edit <program> [fragment]" >&2
    return 1
  fi

  local dir ext
  dir=$(get_mutable_dir "$prog")
  if [[ -z "$dir" ]]; then
    echo -e "${RED}Unknown program:${NC} $prog" >&2
    echo -e "Registered: $(list_programs | tr '\n' ' ')" >&2
    return 1
  fi
  ext=$(get_extension "$prog")
  mkdir -p "$dir"

  if [[ -n "$fragment" ]]; then
    # Edit specific fragment
    local fpath="$dir/$fragment"
    [[ "$fragment" != *".$ext" ]] && fpath="$dir/$fragment.$ext"

    # Seed from state/ if file doesn't exist
    if [[ ! -f "$fpath" ]]; then
      local state_frag
      state_frag="$NXC_FLAKE_ROOT/state/$prog/$(basename "$fpath")"
      if [[ -f "$state_frag" ]]; then
        echo -e "${CYAN}State snapshot found:${NC}"
        cat "$state_frag"
        echo ""
        read -rp "Seed from state/? [Y/n/q] " choice
        case "$choice" in
          q|Q) return 0 ;;
          n|N) touch "$fpath" ;;
          *) cp "$state_frag" "$fpath" ;;
        esac
      else
        touch "$fpath"
      fi
    fi

    ${EDITOR:-nvim} "$fpath"
  else
    # No fragment specified — pick or create
    local fragments
    fragments=$(find "$dir" -name "*.$ext" -type f 2>/dev/null | sort)
    local count=0
    if [[ -n "$fragments" ]]; then
      count=$(echo "$fragments" | wc -l)
    fi

    if [[ "$count" -eq 0 ]]; then
      # Create first user fragment
      local new_frag="$dir/50-user.$ext"
      touch "$new_frag"
      ${EDITOR:-nvim} "$new_frag"
    elif [[ "$count" -eq 1 ]]; then
      ${EDITOR:-nvim} "$fragments"
    else
      local choice
      choice=$(printf "%s\n[new fragment]" "$fragments" | \
        sed "s|$dir/||" | \
        fzf --prompt="$prog fragment> ")
      if [[ "$choice" == "[new fragment]" ]]; then
        read -rp "Fragment name (e.g., 50-keybinds): " fname
        [[ -z "$fname" ]] && return 0
        [[ "$fname" != *".$ext" ]] && fname="$fname.$ext"
        touch "$dir/$fname"
        ${EDITOR:-nvim} "$dir/$fname"
      elif [[ -n "$choice" ]]; then
        ${EDITOR:-nvim} "$dir/$choice"
      fi
    fi
  fi

  # Offer reload after edit
  local reload_cmd
  reload_cmd=$(get_field "$prog" "reloadCmd")
  if [[ -n "$reload_cmd" && "$reload_cmd" != "null" ]]; then
    read -rp "Reload $prog? [Y/n] " choice
    case "$choice" in
      n|N) ;;
      *) eval "$reload_cmd" && echo -e "${GREEN}Reloaded.${NC}" ;;
    esac
  fi
}

mut_reset() {
  local prog="${1:-}"
  if [[ -z "$prog" ]]; then
    echo -e "${RED}Usage:${NC} nxc mut reset <program>" >&2
    return 1
  fi

  local dir
  dir=$(get_mutable_dir "$prog")
  if [[ -z "$dir" ]]; then
    echo -e "${RED}Unknown program:${NC} $prog" >&2
    echo -e "Registered: $(list_programs | tr '\n' ' ')" >&2
    return 1
  fi

  echo -e "${YELLOW}Will delete:${NC}"
  [[ -d "$dir" ]] && echo "  $dir/ (mutable fragments)"
  [[ -d "$NXC_FLAKE_ROOT/state/$prog" ]] && echo "  state/$prog/ (snapshots)"
  echo "  state/.hashes entry"
  [[ -d "$NXC_ANCESTORS/$prog" ]] && echo "  state/.ancestors/$prog/"

  read -rp "Reset $prog? This removes all mutable state. [y/N] " choice
  case "$choice" in
    y|Y)
      rm -rf "${dir:?}"
      rm -rf "${NXC_FLAKE_ROOT:?}/state/${prog:?}"
      rm -rf "${NXC_ANCESTORS:?}/${prog:?}"
      sed -i "/^$prog /d" "$NXC_HASHES" 2>/dev/null
      mkdir -p "$dir"  # recreate empty
      echo -e "${GREEN}Reset $prog.${NC}"

      local reload_cmd
      reload_cmd=$(get_field "$prog" "reloadCmd")
      if [[ -n "$reload_cmd" && "$reload_cmd" != "null" ]]; then
        read -rp "Reload $prog (now using pure declarative config)? [Y/n] " rc
        case "$rc" in
          n|N) ;;
          *) eval "$reload_cmd" ;;
        esac
      fi
      ;;
    *) echo -e "${BLUE}Cancelled.${NC}" ;;
  esac
}

mut_sync() {
  for prog in $(list_programs); do
    local dir ext disk_hash state_hash stored_hash
    dir=$(get_mutable_dir "$prog")
    ext=$(get_extension "$prog")
    disk_hash=$(hash_dir "$dir" "$ext")

    local state_dir="$NXC_FLAKE_ROOT/state/$prog"
    state_hash=$(hash_dir "$state_dir" "$ext" 2>/dev/null || echo "empty")

    if [[ -f "$NXC_HASHES" ]]; then
      stored_hash=$(grep "^$prog " "$NXC_HASHES" 2>/dev/null | awk '{print $2}' || echo "none")
    else
      stored_hash="none"
    fi

    # Use state/ as ancestor when no explicit ancestor exists
    local ancestor_dir="$NXC_ANCESTORS/$prog"
    if [[ ! -d "$ancestor_dir" ]]; then
      ancestor_dir="$state_dir"
    fi

    # Skip if clean
    if [[ "$disk_hash" == "$state_hash" ]]; then
      # Update hash if not tracked yet
      if [[ "$stored_hash" == "none" && "$disk_hash" != "empty" ]]; then
        mkdir -p "$(dirname "$NXC_HASHES")"
        echo "$prog $disk_hash" >> "$NXC_HASHES"
      fi
      continue
    fi

    echo -e "\n${BOLD}${CYAN}$prog${NC} — disk and state/ differ"

    # Determine direction
    if [[ "$stored_hash" == "none" ]]; then
      # First sync — no ancestor, show simple diff
      echo -e "${DIM}(first sync — no baseline)${NC}"
      diff --color=auto -ru "$state_dir" "$dir" 2>/dev/null || true
    elif [[ "$disk_hash" != "$stored_hash" && "$state_hash" == "$stored_hash" ]]; then
      echo -e "${YELLOW}Disk has changes${NC}"
      diff --color=auto -ru "$state_dir" "$dir" 2>/dev/null || true
    elif [[ "$disk_hash" == "$stored_hash" && "$state_hash" != "$stored_hash" ]]; then
      echo -e "${CYAN}State/ has changes${NC}"
      diff --color=auto -ru "$dir" "$state_dir" 2>/dev/null || true
    else
      echo -e "${RED}Both changed (conflict)${NC}"
      # Show both diffs against ancestor
      echo -e "${DIM}--- disk vs ancestor ---${NC}"
      diff --color=auto -ru "$ancestor_dir" "$dir" 2>/dev/null || true
      echo -e "${DIM}--- state/ vs ancestor ---${NC}"
      diff --color=auto -ru "$ancestor_dir" "$state_dir" 2>/dev/null || true
    fi

    # Prompt
    if [[ "$disk_hash" != "$stored_hash" && "$state_hash" == "$stored_hash" ]]; then
      read -rp "Copy disk → state/? [Y/n/s] " choice
      case "$choice" in
        s|S) echo "---"; diff --color=auto -ru "$state_dir" "$dir" 2>/dev/null || true ;;
        n|N) continue ;;
        *)
          mkdir -p "$state_dir"
          rm -f "$state_dir"/*."$ext" 2>/dev/null
          cp "$dir"/*."$ext" "$state_dir/" 2>/dev/null || true
          ;;
      esac
    elif [[ "$disk_hash" == "$stored_hash" && "$state_hash" != "$stored_hash" ]]; then
      read -rp "Copy state/ → disk? [Y/n/s] " choice
      case "$choice" in
        s|S) echo "---"; diff --color=auto -ru "$state_dir" "$dir" 2>/dev/null || true ;;
        n|N) continue ;;
        *)
          rm -f "$dir"/*."$ext" 2>/dev/null
          cp "$state_dir"/*."$ext" "$dir/" 2>/dev/null || true
          ;;
      esac
    else
      # Conflict
      read -rp "Take [d]isk / [s]tate / [m]erge / s[k]ip? " choice
      case "$choice" in
        d)
          mkdir -p "$state_dir"
          rm -f "$state_dir"/*."$ext" 2>/dev/null
          cp "$dir"/*."$ext" "$state_dir/" 2>/dev/null || true
          ;;
        s)
          rm -f "$dir"/*."$ext" 2>/dev/null
          cp "$state_dir"/*."$ext" "$dir/" 2>/dev/null || true
          ;;
        m)
          echo -e "${YELLOW}Manual merge — opening both directories in editor${NC}"
          ${EDITOR:-nvim} -O "$dir" "$state_dir"
          ;;
        *) continue ;;
      esac
    fi

    # Update hash and ancestor
    local new_hash
    new_hash=$(hash_dir "$dir" "$ext")
    mkdir -p "$(dirname "$NXC_HASHES")" "$NXC_ANCESTORS/$prog"
    # Update or add hash entry
    if grep -q "^$prog " "$NXC_HASHES" 2>/dev/null; then
      sed -i "s/^$prog .*/$prog $new_hash/" "$NXC_HASHES"
    else
      echo "$prog $new_hash" >> "$NXC_HASHES"
    fi
    # Update ancestor
    rm -f "$NXC_ANCESTORS/$prog"/*."$ext" 2>/dev/null
    cp "$dir"/*."$ext" "$NXC_ANCESTORS/$prog/" 2>/dev/null || true

    echo -e "${GREEN}Synced $prog.${NC}"
  done
}
