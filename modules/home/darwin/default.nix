# Darwin-only home-manager modules — imports shared + darwin-specific
_: {
  imports = [
    ../shared
    ./aerospace.nix
    ./packages.nix
    ./secrets.nix
    ./user.nix
  ];
}
