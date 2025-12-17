# Stylix system theming: wallpaper, cursor, and fonts from variables.nix.
# stylixMonoFont selects the system monospace font; stylixFontSizes sets per-context sizes.
{pkgs, ...}:
let
  inherit (import ../variables.nix) stylixImage stylixMonoFont stylixFontSizes;
  stylixMonoFontPkgs = {
    "JetBrains Mono" = pkgs.nerd-fonts.jetbrains-mono;
    "Fira Code"      = pkgs.nerd-fonts.fira-code;
    "Iosevka"        = pkgs.nerd-fonts.iosevka;
    "Maple Mono NF"  = pkgs.maple-mono.NF;
  };
in {
  stylix = {
    enable = true;
    image = stylixImage;

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    fonts = {
      monospace = {
        package = stylixMonoFontPkgs.${stylixMonoFont};
        name = stylixMonoFont;
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      sizes = {
        inherit (stylixFontSizes) terminal applications desktop popups;
      };
    };
    polarity = "dark";
    opacity.terminal = 1.0;
  };
}
