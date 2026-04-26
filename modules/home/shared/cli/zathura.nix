{
  pkgs,
  lib,
  ...
}: {
  programs.zathura = {
    enable = pkgs.stdenv.isLinux;
    options = {
      selection-clipboard = "clipboard";
      recolor = true;
      recolor-keephue = true;
    };
  };
}
