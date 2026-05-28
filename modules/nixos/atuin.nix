# Atuin: encrypted shell-history sync server.
#
# Listens on localhost only; Caddy fronts atuin.gxdelerue.dedyn.io with the
# valid LE cert via DNS-01. Still tailnet-gated (the subdomain resolves to
# the Tailscale IP, reachable only from devices on the tailnet).
{vars, ...}: let
  host = "atuin.${vars.deSecDomain}";
  backend = "127.0.0.1:8888";
in {
  services.atuin = {
    enable = true;
    openRegistration = true; # tailnet-gated; closes once all clients registered
    host = "127.0.0.1";
    port = 8888;
  };

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy ${backend}
    '';
  };
}
