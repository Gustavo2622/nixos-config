# Common helpers for nxc subcommands

NXC_STATE_DIR="$HOME/.local/state/nxc"
NXC_REGISTRY="$NXC_STATE_DIR/registry.json"
NXC_THEMES="$NXC_STATE_DIR/themes.json"
NXC_HASHES="$NXC_FLAKE_ROOT/state/.hashes"
NXC_ANCESTORS="$NXC_FLAKE_ROOT/state/.ancestors"
NXC_STALE_DAYS="${NXC_STALE_DAYS:-7}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Spinner characters
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

# Run a command with a spinner + elapsed timer.
# Usage: run_with_spinner "message" output_varname command [args...]
# Both stdout and stderr are captured into output_varname.
run_with_spinner() {
  local msg="$1"
  local output_var="$2"
  shift 2

  local tmpfile
  tmpfile=$(mktemp)
  local start=$SECONDS

  "$@" >"$tmpfile" 2>&1 &
  local pid=$!

  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local elapsed=$(( SECONDS - start ))
    local c="${SPINNER_CHARS:i%10:1}"
    printf '\r\033[2K  %b %s (%ds)' "$c" "$msg" "$elapsed" >&2
    i=$((i + 1))
    sleep 0.1
  done
  printf '\r\033[2K' >&2

  wait "$pid" || true
  eval "$output_var"'=$(cat "$tmpfile")'
  rm -f "$tmpfile"
}

require_registry() {
  if [[ ! -f "$NXC_REGISTRY" ]]; then
    echo -e "${RED}Error:${NC} Registry not found at $NXC_REGISTRY" >&2
    echo -e "Run ${CYAN}nh os switch /etc/nixos${NC} to generate it." >&2
    exit 1
  fi
}

require_themes() {
  if [[ ! -f "$NXC_THEMES" ]]; then
    echo -e "${RED}Error:${NC} Theme manifest not found at $NXC_THEMES" >&2
    echo -e "Run ${CYAN}nh os switch /etc/nixos${NC} to generate it." >&2
    exit 1
  fi
}

# List all registered program names
list_programs() {
  jq -r 'keys[]' "$NXC_REGISTRY"
}

# Get a field from a program's registry entry
get_field() {
  local prog="$1" field="$2"
  jq -r --arg p "$prog" --arg f "$field" '.[$p][$f] // empty' "$NXC_REGISTRY"
}

# Get the mutable directory for a program
get_mutable_dir() {
  get_field "$1" "mutableDir"
}

# Get the file extension for a program
get_extension() {
  get_field "$1" "fileExtension"
}

# List fragment files for a program (sorted)
list_fragments() {
  local prog="$1"
  local dir
  dir=$(get_mutable_dir "$prog")
  local ext
  ext=$(get_extension "$prog")
  if [[ -d "$dir" ]]; then
    find "$dir" -name "*.$ext" -type f 2>/dev/null | sort
  fi
}

# Hash a file (sha256, just the hash)
hash_file() {
  if [[ -f "$1" ]]; then
    sha256sum "$1" | cut -d' ' -f1
  else
    echo "empty"
  fi
}

# Hash an entire fragment directory
hash_dir() {
  local dir="$1" ext="$2"
  if [[ -d "$dir" ]] && ls "$dir"/*."$ext" &>/dev/null; then
    cat "$dir"/*."$ext" 2>/dev/null | sha256sum | cut -d' ' -f1
  else
    echo "empty"
  fi
}
