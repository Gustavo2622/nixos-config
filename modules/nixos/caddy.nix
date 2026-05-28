# Caddy: unified HTTPS reverse proxy.
#
# Two TLS sources cohabit:
#   - Tailscale cert getter for the node's MagicDNS FQDN (tailscaled LocalAPI)
#   - Let's Encrypt via deSEC DNS-01 for *.gxdelerue.dedyn.io (default for any
#     vhost without an explicit tls block — see acme_dns in globalConfig)
#
# Path-based routing was the v1; we're moving to per-service subdomains under
# the deSEC domain. Existing :port vhosts stay during the transition.
#
# deSEC API token lives at /var/lib/caddy/desec-env (root-owned, mode 600),
# loaded as $DESEC_API_TOKEN via the systemd EnvironmentFile. NOT in the nix
# store. Sops-nix on NixOS isn't wired yet (TODO).
{
  vars,
  pkgs,
  lib,
  ...
}: let
  fqdn = vars.tailnetFqdn;
  domain = vars.deSecDomain;
in {
  # Let the caddy user fetch Tailscale certs via the tailscaled LocalAPI.
  services.tailscale.permitCertUid = "caddy";

  # Load deSEC API token at runtime. The "-" prefix makes the file optional so
  # caddy doesn't fail to start if the token hasn't been planted yet (the
  # tailscale-cert vhost keeps working in that case; ACME for subdomains fails
  # loudly in the journal until the file is in place).
  systemd.services.caddy.serviceConfig.EnvironmentFile = "-/var/lib/caddy/desec-env";

  services.caddy = {
    enable = true;

    # Custom caddy build with the deSEC DNS provider plugin (xcaddy under the
    # hood). First build is slow (Go compile); subsequent ones are cached.
    package = pkgs.caddy.withPlugins {
      plugins = ["github.com/caddy-dns/desec@v1.1.0"];
      hash = "sha256-xHmhjCrAaqbnYLAxXCsZ8ah6umgwHWQIXWqeDbghCOo=";
    };

    # Shared TLS config for all *.${domain} vhosts. deSEC publishes records to
    # its auth NSes on a ~60s cycle, so propagation_delay must outlast that or
    # Let's Encrypt validates before the TXT challenge is visible (HTTP 403).
    # Snippet lives in extraConfig (Caddyfile is parsed in two passes, so site
    # blocks can `import` snippets defined anywhere in the file).
    extraConfig = ''
      (le_desec) {
        tls {
          dns desec {
            token {env.DESEC_API_TOKEN}
          }
          propagation_delay 120s
          propagation_timeout 10m
        }
      }
    '';

    virtualHosts."${fqdn}" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        respond "nxc Caddy is up — Tailscale FQDN. Subdomain entry: https://${domain}" 200
      '';
    };

    # Apex placeholder for the public domain.
    virtualHosts."${domain}" = {
      extraConfig = ''
        import le_desec
        respond "nxc Caddy is up — services live at subdomains of ${domain}" 200
      '';
    };

    # Short MagicDNS name: HTTP-only redirect to the FQDN. Browser HTTPS-first
    # attempt finds nothing on 443, falls back to HTTP, 308s to the FQDN, where
    # the cert is validated against the full name. No cert warning, no trust step.
    virtualHosts."http://desktop" = {
      extraConfig = ''
        redir https://${fqdn}{uri} permanent
      '';
    };
  };

  # HTTP (ACME http-01 redirects / short-name redirect) + HTTPS.
  networking.firewall.allowedTCPPorts = [80 443];
}
