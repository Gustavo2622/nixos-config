{
  lib,
  config,
  inputs,
  pkgs,
  ...
} @ args: {
  options = {
    hyprland-hm-config.enable = lib.mkEnableOption "enable home manager hyprland config";
  };

  imports = [];

  config = lib.mkIf config.hyprland-hm-config.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      plugins = [
        inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
        inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.borders-plus-plus
        # "/absolute/path/to/plugin.sp"
      ];
      settings = {
        # required by Nvidia
        env = [
          "LIBVA_DRIVER_NAME,nvidia"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        ];
        cursor = {
          no_hardware_cursors = true;
        };
        monitor = [
          "DP-1, 3840x2160@60.00000, 0x0, 2"
          "DVI-D-1, 1920x1200@59.95000, 1920x0, 1"
          "HDMI-A-1, 1920x1080@60.00000, 1920x1200, 1"
        ];
        general = {
          gaps_in = 5;
          gaps_out = 20;

          border_size = 2;
          "col.active_border" = lib.mkDefault ["rgba(33ccffee) rgba(00ff99ee) 45deg"];
          "col.inactive_border" = lib.mkDefault "rgba(595959aa)";

          resize_on_border = false;

          # https://wiki.hyprland.org/Configuring/Tearing/
          allow_tearing = false;

          layout = "dwindle";
        };
        decoration = {
          rounding = 10;

          active_opacity = 1.0;
          inactive_opacity = 0.9;

          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = lib.mkDefault "rgba(1a1a1aee)";
          };

          blur = {
            enabled = true;
            size = 3;
            passes = 1;

            vibrancy = 0.1696;
          };
        };

        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };

        master = {
          new_status = "master";
        };

        input = {
          kb_layout = "us";
          kb_variant = "";
          kb_model = "";
          kb_options = "ctrl:swapcaps";
          kb_rules = "";

          follow_mouse = 1;
          sensitivity = 0;
        };
        "$mod" = "SUPER";
        bind =
          [
            "$mod, F, fullscreen"
            "$mod, Return, exec, alacritty"
            "$mod, Q, exec, qutebrowser"
            "$mod, K, exec, kitty"
            "$mod, C, killactive"
            "$mod, V, togglefloating"
            "$mod, R, exec, rofi -show drun"
            "$mod, P, pseudo"
            "$mod, J, togglesplit"
            "$mod, S, togglespecialworkspace, magic"
            "$mod SHIFT, S, movetoworkspace, special:magic"
          ]
          ++ (
            # workspaces
            # binds $mods + [shift +] {1..9} to [move to] workspace {1..9}
            builtins.concatLists (builtins.genList (
                i: let
                  ws = i + 1;
                in [
                  "$mod, code:1${toString i}, workspace, ${toString ws}"
                  "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
                ]
              )
              9)
          );

        windowrulev2 = [
          "suppressevent maximize, class:.*"
          "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
        ];

        # Startup programs
        exec-once = [
          "[workspace 1 silent; fullscreen] kitty btop"
          "[workspace 2 silent; fullscreen] qutebrowser"
          "[workspace 3 silent] alacritty"
        ];

        "plugin:borders-plus-plus" = {
          add_borders = 1;

          "col.border_1" = "rgb(ffffff)";
          "col.border_2" = "rgb(2222ff)";

          border_size_1 = 3;
          border_size_2 = -1; # -1 = default

          natural_rounding = "yes";
        };
      };
    };
  };
}
