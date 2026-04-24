# Personal bash environment: sets EDITOR/VISUAL to nvim and adds cl→clear alias.
{pkgs, ...}: {
  home.packages = with pkgs; [bash];

  home.file."./.bashrc-personal".text = ''
    # EDITOR/VISUAL are set system-wide via modules/nixos/editor.nix
    alias cl="clear"
  '';
}
