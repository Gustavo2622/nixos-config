# Toggles the swaync notification panel; adds a 0.1-second delay to allow
# Waybar to register the toggle signal.
{pkgs}:
pkgs.writeShellScriptBin "task-waybar" ''
  sleep 0.1
  ${pkgs.swaynotificationcenter}/bin/swaync-client -t &
''
