{config, pkgs, inputs, lib, ...}:

rec {
  imports = [
    ../modules/config/desktop-monitor-cfg.nix
  ];

  home.username="gustavo";
  home.homeDirectory = "/home/${home.username}";
  xdg.enable = true; # Sets XDG_CONFIG env vars

  # link the config file in cur dir to the specified location in home
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in './scripts' to '~/.config/i3/scripts'
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true; # link recursively 
  #   executable = true; # make all files exec
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi
  xresources.properties = {
    "Xcursor.size" = lib.mkDefault 16;
  };

  xsession = {
    enable = true;
    windowManager.awesome = {
      enable = true;
      luaModules = with pkgs.luaPackages; [
	luarocks # package manager for lua modules
	luadbi-mysql # database abstraction
      ];
    };

    initExtra = ''
      dbus-update-activation-environment --systemd DISPLAY
      eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
      export SSH_AUTH_SOCK
    '';
  };
  xdg.configFile = {
    "awesome/rc.lua".text = builtins.readFile ./awesome/rc.lua;
  };
  desktop-monitor-cfg.enable = true;

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
	"DVI-D-1, 1920x1200@59.95000, 3840x0, 1"
        "HDMI-A-1, 1920x1080@60.00000, 3840x1200, 1"
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
	[ "$mod, F, exec, firefox"
	  "$mod, Enter, exec, alacritty"
	  ", Print, exec, grimblast copy area"
	  "$mod, Q, exec, kitty"
	  "$mod, C, killactive"
	  "$mod, V, togglefloating"
	  "$mod, R, exec, $menu"
	  "$mod, P, pseudo"
	  "$mod, J, togglesplit" 
	  "$mod, S, togglespecialworkspace, magic"
	  "$mod SHIFT, S, movetoworkspace, special:magic"
	]
	++ (
	  # workspaces
	  # binds $mods + [shift +] {1..9} to [move to] workspace {1..9}
	  builtins.concatLists (builtins.genList (i:
	    let ws = i + 1;
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

      "plugin:borders-plus-plus" = {
	add_borders = 1;

	"col.border_1" = "rgb(ffffff)";
	"col.border_2" = "rgb(2222ff)";

	border_size_1 = 10;
	border_size_2 = -1; # -1 = default

	natural_rounding = "yes";
      };
    };
  };

  # Packages that should be installed to the user profile
  home.packages = (with pkgs; [
    
    neofetch # Looks cool
    nnn # terminal file manager

    # archives
    zip 
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively search directories for a regex
    jq # command line json
    yq-go # yaml processor https://github.com/mikefarah/yq
    eza # modern replacement for ls
    fzf # command line fuzzy find

    # networking tools
    mtr # network diagnostics
    iperf3
    dnsutils # dig + nslookup
    ldns # drill, replacement for dig
    aria2 # command line, lightweight, multiprotocol multi source download tool
    socat # netcat but better
    nmap # heheh
    ipcalc # ip address calculator

    # misc
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    # provide 'nom' = nix + more output
    nix-output-monitor

    # productivity
    hugo # static site generator
    glow # markdown previewer for term

    btop # htop but better?
    iotop # io mon
    iftop # ip mon

    # sys call monitoring
    strace # sys call
    ltrace # lib call
    lsof # list open files

    # sys tools
    sysstat
    lm_sensors # sensors command
    ethtool
    pciutils # lspci
    usbutils # lsusb

    # Pretty fonts
    nerd-fonts.iosevka
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono

    # Password Manager
    bitwarden-cli
    bitwarden-desktop
    bitwarden-menu

    # Web apps
    ferdium

    # Web browsers
    firefox
    qutebrowser
  ]) ++ [ inputs.nixvim.packages.${pkgs.system}.nvim ];

  programs.git = {
    enable = true; # live and die by the protocol
    userName = "Gustavo Delerue";
    userEmail = "gxdelerue@proton.me";
  # userEmail = "gxdelerue@gmail.com";
  };

  programs.lazygit.enable = true;

  # pretty prompts for shells
  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;

      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  # come back to me, terminal emulator
  programs.alacritty = {
    enable = true;
    # custom settings
    settings = {
      env.TERM = "xterm-256color";
      font = lib.mkForce {
	normal = {
	  family = "Fira Code Nerd Font";
	  style = "Regular";
	};

	bold = {
	  family = "Fira Code Nerd Font";
	  style = "Bold";
	};

	italic = {
	  family = "Fira Code Nerd Font";
	  style = "Italic";
	};

	bold_italic = {
	  family = "Fira Code Nerd Font";
	  style = "Bold Italic";
	};
        size = 16;
      };
      scrolling.multiplier = 5;
      selection.save_to_clipboard = true;
    };
  };

  # another term emulator, also hyprland dep
  programs.kitty.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
    # TODO add custom bashrc here
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin"
    '';

    # set some aliases
    shellAliases = {
      urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
  };

  programs.tmux.enable = true;

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  services.gnome-keyring = {
    enable = true;
    components = [ "pkcs11" "secrets" "ssh" ];
  };

  fonts.fontconfig.enable = true;

  home.stateVersion = "24.11";

  # Let Home Manager do its thang
  programs.home-manager.enable = true;
}
