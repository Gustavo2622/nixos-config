{
  config,
  options,
  pkgs,
  lib,
  ...
}: {
  options = {
    awesomewm.enable =
      lib.mkEnableOption
      "Whether to enable awesomewm config and related things.";
  };

  config = lib.mkIf (config.awesomewm.enable) {
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
        autoLogin = {
          enable = true;
          user = "gustavo";
        };
      };
    };
  };
}
