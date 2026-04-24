{
  lib,
  theme,
  ...
}: let
  accent = "#" + theme.base0D;
  foreground = "#" + theme.base05;
  muted = "#" + theme.base03;
in {
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    colors = lib.mkForce {
      "fg+" = accent;
      "bg+" = "-1";
      "fg" = foreground;
      "bg" = "-1";
      "prompt" = muted;
      "pointer" = accent;
    };
    defaultOptions = [
      "--margin=1"
      "--layout=reverse"
      "--border=none"
      "--info='hidden'"
      "--header=''"
      "--prompt='/ '"
      "-i"
      "--no-bold"
    ];
    # Ctrl+R: no file preview, exact match, preserve chronological order
    historyWidgetOptions = [
      "--preview-window=hidden"
      "--no-sort"
      "--exact"
    ];
  };

  # Alt+E: fzf file picker (fd, recursive from $PWD) → open in $EDITOR
  programs.zsh.initContent = ''
    function _fzf_edit_file() {
      local file
      file=$(fd --type f --hidden --follow --exclude .git 2>/dev/null \
        | fzf --preview='bat --style=numbers --color=always --line-range :500 {}' \
              --preview-window=right:60%:wrap)
      [[ -n "$file" ]] && ''${EDITOR:-nvim} "$file"
      zle reset-prompt
    }
    zle -N _fzf_edit_file
    bindkey '^[e' _fzf_edit_file
  '';
}
