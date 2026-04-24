{...}: {
  services.atuin = {
    enable = true;
    openRegistration = true; # personal server, only accessible via Tailscale
    host = "0.0.0.0";
    port = 8888;
  };

  networking.firewall.allowedTCPPorts = [8888];
}
