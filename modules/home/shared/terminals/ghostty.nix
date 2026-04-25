{
  pkgs,
  lib,
  config,
  vars,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;
  ghostHome = "${config.xdg.configHome}/ghostty";
  shaderFile = "${ghostHome}/shaders/shader.glsl";

  # Shared settings used by both programs.ghostty (linux) and xdg.configFile (darwin)
  sharedSettings = {
    config-file = [
      "?~/.local/state/mutable/ghostty/00-theme.conf"
      "?~/.local/state/mutable/ghostty/50-user.conf"
      "?~/.local/state/mutable/ghostty/90-debug.conf"
    ];
    custom-shader = shaderFile;
    custom-shader-animation = "always";
    term = "xterm-256color";
    confirm-close-surface = false;
    font-family = [vars.fontName vars.fallbackFont];
    font-size = vars.termFontSize;
    theme = "dark:catppuccin-mocha,light:catppuccin-mocha";
    adjust-cell-height = "10%";
    window-theme = "dark";
    window-height = "32";
    window-width = "110";
    background-opacity = "1.00";
    background-blur-radius = "60";
    selection-background = "#2d3f76";
    selection-foreground = "#c8d3f5";
    cursor-style = "bar";
    mouse-hide-while-typing = "true";
    wait-after-command = "false";
    shell-integration = "detect";
    window-save-state = "always";
    unfocused-split-opacity = "0.50";
    quick-terminal-position = "center";
    shell-integration-features = "cursor,sudo";
    bold-is-bright = "false";
    focus-follows-mouse = "true";
    resize-overlay = "never";
  };

  sharedKeybinds = [
    "ctrl+shift+c=copy_to_clipboard"
    "ctrl+shift+v=paste_from_clipboard"
    "ctrl+shift+plus=increase_font_size:1"
    "ctrl+shift+minus=decrease_font_size:1"
    "ctrl+shift+zero=reset_font_size"
    "alt+s>r=reload_config"
    "alt+s>x=close_surface"
    "alt+s>n=new_window"
    "alt+s>c=new_tab"
    "alt+s>shift+l=next_tab"
    "alt+s>shift+h=previous_tab"
    "alt+s>comma=move_tab:-1"
    "alt+s>period=move_tab:1"
    "alt+s>1=goto_tab:1"
    "alt+s>2=goto_tab:2"
    "alt+s>3=goto_tab:3"
    "alt+s>4=goto_tab:4"
    "alt+s>5=goto_tab:5"
    "alt+s>6=goto_tab:6"
    "alt+s>7=goto_tab:7"
    "alt+s>8=goto_tab:8"
    "alt+s>9=goto_tab:9"
    "alt+s>\\=new_split:right"
    "alt+s>-=new_split:down"
    "alt+s>j=goto_split:bottom"
    "alt+s>k=goto_split:top"
    "alt+s>h=goto_split:left"
    "alt+s>l=goto_split:right"
    "alt+s>z=toggle_split_zoom"
    "alt+s>e=equalize_splits"
  ];

  # Render settings to ghostty config format for darwin xdg.configFile
  renderValue = v:
    if builtins.isList v
    then builtins.concatStringsSep "\n" (map (x: renderValue x) v)
    else if builtins.isBool v
    then
      if v
      then "true"
      else "false"
    else toString v;

  renderSettings = settings:
    builtins.concatStringsSep "\n" (
      lib.mapAttrsToList (
        k: v:
          if builtins.isList v
          then builtins.concatStringsSep "\n" (map (item: "${k} = ${renderValue item}") v)
          else "${k} = ${renderValue v}"
      )
      settings
    );

  darwinConfig =
    renderSettings sharedSettings
    + "\nmacos-option-as-alt = true\n"
    + builtins.concatStringsSep "\n" (map (kb: "keybind = ${kb}") sharedKeybinds)
    + "\n";
in {
  # Shared: theme files and shader
  home.file = {
    "${ghostHome}/themes/catppuccin-mocha".source = ./ghostty-themes/catppuccin-mocha;

    "${ghostHome}/ghostty-bg.conf".text = ''
      background-image=${config.home.homeDirectory}/Pictures/current_image_ghostty
      background-image-opacity=0.9
      background-image-position=center
      background-image-fit=cover
      background-image-repeat=false
    '';

    "${shaderFile}".source = pkgs.fetchurl {
      url = "https://github.com/sahaj-b/ghostty-cursor-shaders/raw/88c27a55b2e970eec19c21ef858a1a5bea489a1d/cursor_warp.glsl";
      sha256 = "sha256-9ZlLcNu5cH0Ibc7qrS+lfrY4neesQm/5FdTCNa85G+s=";
    };
  };

  # Linux: use programs.ghostty (installs package + shell integration + bat syntax)
  programs.ghostty = lib.mkIf isLinux {
    enable = true;
    package = pkgs.ghostty;
    enableFishIntegration = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    clearDefaultKeybinds = true;
    settings =
      sharedSettings
      // {
        gtk-single-instance = "true";
        keybind = sharedKeybinds;
      };
  };

  # Darwin: write config directly (ghostty installed via homebrew cask)
  xdg.configFile."ghostty/config" = lib.mkIf (!isLinux) {
    text = darwinConfig;
  };

  # Linux-only: desktop entry and background wrapper
  home.file."${config.xdg.dataHome}/applications/ghostty-bg.desktop" = lib.mkIf isLinux {
    text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Ghostty with Background
      Comment=Terminal Emulator with random background image
      Exec=ghostty-bg --foreground
      Icon=utilities-terminal
      Terminal=false
      Categories=System;TerminalEmulator;Utility
      Keywords=terminal;shell;prompt;
    '';
  };

  home.packages = lib.optionals isLinux [
    (pkgs.writeShellScriptBin "ghostty-bg" ''
            #!/usr/bin/env bash
            set -euo pipefail

            # Defaults
            SOURCE_DIR="$HOME/Pictures/Wallpapers"
            LINK_PATH="$HOME/Pictures/current_image_ghostty"
            LAUNCH=1
            FOREGROUND=0

            # Parse options (stop at first positional or --)
            while [[ $# -gt 0 ]]; do
              case "$1" in
                -s|--source)
                  [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
                  SOURCE_DIR="$2"; shift 2;;
                -l|--link)
                  [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
                  LINK_PATH="$2"; shift 2;;
                --no-launch)
                  LAUNCH=0; shift;;
                --foreground)
                  FOREGROUND=1; shift;;
                -h|--help)
                  cat <<'EOF'
      Usage: ghostty-bg [options] [--] [ghostty_args...]

      Defaults: Launches ghostty in the background with background-image linked at ~/Pictures/current_image_ghostty

      Options:
        -s, --source DIR   Source directory of images (default: ~/Pictures/Wallpapers)
        -l, --link PATH    Symlink path (default: ~/Pictures/current_image_ghostty)
            --no-launch    Only update symlink; do not launch ghostty
            --foreground   Run ghostty in the foreground (default is background)
        -h, --help         Show this help
      EOF
                  exit 0;;
                --)
                  shift; break;;
                -*)
                  echo "Unknown option: $1" >&2; exit 2;;
                *)
                  break;;
              esac
            done

            # Validate and choose random image
            if [[ ! -d "$SOURCE_DIR" ]]; then
              echo "Source directory not found: $SOURCE_DIR" >&2
              exit 1
            fi

            CHOSEN="$(${pkgs.findutils}/bin/find -L "$SOURCE_DIR" -type f \
              \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
              -print0 | ${pkgs.coreutils}/bin/shuf -z -n 1 | ${pkgs.coreutils}/bin/tr -d '\0')"
            if [[ -z "$CHOSEN" ]]; then
              echo "No images found in: $SOURCE_DIR" >&2
              exit 1
            fi

            # Update symlink
            mkdir -p "$(dirname "$LINK_PATH")"
            ln -sfn "$CHOSEN" "$LINK_PATH"

            # Launch ghostty with CLI overrides for background image
            if (( LAUNCH )); then
              if (( FOREGROUND )); then
                exec ghostty \
                  --background-image="$LINK_PATH" \
                  --background-image-opacity=0.9 \
                  --background-image-position=center \
                  --background-image-fit=cover \
                  --background-image-repeat=false \
                  "$@"
              else
                setsid -f ghostty \
                  --background-image="$LINK_PATH" \
                  --background-image-opacity=0.9 \
                  --background-image-position=center \
                  --background-image-fit=cover \
                  --background-image-repeat=false \
                  "$@" >/dev/null 2>&1 < /dev/null &
              fi
            fi
    '')
  ];
}
