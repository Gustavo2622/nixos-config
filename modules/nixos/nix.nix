# Nix daemon: latest nix, flakes + nix-command, unfree packages, NIXOS_OZONE_WL=1
# for Wayland Electron, nix-ld for running unpatched binaries.
{
  lib,
  pkgs,
  ...
} @ args: {
  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  nixpkgs.config.allowUnfree = true;
  environment.variables.NIXPKGS_ALLOW_UNFREE = 1;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.variables.NIXOS_OZONE_WL = "1"; # Enable Native Wayland for electron
  systemd.services.nix-daemon.environment.TMPDIR = "/var/tmp";
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
    ];
  };

  system.stateVersion = "25.11"; # Did you read the comment?
}
