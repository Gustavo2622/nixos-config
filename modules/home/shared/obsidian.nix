{pkgs, ...}: {
  programs.obsidian = {
    enable = pkgs.stdenv.isLinux; # Linux-only HM module; darwin uses App Store
  };
}
