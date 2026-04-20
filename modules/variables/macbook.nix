# MacBook (gdel-MacBook) host-specific variables.
# Merged on top of shared.nix via //.
rec {
  username = "gdel";
  host = "${username}-MacBook";
  homePrefix = "/Users";

  # Per-host font sizes
  termFontSize = 14;
  uiFontSize = 14;
  stylixFontSizes = {
    terminal = 16;
    applications = 14;
    desktop = 12;
    popups = 14;
  };
}
