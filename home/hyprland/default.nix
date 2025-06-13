{
  lib,
  config,
  inputs,
  pkgs,
  ...
} @ args: {
  options = with lib; {
    hyprland-hm-config.enable = mkEnableOption "enable home manager hyprland config";
    hyprland-hm-config.term = mkOption {
      description = "Terminal to use with hyprland";
      type = with types; submodule {
	options = rec {
	  exe = mkOption {
	    type = str;
	    example = "kitty";
	    default = "kitty";
	  };
	  run_subcommand = mkOption {
	    type = str;
	    example = "kitty";
	    default = exe;
	  };
	};
      };
    };
    hyprland-hm-config.web_browser = mkOption {
      type = types.str;
      default = "firefox";
      example = "firefox";
    };
  };

  imports = [
    ./smart_gaps.nix
  ];

  config = 
  let 
    inherit (config.hyprland-hm-config) term web_browser;
  in lib.mkIf config.hyprland-hm-config.enable {
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
            "$mod, Return, exec, ${term.exe}"
            "$mod, K, exec, kitty"
	    "$mod, B, exec, ${web_browser}"
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
		  "$mod CTRL, code:1${toString i}, focusworkspaceoncurrentmonitor, ${toString ws}"
                ]
              )
              9)
          );

        windowrulev2 = [
          "suppressevent maximize, class:.*"
          "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
        ];

	workspace = [
	  "1, monitor:DVI-D-1, default:true"
	  "2, monitor:DP-1, default:true"
	  "9, monitor:HDMI-A-1, default:true"

	  "3, monitor:DP-1"
	  "4, monitor:DVI-D-1"
	  "5, monitor:DP-1"
	  "6, monitor:DVI-D-1"
	  "7, monitor:DVI-D-1"
	];

        # Startup programs
	exec-once = [
	  "waybar 2>&1 > ~/waybar_log.txt"
	  "[workspace 1 silent] ${term.exe}"
	  "[workspace 2 silent; fullscreen] ${web_browser}"
	  "[workspace 3 silent; fullscreen] ferdium"
	  "[workspace 4 silent; fullscreen] anki"
	  "[workspace 5 silent; fullscreen] bitwarden"
	  "[workspace 6 silent; fullscreen] obsidian"
	  "[workspace 7 silent; fullscreen] discord" 
	  "[workspace 9 silent; fullscreen] ${term.run_subcommand} btop"
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
    hyprland-smart-gaps.enable = true;

    # hyprland depends on kitty
    programs.kitty.enable = true;
  };
}
