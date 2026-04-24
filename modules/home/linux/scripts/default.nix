# Linux-only scripts (Hyprland/Wayland/QuickShell)
{
  config,
  pkgs,
  username,
  ...
}: {
  home.packages = [
    (import ./emopicker9000.nix {inherit pkgs;})
    (import ./keybinds.nix {inherit pkgs;})
    (import ./keybind-cheatsheet.nix {inherit pkgs;})
    (import ./qs-keybinds.nix {inherit pkgs;})
    (import ./note-from-clipboard.nix {inherit pkgs;})
    (import ./nvidia-offload.nix {inherit pkgs;})
    (import ./rofi-launcher.nix {inherit pkgs;})
    (import ./screenshootin.nix {inherit pkgs;})
    (import ./squirtle.nix {inherit pkgs;})
    (import ./task-waybar.nix {inherit pkgs;})
    (import ./wallsetter.nix {
      inherit pkgs;
      inherit username;
    })
    # Cheatsheets viewer (QuickShell)
    (import ./qs-cheatsheets.nix {inherit config pkgs;})
    # QuickShell scripts
    (import ./qs-vid-wallpapers.nix {inherit pkgs;})
    (import ./qs-vid-wallpapers-apply.nix {inherit pkgs;})
    (import ./qs-vid-wallpapers-watchdog.nix {inherit pkgs;})
    (import ./qs-wallpapers.nix {inherit pkgs;})
    (import ./qs-wallpapers-apply.nix {inherit pkgs;})
    (import ./qs-wallpapers-restore.nix {inherit pkgs;})
    (import ./qs-wlogout.nix {inherit pkgs;})
    (import ./qs-docs.nix {inherit pkgs;})
    (import ./launch-nwg-menu.nix {inherit pkgs;})
    (import ./hyprland-dock.nix {inherit pkgs;})
  ];
}
