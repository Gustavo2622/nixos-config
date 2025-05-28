{
  config,
  pkgs,
  inputs,
  outputs,
  lib,
  osConfig,
  ...
}: rec {
  imports = [
    ./hyprland
  ];
  options = {};
  config = {
    ## Terminal Emulators ##
    # Set hyprland terminal emulator
    hyprland-hm-config.term = rec {
      exe = "ghostty";
      run_subcommand = exe + " -e"; 
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
    programs.kitty = {
      enable = true;
      font = {
	size = 16;
      };
      extraConfig = ''
	font_features = FiraCode-Mono +liga + calt
      '';
    };

    # Maybe the one true term emu?
    programs.ghostty = {
      enable = true;
      enableBashIntegration = true;
      settings = {	
	font-size = 16;
	font-family = lib.mkForce "Iosevka NFM";
	keybind = [
	  "ctrl+h=goto_split:left"
	  "ctrl+l=goto_split:right"
	];
      };
    };

    ## Starship for Prompt ##
    programs.starship = {
      enable = true;

      settings = {
	add_newline = false;

	aws.disabled = true;
	gcloud.disabled = true;
	line_break.disabled = true;
      };
    };


    ## Terminal Shells ##
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

    ## Multiplexers ##
    programs.tmux.enable = true;

  };
}
