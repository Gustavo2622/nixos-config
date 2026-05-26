# Forgejo: personal git forge, accessible over Tailscale.
# Web UI on port 3000, SSH on port 3022 (avoids conflict with system SSH).
# Actions runner for CI (nix flake check, nxc health).
{
  vars,
  pkgs,
  ...
}: {
  services.forgejo = {
    enable = true;
    settings = {
      DEFAULT.APP_NAME = "forge";
      server = {
        DOMAIN = "gustavo-Desktop";
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3000;
        START_SSH_SERVER = true;
        SSH_PORT = 3022;
        SSH_LISTEN_PORT = 3022;
        ROOT_URL = "http://gustavo-Desktop:3000/";
      };
      service = {
        DISABLE_REGISTRATION = true;
      };
      session = {
        COOKIE_SECURE = false;
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

  # Open Forgejo ports (accessible via Tailscale)
  networking.firewall.allowedTCPPorts = [3000 3022];
}
