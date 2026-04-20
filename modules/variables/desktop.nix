# Desktop (gustavo-Desktop) host-specific variables.
# Merged on top of shared.nix via //.
rec {
  username = "gustavo";
  host = "${username}-Desktop";
  homePrefix = "/home";

  # Linux-only switchable options
  displayManager = "tui";
  stylixImage = ../../Wallpapers/PinkPurpleHaze.jpg;
  barChoice = "noctalia";
  animChoice = "dynamic";

  # Per-host font sizes
  termFontSize = 14;
  uiFontSize = 14;
  stylixFontSizes = {
    terminal = 20;
    applications = 16;
    desktop = 14;
    popups = 16;
  };
}
