# LaTeX environment: texliveFull, Inkscape with figure workflow script, and systemd
# watcher that auto-exports SVG figures to PDF+PDF_TEX on every Inkscape save.
#
# inkscape-figures is not in nixpkgs; this module provides a shell implementation
# of Castel's inkscape-figures CLI (create / edit / watch subcommands) using
# inotifywait to detect saves and `inkscape --export-latex` for PDF conversion.
{
  pkgs,
  ...
}: let
  inkscape-figures = pkgs.writeShellScriptBin "inkscape-figures" ''
    set -euo pipefail
    cmd="''${1:-}"
    case "$cmd" in
      create)
        name="''${2:?Usage: inkscape-figures create <name> <dir>}"
        dir="''${3:?Usage: inkscape-figures create <name> <dir>}"
        mkdir -p "$dir"
        svg="$dir/$name.svg"
        if [[ ! -f "$svg" ]]; then
          cat > "$svg" <<'SVGEOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="200mm" height="150mm" viewBox="0 0 200 150">
  <title>FIGURE_NAME</title>
</svg>
SVGEOF
          sed -i "s/FIGURE_NAME/$name/" "$svg"
        fi
        ${pkgs.inkscape}/bin/inkscape "$svg" &
        ;;
      edit)
        dir="''${2:?Usage: inkscape-figures edit <dir>}"
        figs=$(ls "$dir"/*.svg 2>/dev/null | xargs -I{} basename {} .svg || true)
        if [[ -z "$figs" ]]; then
          echo "No figures found in $dir" >&2; exit 1
        fi
        chosen=$(printf '%s\n' $figs \
          | ${pkgs.rofi}/bin/rofi -dmenu -p "Edit figure:" -i)
        [[ -n "$chosen" ]] && ${pkgs.inkscape}/bin/inkscape "$dir/$chosen.svg" &
        ;;
      watch)
        echo "inkscape-figures: watching ~/Documents for SVG changes..."
        ${pkgs.inotify-tools}/bin/inotifywait \
          -m -e close_write --format "%w%f" \
          -r "''${FIGURES_DIR:-$HOME/Documents}" 2>/dev/null \
        | grep --line-buffered '\.svg$' \
        | while IFS= read -r svg_file; do
            base="''${svg_file%.svg}"
            echo "inkscape-figures: exporting $svg_file"
            ${pkgs.inkscape}/bin/inkscape \
              --export-type=pdf \
              --export-latex \
              --export-filename="$base.pdf" \
              "$svg_file" 2>/dev/null || true
          done
        ;;
      *)
        echo "Usage: inkscape-figures {create <name> <dir> | edit <dir> | watch}" >&2
        exit 1
        ;;
    esac
  '';
in {
  home.packages = with pkgs; [
    texliveFull
    inkscape
    inkscape-figures
  ];

  # Watches ~/Documents recursively for SVG saves and exports PDF+PDF_TEX.
  # Set FIGURES_DIR env var to restrict the watch scope if needed.
  systemd.user.services.inkscape-figures-watch = {
    Unit.Description = "Inkscape figures SVG watcher (auto-export PDF+PDF_TEX)";
    Service = {
      ExecStart = "${inkscape-figures}/bin/inkscape-figures watch";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = ["default.target"];
  };
}
