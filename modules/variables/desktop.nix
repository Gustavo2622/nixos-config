# Desktop (gustavo-Desktop) host-specific variables.
# Merged on top of shared.nix via //.
rec {
  username = "gustavo";
  host = "${username}-Desktop";
  homePrefix = "/home";

  # Tailscale MagicDNS FQDN (device name "desktop", tailnet taildd2a68).
  # Tailscale issues a valid TLS cert for this exact name only; Caddy + all
  # self-hosted services key their public URLs off it.
  tailnetFqdn = "desktop.taildd2a68.ts.net";

  # Public domain at deSEC (free dynamic-DNS / DNS hoster). Wildcard A record
  # *.gxdelerue.dedyn.io → Tailscale IP, so service subdomains like
  # forgejo.gxdelerue.dedyn.io resolve to this host. Caddy gets Let's Encrypt
  # certs via the deSEC DNS-01 challenge.
  deSecDomain = "gxdelerue.dedyn.io";

  # Linux-only switchable options
  displayManager = "tui";
  stylixImage = ../../Wallpapers/PinkPurpleHaze.jpg;
  barChoice = "noctalia";
  animChoice = "dynamic";

  # Per-host font sizes
  termFontSize = 14;
  uiFontSize = 14;
  stylixFontSizes = {
    terminal = 20;
    applications = 16;
    desktop = 14;
    popups = 16;
  };
}
