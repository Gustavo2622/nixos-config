# Screenshot utility: uses slurp for region selection, grim for capture, and swappy
# to annotate and save the result.
{pkgs}:
pkgs.writeShellScriptBin "screenshootin" ''
  grim -g "$(slurp)" - | swappy -f -
''
