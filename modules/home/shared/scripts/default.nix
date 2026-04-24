# Cross-platform scripts
{pkgs, ...}: {
  home.packages = [
    (import ./clip.nix {inherit pkgs;})
    (import ./note.nix {inherit pkgs;})
    (import ./hm-find.nix {inherit pkgs;})
    (import ./web-search.nix {inherit pkgs;})
  ];
}
