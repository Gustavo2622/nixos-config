{
  config,
  pkgs,
  inputs,
  outputs,
  lib,
  osConfig,
  ...
}: rec {
  imports = [];
  options = {};
  config = {
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

