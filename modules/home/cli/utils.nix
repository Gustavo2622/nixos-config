{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    moreutils # Vipe
    fd        # Fast find; used by fzf Alt+E widget and Ctrl+T

    # Archives
    p7zip
    unzip
    xz
    zip

    # CLI utils
    alejandra    # Nix code formatter (also available via nix fmt)
    clipboard-jh # Clipboard manager with history, piping, and multi-clipboard
    comma        # Run any nixpkgs program without installing: , cowsay hello
    nix-index    # Locate which package provides a binary: nix-locate bin/pandoc
    glow         # Terminal Markdown renderer
    jq           # JSON processor
    nushell      # Structured data shell
    xclip        # X11 clipboard
    xsel         # X11 clipboard (alternative)
    yq-go        # YAML/XML/TOML processor (like jq for YAML)

    # Core utils
    file    # File type detection
    gnupg   # GPG encryption
    gnused  # Stream editor
    gnutar  # Archive tool
    tree    # Directory tree viewer

    # Networking
    aria2    # Multi-protocol download accelerator
    dnsutils # dig + nslookup
    mtr      # Network diagnostics (traceroute + ping)
    nmap     # Network scanner
    socat    # Multipurpose relay (netcat++)

    # Monitoring
    ethtool    # Network interface config
    iftop      # Per-connection bandwidth monitor
    iotop      # Per-process disk I/O monitor
    lm_sensors # CPU/GPU/board temperature and fan sensors
    lsof       # List open files and sockets
    pciutils   # lspci — list PCI devices
    strace     # System call tracer
    sysstat    # sar, iostat, mpstat — system performance stats
    usbutils   # lsusb — list USB devices
  ];
}
