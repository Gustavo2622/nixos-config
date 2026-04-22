# Theme hotswap layer.
# Enumerates all themes, renders per-program color configs, and generates
# themes.json manifest for the nxc theme command.
{
  lib,
  pkgs,
  ...
}: let
  themesDir = ../../modules/theme/themes;

  # Discover all theme files
  themeFiles =
    builtins.filter (f: lib.hasSuffix ".nix" f)
    (builtins.attrNames (builtins.readDir themesDir));
  themeNames = map (f: lib.removeSuffix ".nix" f) themeFiles;
  themes = lib.genAttrs themeNames (name: import (themesDir + "/${name}.nix"));

  # Per-program theme templates: colors attrset → rendered config string
  # Each function takes { base00, base01, ..., base0F } and returns a string
  # in the program's native config format.
  templates = {
    hyprland = colors: ''
      # Theme colors (base16)
      $base00 = rgb(${colors.base00})
      $base01 = rgb(${colors.base01})
      $base02 = rgb(${colors.base02})
      $base03 = rgb(${colors.base03})
      $base04 = rgb(${colors.base04})
      $base05 = rgb(${colors.base05})
      $base06 = rgb(${colors.base06})
      $base07 = rgb(${colors.base07})
      $base08 = rgb(${colors.base08})
      $base09 = rgb(${colors.base09})
      $base0A = rgb(${colors.base0A})
      $base0B = rgb(${colors.base0B})
      $base0C = rgb(${colors.base0C})
      $base0D = rgb(${colors.base0D})
      $base0E = rgb(${colors.base0E})
      $base0F = rgb(${colors.base0F})

      general {
        col.active_border = rgb(${colors.base0D}) rgb(${colors.base0E}) 45deg
        col.inactive_border = rgb(${colors.base02})
      }
    '';

    ghostty = colors: ''
      background = ${colors.base00}
      foreground = ${colors.base05}
      cursor-color = ${colors.base05}
      selection-background = ${colors.base02}
      selection-foreground = ${colors.base05}
      palette = 0=#${colors.base00}
      palette = 1=#${colors.base08}
      palette = 2=#${colors.base0B}
      palette = 3=#${colors.base0A}
      palette = 4=#${colors.base0D}
      palette = 5=#${colors.base0E}
      palette = 6=#${colors.base0C}
      palette = 7=#${colors.base05}
      palette = 8=#${colors.base03}
      palette = 9=#${colors.base08}
      palette = 10=#${colors.base0B}
      palette = 11=#${colors.base0A}
      palette = 12=#${colors.base0D}
      palette = 13=#${colors.base0E}
      palette = 14=#${colors.base0C}
      palette = 15=#${colors.base07}
    '';

    waybar = colors: ''
      :root {
        --base00: #${colors.base00};
        --base01: #${colors.base01};
        --base02: #${colors.base02};
        --base03: #${colors.base03};
        --base04: #${colors.base04};
        --base05: #${colors.base05};
        --base06: #${colors.base06};
        --base07: #${colors.base07};
        --base08: #${colors.base08};
        --base09: #${colors.base09};
        --base0A: #${colors.base0A};
        --base0B: #${colors.base0B};
        --base0C: #${colors.base0C};
        --base0D: #${colors.base0D};
        --base0E: #${colors.base0E};
        --base0F: #${colors.base0F};
      }
    '';

    nvim = colors: ''
      -- Theme colors (base16) for runtime override
      vim.g.nxc_theme_colors = {
        base00 = "#${colors.base00}",
        base01 = "#${colors.base01}",
        base02 = "#${colors.base02}",
        base03 = "#${colors.base03}",
        base04 = "#${colors.base04}",
        base05 = "#${colors.base05}",
        base06 = "#${colors.base06}",
        base07 = "#${colors.base07}",
        base08 = "#${colors.base08}",
        base09 = "#${colors.base09}",
        base0A = "#${colors.base0A}",
        base0B = "#${colors.base0B}",
        base0C = "#${colors.base0C}",
        base0D = "#${colors.base0D}",
        base0E = "#${colors.base0E}",
        base0F = "#${colors.base0F}",
      }
    '';
  };

  # Build the manifest: { theme_name: { program: rendered_string } }
  manifest = lib.genAttrs themeNames (themeName: let
    colors = themes.${themeName};
  in
    lib.mapAttrs (prog: template: template colors)
    (lib.filterAttrs (prog: _: templates ? ${prog}) templates));

  manifestJson = builtins.toJSON manifest;
  manifestFile = pkgs.writeText "nxc-themes.json" manifestJson;
in {
  # Copy theme manifest to nxc state dir on activation
  home.activation.nxcThemes = lib.hm.dag.entryAfter ["nxcRegistry"] ''
    mkdir -p "$HOME/.local/state/nxc"
    cp -f "${manifestFile}" "$HOME/.local/state/nxc/themes.json"
  '';
}
