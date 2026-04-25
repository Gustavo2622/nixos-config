# Darwin-only home-manager modules — imports shared + darwin-specific
_: {
  imports = [
    ../shared
    ./packages.nix
    ./secrets.nix
    ./user.nix
  ];
}
