{inputs}: let
  linuxOverlays = [
    (import ./linux/anki.nix)
  ];

  darwinOverlays = [
    (import ./darwin/erlang-ls-compat.nix)
    (import ./darwin/direnv-skip-check.nix)
  ];

  platformOverlay = final: prev: let
    composed =
      if prev.stdenv.hostPlatform.isLinux
      then nixpkgs.lib.composeManyExtensions linuxOverlays final prev
      else if prev.stdenv.hostPlatform.isDarwin
      then nixpkgs.lib.composeManyExtensions darwinOverlays final prev
      else {};
  in
    composed;

  inherit (inputs) nixpkgs;
in {
  default = platformOverlay;
}
