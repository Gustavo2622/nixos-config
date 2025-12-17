_: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in {
  programs.git = {
    enable = true; # live and die by the protocol
    signing.format = null;
    settings = {
      user = {
        name = "${gitUsername}";
        email = "${gitEmail}";
      };

      # FOSS-friendly?
      push.default = "simple";
      credential.helper = "cache --timeout=7200";
      init.defaultBranch = "main";
      log.decorate = "full";
      log.date = "iso";

      merge.conflictStyle = "zdiff3";

      # Cool git aliases
      alias = {
        br = "branch --sort=-committerdate";
        co = "checkout";
        df = "diff";
        com = "commit -a";
        gs = "stash";
        gp = "pull";
        lg = "log --graph --pretty=format'%Cred%h%Creset - %C(yellow)%d%Creset %s %C(green)(%cr)%C(bold blue) <%an>%Creset' --abbrev-commit";
        st = "status";
      };
    };
  };
}
