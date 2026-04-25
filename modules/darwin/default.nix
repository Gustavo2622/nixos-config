# Darwin system module aggregator
{vars, ...}: {
  imports = [
    ./dock
    ./homebrew.nix
    ./nix.nix
    ./system-defaults.nix
    ./user.nix
  ];

  system.primaryUser = vars.username;
  system.stateVersion = 4;
}
