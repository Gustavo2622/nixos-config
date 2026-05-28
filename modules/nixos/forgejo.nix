# Forgejo: personal git forge, accessible over Tailscale.
# Web UI on port 3000, SSH on port 3022 (avoids conflict with system SSH).
# Actions runner for CI (nix flake check, nxc health).
{
  vars,
  pkgs,
  ...
}: let
  host = "forgejo.${vars.deSecDomain}";
in {
  services.forgejo = {
    enable = true;
    settings = {
      DEFAULT.APP_NAME = "forge";
      server = {
        DOMAIN = host;
        # Localhost only — Caddy fronts the web UI on HTTPS. The CI runner still
        # reaches Forgejo at localhost:3000, so no re-registration needed.
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        START_SSH_SERVER = true;
        SSH_PORT = 3022;
        SSH_LISTEN_PORT = 3022;
        ROOT_URL = "https://${host}/";
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

  # Caddy fronts the web UI on the deSEC subdomain (LE cert via DNS-01).
  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy 127.0.0.1:3000
    '';
  };

  # Public ports: Caddy's HTTPS is on :443 (opened in caddy.nix); git-over-SSH
  # stays on :3022. :3000 is not exposed — Forgejo binds to localhost.
  networking.firewall.allowedTCPPorts = [3022];
}
