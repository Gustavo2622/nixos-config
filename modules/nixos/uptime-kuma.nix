# Uptime Kuma: service health dashboard for all self-hosted services.
#
# Uptime Kuma is a SPA + websocket app that doesn't support a base path, so
# Caddy fronts it on a dedicated HTTPS port with the node's Tailscale cert.
# The app binds to localhost; only Caddy is exposed.
{vars, ...}: let
  backend = "127.0.0.1:3001";
  host = "uptime.${vars.deSecDomain}";
in {
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_HOST = "127.0.0.1";
      UPTIME_KUMA_PORT = "3001";
    };
  };

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy ${backend}
    '';
  };

  # No public ports — Caddy fronts the subdomain on :443.
}
