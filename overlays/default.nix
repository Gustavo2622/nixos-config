{inputs}: let
  inherit (import ./anki.nix) anki;
  all = [anki];
in {
  default = inputs.nixpkgs.lib.composeManyExtensions all;
}
