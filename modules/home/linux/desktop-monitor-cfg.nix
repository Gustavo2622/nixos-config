# Autorandr profile "home" for a 4K LG Ultra HD monitor: 0.5x scale, gamma
# correction, 172 DPI.
{
  lib,
  config,
  pkgs,
  ...
}: {
  options = {
    desktop-monitor-cfg.enable =
      lib.mkEnableOption "enable desktop-monitor-cfg module";
  };

  config = let
    profiles = {
      "home" = {
        fingerprint = {
          DP-0 = "00ffffffffffff001e6d095b92b105000a190104b53c22789e3035a7554ea3260f50542108007140818081c0a9c0d1c081000101010150d000a0f0703e800890650c58542100001a286800a0f0703e800890650c58542100001a000000fd00383d1e8738000a202020202020000000fc004c4720556c7472612048440a2001050203117144900403012309070783010000023a801871382d40582c450058542100001e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041";
        };
        config = {
          DP-0 = {
            enable = true;
            primary = true;
            position = "0x0";
            mode = "3840x2160";
            gamma = "1.0:0.909:0.833";
            rate = "60.00";
            scale = {
              x = 0.5;
              y = 0.5;
            };
            dpi = 172;
          };
        };
      };
    };
  in
    lib.mkIf config.desktop-monitor-cfg.enable {
      programs.autorandr = {
        enable = true;
        inherit profiles;
      };
      services.autorandr.enable = true;
    };
}
