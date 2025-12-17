{pkgs, ...} : {
  home.packages = with pkgs; [zsh];

  home.file."./.zshrc-personal".text = ''
    #!/usr/bin/env zsh
    # EDITOR/VISUAL are set system-wide via modules/nixos/editor.nix
  '';
}
