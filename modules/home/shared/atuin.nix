{lib, ...}: {
  programs.atuin = {
    enable = true;
    enableZshIntegration = false; # don't override Ctrl+R (fzf keeps it)
    settings = {
      sync_address = "https://atuin.gxdelerue.dedyn.io";
      auto_sync = true;
      sync_frequency = "5m";
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
    };
  };

  # Ctrl+H: invoke atuin search
  programs.zsh.initContent = lib.mkOrder 600 ''
    function _atuin_search() {
      local output
      output=$(atuin search --interactive 2>&1)
      if [[ -n "$output" ]]; then
        BUFFER="$output"
        CURSOR=$#BUFFER
      fi
      zle reset-prompt
    }
    zle -N _atuin_search
    bindkey '^H' _atuin_search
  '';
}
