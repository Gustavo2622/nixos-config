{
  pkgs,
  vars,
  ...
}: {
  nix = {
    settings = {
      trusted-users = ["@admin" vars.username];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
      experimental-features = "nix-command flakes";
    };

    gc = {
      automatic = true;
      interval = {
        Weekday = 0; # Sunday
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    package = pkgs.nix;
  };

  nixpkgs.config.allowUnfree = true;
}
