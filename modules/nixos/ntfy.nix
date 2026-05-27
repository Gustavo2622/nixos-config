# ntfy: self-hosted push notifications (phone <-> desktop).
#
# ntfy must own the root of its host (no subpath support), so Caddy fronts it
# on a dedicated HTTPS port using the node's valid Tailscale cert. The ntfy
# server itself binds to localhost; only Caddy is exposed.
{vars, ...}: let
  port = 8443; # public HTTPS port (Caddy); subdomain replaces this later
  backend = "127.0.0.1:2586";
  url = "https://${vars.tailnetFqdn}:${toString port}";
in {
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = url;
      listen-http = backend; # localhost only — Caddy proxies
      behind-proxy = true; # trust X-Forwarded-For from Caddy
    };
  };

  services.caddy.virtualHosts."${vars.tailnetFqdn}:${toString port}" = {
    extraConfig = ''
      tls {
        get_certificate tailscale
      }
      reverse_proxy ${backend}
    '';
  };

  networking.firewall.allowedTCPPorts = [port];
}
