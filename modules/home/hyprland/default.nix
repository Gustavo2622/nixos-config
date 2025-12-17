_: let
  vars = import ../../variables.nix;
  animFiles = {
    "dynamic"        = ./animations-dynamic.nix;
    "def"            = ./animations-def.nix;
    "end4"           = ./animations-end4.nix;
    "end4-slide"     = ./animations-end4-slide.nix;
    "end-slide"      = ./animations-end-slide.nix;
    "hyde-optimized" = ./animations-hyde-optimized.nix;
    "mahaveer-1"     = ./animations-mahaveer-me-1.nix;
    "mahaveer-2"     = ./animations-mahaveer-me-2.nix;
    "ml4w-classic"   = ./animations-ml4w-classic.nix;
    "ml4w-fast"      = ./animations-ml4w-fast.nix;
    "ml4w-high"      = ./animations-ml4w-high.nix;
    "moving"         = ./animations-moving.nix;
  };
in {
  imports = [
    ./hyprland.nix
    animFiles.${vars.animChoice}
    ./binds.nix
    ./env.nix
    ./exec-once.nix
    ./hypridle.nix
    ./hyprlock.nix
    ./pyprland.nix
    ./windowrules.nix
  ];
}
