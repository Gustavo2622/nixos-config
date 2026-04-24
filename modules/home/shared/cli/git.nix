{vars, ...}: let
  inherit (vars) gitUsername gitEmail homePrefix username;
in {
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
    };
  };

  programs.git = {
    enable = true; # live and die by the protocol

    lfs.enable = true;

    signing = {
      format = "ssh";
      key = "${homePrefix}/${username}/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    settings = {
      user = {
        name = "${gitUsername}";
        email = "${gitEmail}";
      };

      push.default = "simple";
      pull.rebase = true;
      rebase.autoStash = true;
      credential.helper = "cache --timeout=7200";
      init.defaultBranch = "main";
      log.decorate = "full";
      log.date = "iso";

      merge.conflictStyle = "zdiff3";

      # difftastic as difftool (delta handles pager duties)
      diff.tool = "difftastic";
      difftool.prompt = false;
      difftool.difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';

      alias = {
        br = "branch --sort=-committerdate";
        co = "checkout";
        df = "diff";
        dt = "difftool"; # structural diff via difftastic
        com = "commit -a";
        gs = "stash";
        gp = "pull";
        lg = "log --graph --pretty=format'%Cred%h%Creset - %C(yellow)%d%Creset %s %C(green)(%cr)%C(bold blue) <%an>%Creset' --abbrev-commit";
        st = "status";
      };
    };
  };
}
