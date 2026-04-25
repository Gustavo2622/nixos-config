# Multimedia packages: mpv for video playback, tauon and nuclear for music.
{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs;
    [
      mpv
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      tauon
      nuclear
    ];
}
