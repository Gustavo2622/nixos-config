{
  config,
  pkgs,
  inputs,
  outputs,
  lib,
  osConfig,
  ...
}: rec {
  imports = [
    ./hyprland/
  ];
  options = {};
  config = {
    # Set default browser for hyprland
    hyprland-hm-config.web_browser = "brave";

    home.packages = 
    (with pkgs; [
      firefox
      qutebrowser
    ]);

    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      extensions = [
	{ id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin?
      ];
      commandLineArgs = [
	"--disable-features=WebRtcAllowInputVolumeAdjustment"
      ];
    };
  };
}

