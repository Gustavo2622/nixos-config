# Multi-Host Refactoring Plan

Target: support both NixOS (linux desktop) and nix-darwin (macOS) with maximum code sharing.

## Target Structure

```
modules/
  variables/
    shared.nix          # [shared] vars: git, username, fonts, browser, terminal
    desktop.nix         # [linux-only] + [per-host]: displayManager, animChoice, barChoice, stylixImage
    macbook.nix         # [per-host] darwin overrides (font sizes, host name, etc.)
    default.nix         # { host }: lib.recursiveUpdate (import ./shared.nix) (import ./${host}.nix)
  nvim.nix              # NVF config (platform-agnostic, consumed by flake directly)
  home/
    shared/             # cross-platform home-manager modules
      default.nix       # aggregator
      cli/              # git, fzf, bat, btop, direnv, gh, lazygit, difftastic, zoxide, tealdeer
      editors/          # vscode, helix, nano
      terminals/        # ghostty, kitty, alacritty, wezterm
      zsh/              # zsh + oh-my-zsh + p10k + starship
      stylix/
        theme.nix       # base16 scheme, fonts, font sizes (wallpaper from variables per-host)
      browsers.nix, zen-browser.nix, obsidian.nix, productivity.nix,
      python.nix (sans weather wrapper), newsboat.nix, amfora.nix,
      bitwarden.nix, emoji.nix, fonts.nix, bash.nix, bashrc-personal.nix, eza.nix
    linux/              # linux-only home-manager modules
      default.nix       # imports ../shared/ + all linux-only modules below
      hyprland/, waybar/, rofi/, wlogout/, yazi/, scripts/
      stylix.nix        # disable auto-styling for hyprland, waybar, rofi, ghostty
      gtk.nix, qt.nix, xdg.nix, monitors.nix, desktop-monitor-cfg.nix,
      swaync.nix, swappy.nix, noctalia.nix, nwg-dock-hyprland/,
      cava.nix (ALSA dep), anki.nix, multimedia.nix, obs-studio.nix,
      musescore.nix, latex.nix, virtmanager.nix,
      user.nix (homeDirectory = /home/...)
      weather-wrapper.nix  # extracted from python.nix
    darwin/             # darwin-only home-manager modules
      default.nix       # imports ../shared/ + darwin-specific
      user.nix          # homeDirectory = /Users/...
  nixos/                # NixOS system modules (unchanged internally)
    stylix.nix          # imports shared theme, applies via NixOS module
  darwin/               # nix-darwin system modules (from existing darwin config)
overlays/
  shared/               # platform-agnostic overlays
  linux/                # anki.nix, bleeding-edge.nix
  darwin/               # (from existing darwin config)
  default.nix           # { inputs, platform }: shared ++ platform-specific
```

## Flake Output Changes

```nix
# New darwin output
darwinConfigurations.gustavo-MacBook = nix-darwin.lib.darwinSystem {
  modules = [ ./modules/darwin ];
  # home-manager uses modules/home/darwin/default.nix (which imports shared/)
};

# Overlay composition becomes platform-aware
pkgs = system: let
  platform = if builtins.match ".*-darwin" system != null then "darwin" else "linux";
in import nixpkgs {
  inherit system;
  overlays = import ./overlays { inherit inputs; inherit platform; };
};
```

## Migration Phases

Each phase = one commit with a passing `nh os switch -q /etc/nixos`.

### Phase 1: Overlays (trivial)
- Create `overlays/{shared,linux,darwin}/`
- Move `anki.nix` and `bleeding-edge.nix` to `overlays/linux/`
- Update `overlays/default.nix` to take `{ inputs, platform }` and compose
- Update `flake.nix` to pass platform

### Phase 2: Variables split
- Create `variables/shared.nix` with [shared] vars
- Create `variables/desktop.nix` with [linux-only] + [per-host] vars
- Create `variables/default.nix` merger
- Keep `variables.nix` as backward-compat wrapper: `import ./variables { host = "desktop"; }`
- Update consumers incrementally (30+ files)

### Phase 3: Home-manager split — linux-only first
- Create `modules/home/linux/`, move obvious linux-only modules:
  hyprland/, waybar/, rofi/, wlogout/, nwg-dock-hyprland/, yazi/, scripts/,
  gtk.nix, qt.nix, xdg.nix, monitors.nix, desktop-monitor-cfg.nix,
  swaync.nix, swappy.nix, noctalia.nix, cava.nix (from cli/),
  anki.nix, obs-studio.nix, latex.nix, virtmanager.nix
- Extract weather wrapper from python.nix into linux/weather-wrapper.nix
- Create linux/user.nix with linux homeDirectory

### Phase 4: Home-manager split — shared
- Create `modules/home/shared/`, move remaining:
  cli/ (minus cava), editors/, terminals/, zsh/,
  browsers.nix, zen-browser.nix, obsidian.nix, productivity.nix,
  python.nix, newsboat.nix, amfora.nix, bitwarden.nix, emoji.nix,
  fonts.nix, bash.nix, bashrc-personal.nix, eza.nix, starship.nix,
  multimedia.nix (verify mpv works on darwin), musescore.nix (verify)
- Test each module for hidden linux dependencies

### Phase 5: Stylix 3-layer
- Extract shared theme to `modules/home/shared/stylix/theme.nix`
- NixOS stylix.nix imports shared theme
- Linux home stylix.nix imports shared theme + disables linux-only targets
- Darwin home stylix.nix imports shared theme + disables darwin-only targets (if any)

### Phase 6: Darwin merge
- Add nix-darwin input to flake.nix
- Import existing darwin config into `modules/darwin/`
- Create `modules/home/darwin/default.nix`
- Create `variables/macbook.nix`
- Wire up `darwinConfigurations` in flake.nix

## Pre-refactor Fixes (DONE)
- [x] Remove rogue `imports = [./hyprland]` from browsers.nix
- [x] Delete `hyprland.bck/` backup directory
- [x] Add DEPRECATED warning to `overlays/bleeding-edge.nix`
- [x] Annotate `variables.nix` with scope tags

## Known Issues to Address During Refactor
- `modules/home/default.nix` uses `rec {}` — drop when splitting
- `python.nix` weather wrapper must be extracted to linux-only
- `user.nix` homeDirectory must be parameterized
- `xdg.nix` is linux-only (Hyprland portal config)
- `cava.nix` is linux-only (ALSA/PulseAudio)
- Some modules take unused function args — clean up during move
- `forAllSystems` currently applies linux overlays to darwin — overlay split fixes this
