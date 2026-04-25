{
  pkgs,
  lib,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  hasZen = inputs.zen-browser.packages ? ${system};
  zenPkg =
    if hasZen
    then (inputs.zen-browser.packages.${system}.zen-browser or inputs.zen-browser.packages.${system}.default)
    else null;
in {
  home.packages = lib.optional (zenPkg != null) zenPkg;
}
