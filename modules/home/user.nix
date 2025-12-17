{pkgs, ...}: 
let 
  inherit (import ../variables.nix) username;
in
{
  home = rec {
    inherit username;
    homeDirectory = "/home/${username}";
  };
}
