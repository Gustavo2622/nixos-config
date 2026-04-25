# Darwin system module aggregator
{vars, ...}: {
  imports = [
    ./dock
    ./homebrew.nix
    ./nix.nix
    ./system-defaults.nix
    ./user.nix
  ];
}
