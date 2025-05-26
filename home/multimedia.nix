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
	# Video player
	mpv

	# Music player
	tauon
	nuclear
    ]);
  };
}
