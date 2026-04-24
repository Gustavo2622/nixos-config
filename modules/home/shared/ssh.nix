{vars, ...}: let
  identityFile = "${vars.homePrefix}/${vars.username}/.ssh/id_ed25519";
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        extraOptions = {
          "AddKeysToAgent" = "yes";
          "IdentitiesOnly" = "yes";
        };
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = identityFile;
      };

      "gustavo-Desktop" = {
        hostname = "gustavo-Desktop";
        user = vars.username;
        identityFile = identityFile;
      };

      "forge" = {
        hostname = "gustavo-Desktop";
        port = 3022;
        user = "forgejo";
        identityFile = identityFile;
      };
    };
  };
}
