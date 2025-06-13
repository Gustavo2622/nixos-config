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
	# SRS 
	anki-bin
	
	# Note taking and all that magic
	obsidian

	# TODO: Find some more for here
      ]);
  };
}
