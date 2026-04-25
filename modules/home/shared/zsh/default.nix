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

    dotDir = "${config.xdg.configHome}/zsh";

    initContent = ''
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
    '';

    shellAliases =
      {
        nix-fmt-all = "nix fmt ./";
        sv = "sudo nvim";
        v = "nvim";
        c = "clear";
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
        dr = "sudo darwin-rebuild switch --flake ~/nixos-config |& nom";
      };
  };
}
