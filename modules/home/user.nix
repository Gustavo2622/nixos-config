{
  pkgs,
  vars,
  ...
}: let
  inherit (vars) username;
in {
  home = rec {
    inherit username;
    homeDirectory = "/home/${username}";
  };
}
