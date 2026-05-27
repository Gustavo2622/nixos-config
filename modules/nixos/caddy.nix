# Caddy: unified HTTPS reverse proxy over Tailscale.
#
# Path-based routing for now (e.g. /git, /papers). Per-service subdomains
# (papers.gustavo-Desktop) are deferred to the Headscale phase — they need
# wildcard DNS + an internal CA or a real domain, which Tailscale certs can't do.
#
# TLS: Caddy's native Tailscale cert getter fetches the cert for this node's
# MagicDNS name via the local tailscaled API. Prerequisite (one-time, manual):
# enable HTTPS for the tailnet in the Tailscale admin console (DNS settings).
{...}: let
  # This node's MagicDNS FQDN (tailnet taildd2a68). Tailscale issues a valid
  # cert for this exact name only. (Tailscale device name is "desktop"; the
  # system hostname is still gustavo-Desktop.)
  fqdn = "desktop.taildd2a68.ts.net";
in {
  # Let the caddy user fetch Tailscale certs via the tailscaled LocalAPI.
  services.tailscale.permitCertUid = "caddy";

  services.caddy = {
    enable = true;
    virtualHosts."${fqdn}" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        # Placeholder root — services mount under paths as they land.
        respond "nxc Caddy is up — path-based services mount here." 200
      '';
    };

    # Short MagicDNS name: HTTP-only redirect to the FQDN. Deliberately no TLS
    # here — the browser's HTTPS-first attempt to https://desktop finds nothing
    # on 443, falls back to HTTP, and this 308s to the FQDN, where the cert is
    # validated against the full name (no cert warning, no client trust step).
    virtualHosts."http://desktop" = {
      extraConfig = ''
        redir https://${fqdn}{uri} permanent
      '';
    };
  };

  # HTTP (redirect) + HTTPS. Reachable over Tailscale.
  networking.firewall.allowedTCPPorts = [80 443];
}
