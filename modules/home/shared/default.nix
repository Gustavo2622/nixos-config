# Cross-platform home-manager modules (shared between NixOS and darwin)
_: {
  imports = [
    ./amfora.nix
    ./atuin.nix
    ./bash.nix
    ./bashrc-personal.nix
    ./cli
    ./editors
    ./emoji.nix
    ./eza.nix
    ./fonts.nix
    ./multimedia.nix
    # ./newsboat.nix  # removed — RSS client choice deferred to Phase 10
    ./obsidian.nix
    ./python.nix
    ./scripts
    ./ssh.nix
    ./starship.nix
    ./tealdeer.nix
    ./terminals
    ./zen-browser.nix
    ./zoxide.nix
    ./zsh
  ];
}
