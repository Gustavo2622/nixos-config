# Homebrew wiring — manages casks, brews, and taps declaratively via nix-homebrew
_: {
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "none"; # TODO: re-enable "zap" after clean build
      upgrade = true;
    };

    taps = [
      "nikitabobko/tap" # aerospace
    ];

    casks = [
      # Terminal
      "ghostty"

      # Communication
      "slack"
      # "zoom"  # cask definition broken upstream — install manually: brew install --cask zoom

      # Browsers
      "brave-browser"
      "google-chrome"
      "firefox"

      # Productivity
      "raycast"

      # Security
      "bitwarden"

      # Sync / Networking
      "syncthing-app"
      "tailscale-app"

      # Media
      "vlc"

      # AI
      "ollama-app"

      # Dev
      "vscodium"

      # Window management
      "nikitabobko/tap/aerospace"
    ];

    brews = [
      "colima" # Docker runtime (formula, not cask)
      "docker"
      "docker-compose"
      "qemu"
    ];
  };
}
