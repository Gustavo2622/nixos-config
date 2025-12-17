rec {
  # === Variable Scope ===
  # When splitting for multi-host (linux + darwin), use this guide:
  #   [shared]     — platform-agnostic, used on all hosts
  #   [linux-only] — depends on Hyprland, Wayland, or linux-specific services
  #   [per-host]   — likely to differ between machines (font sizes, wallpaper, etc.)

  # === Switchable Options ===
  # terminal      : "ghostty" | "kitty" | "alacritty" | "wezterm"  (sets default; all are installed)
  # displayManager: "tui" (greetd) | "ly" | "sddm"
  # animChoice    : "dynamic" | "def" | "end4" | "end4-slide" | "end-slide"
  #               | "hyde-optimized" | "mahaveer-1" | "mahaveer-2"
  #               | "ml4w-classic" | "ml4w-fast" | "ml4w-high" | "moving"
  # barChoice     : "noctalia" | "waybar"
  # fontName      : Primary monospace font for terminals and code editors (all are installed)
  #   "Maple Mono NF"                — current; Maple Mono with Nerd Font icons
  #   "JetBrainsMono Nerd Font Mono" — JetBrains Mono with Nerd Font icons
  #   "FiraCode Nerd Font Mono"      — Fira Code with ligatures and Nerd Font icons
  #   "Iosevka Nerd Font Mono"       — Iosevka condensed with Nerd Font icons
  #   "Iosevka Term Nerd Font Mono"  — Iosevka Term (standard width) with Nerd Font icons
  # uiFontName    : Monospace font for UI overlays and bars (rofi, swaync, wlogout, waybar)
  #   "JetBrainsMono Nerd Font Mono" — current
  #   "FiraCode Nerd Font Mono"      — Fira Code variant
  #   "Iosevka Nerd Font Mono"       — Iosevka variant
  # stylixMonoFont: Monospace font for the Stylix theming system (controls themed apps)
  #   "JetBrains Mono" — current; maps to nerd-fonts.jetbrains-mono
  #   "Fira Code"      — maps to nerd-fonts.fira-code
  #   "Iosevka"        — maps to nerd-fonts.iosevka
  #   "Maple Mono NF"  — maps to maple-mono.NF
  # fallbackFont  : Symbol font for codepoints the primary font lacks (arrows, math, box-drawing)
  #   "Symbola"            — 11882 codepoints; broadest coverage (recommended)
  #   "Noto Sans Symbols2" — 2639 codepoints; Google-maintained
  # termFontSize  : Font size for terminal emulators (ghostty, kitty, alacritty, wezterm)
  # uiFontSize    : Base font size for UI components with a single global size (rofi, waybar)
  # stylixFontSizes: Font sizes for Stylix-managed applications

  # [shared]
  gitUsername = "Gustavo Delerue";
  gitEmail = "gxdelerue@proton.me";
  username = "gustavo";

  # [per-host]
  host = "${username}-Desktop";

  # [shared]
  terminal = "ghostty";
  browser = "brave";

  # [linux-only]
  displayManager = "tui"; # One of ["tui" "ly" "sddm"]
  stylixImage = ../Wallpapers/PinkPurpleHaze.jpg;
  barChoice = "noctalia"; # One of ["noctalia" "waybar"]
  animChoice = "dynamic"; # One of the animChoice values listed above

  # [shared] — fonts are cross-platform
  fontName       = "Maple Mono NF";
  uiFontName     = "JetBrainsMono Nerd Font Mono";
  stylixMonoFont = "JetBrains Mono";
  fallbackFont   = "Symbola";

  # [per-host] — may differ by display
  termFontSize   = 14;
  uiFontSize     = 14;
  stylixFontSizes = {
    terminal     = 20;
    applications = 16;
    desktop      = 14;
    popups       = 16;
  };
}
