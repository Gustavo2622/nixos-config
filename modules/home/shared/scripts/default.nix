# Cross-platform scripts
{
  pkgs,
  lib,
  ...
}: {
  home.packages =
    [
      (import ./clip.nix {inherit pkgs;})
      (import ./note.nix {inherit pkgs;})
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      (import ./hm-find.nix {inherit pkgs;}) # uses journalctl
      (import ./web-search.nix {inherit pkgs;}) # uses rofi + xdg-open
    ];
}
