# Forgejo: personal git forge, accessible over Tailscale.
# Web UI on port 3000, SSH on port 3022 (avoids conflict with system SSH).
{vars, ...}: {
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
    };
    database = {
      type = "sqlite3";
    };
  };

  # Open Forgejo ports (accessible via Tailscale)
  networking.firewall.allowedTCPPorts = [3000 3022];
}
