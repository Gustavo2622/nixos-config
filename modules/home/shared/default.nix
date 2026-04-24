# Cross-platform home-manager modules (shared between NixOS and darwin)
_: {
  imports = [
    ./amfora.nix
    ./bash.nix
    ./bashrc-personal.nix
    ./cli
    ./editors
    ./emoji.nix
    ./eza.nix
    ./fonts.nix
    ./multimedia.nix
    ./newsboat.nix
    ./obsidian.nix
    ./python.nix
    ./scripts
    ./starship.nix
    ./tealdeer.nix
    ./terminals
    ./zen-browser.nix
    ./zoxide.nix
    ./zsh
  ];
}
