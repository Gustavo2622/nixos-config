# Miscellaneous services: libinput, fstrim, gvfs, power-profiles-daemon, tumbler
# (thumbnails), gnome-keyring, seahorse, and smartd with autodetect.
_: {
  services = {
    libinput.enable = true;
    fstrim.enable = true;
    gvfs.enable = true;
    power-profiles-daemon.enable = true;
    tumbler.enable = true;
    gnome.gnome-keyring.enable = true;

    smartd = {
      enable = true;
      autodetect = true;
    };
  };

  programs.seahorse.enable = true;
}
