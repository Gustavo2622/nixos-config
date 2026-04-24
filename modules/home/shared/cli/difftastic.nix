_: {
  programs.difftastic = {
    enable = true;
    # git integration disabled — delta handles pager duties.
    # difftastic is configured as difftool in git.nix instead.
  };
}
