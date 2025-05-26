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

	# Task management
	super-productivity
	# Find some more for here

      ]);
  };
}
