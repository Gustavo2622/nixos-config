# Cross-platform CLI utilities
{pkgs, ...}: {
  home.packages = with pkgs; [
    moreutils # Vipe
    fd # Fast find; used by fzf Alt+E widget and Ctrl+T

    # Archives
    p7zip
    unzip
    xz
    zip

    # CLI utils
    alejandra # Nix code formatter (also available via nix fmt)
    clipboard-jh # Clipboard manager with history, piping, and multi-clipboard
    comma # Run any nixpkgs program without installing: , cowsay hello
    nix-index # Locate which package provides a binary: nix-locate bin/pandoc
    glow # Terminal Markdown renderer
    jq # JSON processor
    nushell # Structured data shell
    yq-go # YAML/XML/TOML processor (like jq for YAML)

    # Core utils
    file # File type detection
    gnupg # GPG encryption
    gnused # Stream editor
    gnutar # Archive tool
    tree # Directory tree viewer

    # Encryption / secrets
    age # Modern encryption tool (used by sops-nix)
    age-plugin-yubikey # YubiKey support for age

    # Networking
    aria2 # Multi-protocol download accelerator
    dnsutils # dig + nslookup
    mtr # Network diagnostics (traceroute + ping)
    nmap # Network scanner
    socat # Multipurpose relay (netcat++)

    # Monitoring (cross-platform)
    lsof # List open files and sockets
  ];
}
