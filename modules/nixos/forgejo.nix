# Forgejo: personal git forge, accessible over Tailscale.
# Web UI on port 3000, SSH on port 3022 (avoids conflict with system SSH).
# Actions runner for CI (nix flake check, nxc health).
{
  vars,
  pkgs,
  ...
}: let
  webPort = 8445; # public HTTPS port (Caddy); Forgejo itself stays on localhost:3000
in {
  services.forgejo = {
    enable = true;
    settings = {
      DEFAULT.APP_NAME = "forge";
      server = {
        DOMAIN = vars.tailnetFqdn;
        # Localhost only — Caddy fronts the web UI on HTTPS. The CI runner still
        # reaches Forgejo at localhost:3000, so no re-registration needed.
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        START_SSH_SERVER = true;
        SSH_PORT = 3022;
        SSH_LISTEN_PORT = 3022;
        ROOT_URL = "https://${vars.tailnetFqdn}:${toString webPort}/";
      };
      service = {
        DISABLE_REGISTRATION = true;
      };
      session = {
        COOKIE_SECURE = true; # served over HTTPS via Caddy
      };
      actions = {
        ENABLED = true;
      };
    };
    database = {
      type = "sqlite3";
    };
  };

  # Forgejo Actions runner — executes CI workflows on the local machine
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.default = {
      enable = true;
      name = "desktop-runner";
      url = "http://localhost:3000";
      labels = [
        "native:host"
      ];
      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        gawk
        git
        gnused
        nix
        nodejs
      ];
      settings = {
        runner.fetch_timeout = "10s";
        runner.fetch_interval = "5s";
      };
      # Token from Forgejo admin panel: /admin/actions/runners
      tokenFile = "/var/lib/gitea-runner/default/token";
    };
  };

  # Caddy fronts the web UI on its own HTTPS port with the node's Tailscale cert.
  services.caddy.virtualHosts."${vars.tailnetFqdn}:${toString webPort}" = {
    extraConfig = ''
      tls {
        get_certificate tailscale
      }
      reverse_proxy 127.0.0.1:3000
    '';
  };

  # Public ports over Tailscale: HTTPS web UI (Caddy) + git-over-SSH.
  # :3000 is no longer exposed — Forgejo binds to localhost.
  networking.firewall.allowedTCPPorts = [webPort 3022];
}
