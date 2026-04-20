# Tailscale mesh VPN for cross-machine connectivity.
_: {
  services.tailscale.enable = true;
  networking.firewall.allowedUDPPorts = [41641];
}
