{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./zshrc-personal.nix
  ];

  home.packages = [pkgs.atool];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = ["main" "brackets" "pattern" "regexp" "root" "line"];
    };
    historySubstringSearch.enable = true;

    history = {
      ignoreDups = true;
      save = 10000;
      size = 10000;
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    dotDir = "${config.xdg.configHome}/zsh";

    initContent = lib.mkMerge [
      # Instant prompt — must be at the very top, before any console output
      (lib.mkOrder 100 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      # Terminal shell integrations — only load for the active terminal
      (lib.mkOrder 150 ''
        case "''${TERM_PROGRAM-}" in
          ghostty)
            if [[ -n "''${GHOSTTY_RESOURCES_DIR-}" ]]; then
              source "''${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
            fi
            ;;
          kitty)
            source "${pkgs.kitty}/lib/kitty/shell-integration/zsh/kitty.zsh"
            ;;
          WezTerm)
            source "${pkgs.wezterm}/etc/profile.d/wezterm.sh"
            ;;
        esac
      '')
      # Main init
      (lib.mkOrder 500 ''
        bindkey "\eh" backward-word
        bindkey "\ej" down-line-or-history
        bindkey "\ek" up-line-or-history
        bindkey "\el" forward-word
        if [ -f $HOME/.zshrc-personal ]; then
          source $HOME/.zshrc-personal
        fi

        # Double-ESC to prepend/remove sudo
        function _sudo_command_line() {
          [[ -z $BUFFER ]] && zle up-history
          if [[ $BUFFER == sudo\ * ]]; then
            LBUFFER="''${LBUFFER#sudo }"
          else
            LBUFFER="sudo $LBUFFER"
          fi
        }
        zle -N _sudo_command_line
        bindkey '\e\e' _sudo_command_line
      '')
      # p10k config — source user's config if it exists, otherwise prompt wizard
      (lib.mkOrder 1000 ''
        [[ -f "${config.programs.zsh.dotDir}/.p10k.zsh" ]] && source "${config.programs.zsh.dotDir}/.p10k.zsh"
      '')
    ];

    shellAliases =
      {
        nix-fmt-all = "nix fmt ./";
        sv = "sudo nvim";
        v = "nvim";
        c = "clear";
        unfuck = "reset && stty sane"; # fix garbled terminal after broken SSH
        cat = "bat";
        man = "batman";
        diff = "difftastic";

        # Url Encode/Decode
        urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
        urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";

        # Nix with pretty output (piped through nom for tree view)
        nb = "nix build |& nom";
        nd = "nix develop |& nom";
        ns = "nix shell |& nom";
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        fr = "nh os switch";
        fu = "nh os switch --update";
        ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        dr = "sudo darwin-rebuild switch --flake ~/nixos-config#gdel-macbook |& nom";
        drp = "git -C ~/nixos-config pull && sudo darwin-rebuild switch --flake ~/nixos-config#gdel-macbook |& nom";
        sage-remote = "ssh -t gustavo-Desktop sage";
      };
  };
}
