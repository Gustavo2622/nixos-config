# Application launcher: kills any existing rofi instance then opens rofi in drun mode.
{pkgs}:
pkgs.writeShellScriptBin "rofi-launcher" ''
  # check if rofi is already running
  if pidof rofi > /dev/null; then
    pkill rofi
  fi
  rofi -show drun
''
