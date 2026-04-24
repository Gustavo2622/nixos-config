# Linux-only CLI utilities (hardware monitoring, X11 clipboard, system tracing)
{pkgs, ...}: {
  home.packages = with pkgs; [
    xclip # X11 clipboard
    xsel # X11 clipboard (alternative)
    ethtool # Network interface config
    iftop # Per-connection bandwidth monitor
    iotop # Per-process disk I/O monitor
    lm_sensors # CPU/GPU/board temperature and fan sensors
    pciutils # lspci — list PCI devices
    strace # System call tracer
    sysstat # sar, iostat, mpstat — system performance stats
    usbutils # lsusb — list USB devices
  ];
}
