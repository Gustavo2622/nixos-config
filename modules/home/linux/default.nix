# Linux-only home-manager modules — imports shared + linux-specific
{
  lib,
  vars,
  ...
}: {
  imports =
    [
      ../shared
      ./anki.nix
      ./bitwarden.nix
      ./browsers.nix
      ./cli
      ./desktop-monitor-cfg.nix
      ./gtk.nix
      ./hyprland
      ./latex.nix
      ./monitors.nix
      ./musescore.nix
      ./obs-studio.nix
      ./productivity.nix
      ./qt.nix
      ./rofi
      ./scripts
      ./stylix.nix
      ./swappy.nix
      ./swaync.nix
      ./user.nix
      ./virtmanager.nix
      ./wlogout
      ./xdg.nix
      ./yazi
    ]
    ++ lib.optional (vars.barChoice == "noctalia") ./noctalia.nix
    ++ lib.optional (vars.barChoice == "waybar") ./waybar;
}
