# Enables Hyprland from nixpkgs (not the flake input) with XWayland; installs
# kitty as a system-level terminal package.
{
  config,
  options,
  pkgs,
  lib,
  inputs,
  ...
}: {
  programs.hyprland = {
    enable = true;
    # set the flake package
    # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # set the portal also, to remain in sync
    # portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    withUWSM = false;
    xwayland.enable = true;
  };
  # Kitty as system-level fallback terminal — Hyprland uses it as default.
  # User config is in home-manager (terminals/kitty.nix); this ensures
  # a working terminal even if home-manager fails to activate.
  environment.systemPackages = with pkgs; [kitty];
}
