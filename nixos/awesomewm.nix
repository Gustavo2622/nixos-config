{config, options, pkgs, lib, ...}:

{
  options = {
    awesomewm.enable = lib.mkEnableOption 
      "Whether to enable awesomewm config and related things.";
  };

  config = {
    services = {
      xserver = {
	  enable = true;

	  windowManager.awesome = {
	    enable = true;
	    luaModules = with pkgs.luaPackages; [
	      luarocks # package manager for lua modules
	      luadbi-mysql # database abstraction
	    ];
	  };
      };

      displayManager = {
	sddm.enable = true;
	defaultSession = "none+awesome";
      };
    };
  };
}
