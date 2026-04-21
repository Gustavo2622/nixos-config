# OSC 52 clipboard script — works locally and over SSH.
# Usage: echo "text" | clip
#        clip < file.txt
# Copies stdin to the local terminal's clipboard via OSC 52 escape sequence.
# Requires a terminal that supports OSC 52 (Ghostty, Kitty, etc.).
{pkgs, ...}:
pkgs.writeShellScriptBin "clip" ''
  if [ -t 0 ]; then
    echo "Usage: echo 'text' | clip" >&2
    echo "       clip < file.txt" >&2
    exit 1
  fi

  # Read stdin as-is, base64-encode, send via OSC 52
  # Faithfully copies exactly what's piped in — no newline stripping
  data=$(${pkgs.coreutils}/bin/base64 | tr -d '\n')
  printf '\033]52;c;%s\a' "$data"
''
