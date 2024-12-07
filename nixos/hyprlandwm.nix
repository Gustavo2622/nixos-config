
{config, options, pkgs, lib, inputs, ...}:

{
  options = {
    hyprlandwm.enable = lib.mkEnableOption 
      "Whether to enable hyprland wm config and related things.";
  };

  config = lib.mkIf (config.hyprlandwm.enable) {
    programs.hyprland = {
      enable = true;
      # set the flake package
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      # set the portal also, to remain in sync
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      xwayland.enable = true;
    };
    services.displayManager = {
      sddm = {
	enable = true;
	wayland.enable = true;
      };
      enable = true;
      logToFile = true;
      # defaultSession = "hyprland";
    };
  };
}
