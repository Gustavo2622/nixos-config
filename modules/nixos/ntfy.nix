# ntfy: self-hosted push notifications (phone <-> desktop).
#
# ntfy must own the root of its host (no subpath support), so Caddy fronts it
# on a dedicated HTTPS port using the node's valid Tailscale cert. The ntfy
# server itself binds to localhost; only Caddy is exposed.
{vars, ...}: let
  backend = "127.0.0.1:2586";
  host = "ntfy.${vars.deSecDomain}";
in {
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://${host}";
      listen-http = backend; # localhost only — Caddy proxies
      behind-proxy = true; # trust X-Forwarded-For from Caddy
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
