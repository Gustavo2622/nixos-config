
{
  lib,
  config,
  inputs,
  pkgs,
  ...
} @ args: {
  options = {
    hyprland-smart-gaps.enable = lib.mkEnableOption "enable home manager hyprland config";
  };

  imports = [];

  config = lib.mkIf config.hyprland-smart-gaps.enable {
    wayland.windowManager.hyprland = {
      settings = {
	workspace = [
	  "w[tv1], gapsout:0, gapsin:0"
	  "f[1], gapsout:0, gapsin:0"
	];
	windowrulev2 = [
	  "bordersize 0, floating:0, onworkspace:w[tv1]"
	  "rounding 0, floating:0, onworkspace:w[tv1]"
	  "bordersize 0, floating:0, onworkspace:f[1]"
	  "rounding 0, floating:0, onworkspace:f[1]"
	];
      };
    };
  };
}
