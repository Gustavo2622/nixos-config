{
  # Enable CUPS to print documents.
  services = {
    printing = {
      enable = true;
      drivers = [];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    ipp-usb.enable = true;
  };
}
