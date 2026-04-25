# Homebrew wiring — manages casks, brews, and taps declaratively via nix-homebrew
_: {
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap"; # Remove unmanaged casks/brews
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
      "zoom"

      # Browsers
      "google-chrome"
      "firefox"

      # Productivity
      "raycast"

      # Security
      "bitwarden"

      # Sync / Networking
      "syncthing"
      "tailscale"

      # Media
      "vlc"

      # AI
      "ollama"

      # Dev
      "colima" # Docker runtime (lightweight, no Docker Desktop)

      # Window management
      "nikitabobko/tap/aerospace"
    ];

    brews = [
      "docker"
      "docker-compose"
      "qemu"
    ];
  };
}
