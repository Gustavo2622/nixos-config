# Uptime Kuma: service health dashboard for all self-hosted services.
#
# Uptime Kuma is a SPA + websocket app that doesn't support a base path, so
# Caddy fronts it on a dedicated HTTPS port with the node's Tailscale cert.
# The app binds to localhost; only Caddy is exposed.
{vars, ...}: let
  port = 8444; # public HTTPS port (Caddy); subdomain replaces this later
  backend = "127.0.0.1:3001";
in {
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_HOST = "127.0.0.1";
      UPTIME_KUMA_PORT = "3001";
    };
  };

  services.caddy.virtualHosts = {
    "${vars.tailnetFqdn}:${toString port}" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy ${backend}
      '';
    };
    # New subdomain entry — Let's Encrypt cert via deSEC DNS-01.
    "uptime.${vars.deSecDomain}" = {
      extraConfig = ''
        import le_desec
        reverse_proxy ${backend}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [port];
}
