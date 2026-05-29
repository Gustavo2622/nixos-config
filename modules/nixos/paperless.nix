# Paperless-ngx: OCR document management.
#
# SQLite backend (single-user homelab; Postgres migration is a follow-up if
# scale demands it). Binds 127.0.0.1:28981; Caddy fronts papers.gxdelerue.dedyn.io.
# Admin password + Django secret key come from sops.
#
# Consume dir: /var/lib/paperless/consume — drop scanned PDFs here and Paperless
# OCRs + indexes them. Later: wire up Syncthing for cross-device dropbox.
{
  config,
  vars,
  ...
}: let
  host = "papers.${vars.deSecDomain}";
  backend = "127.0.0.1:28981";
in {
  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    port = 28981;
    domain = host;
    passwordFile = config.sops.secrets.paperless_admin_password.path;
    environmentFile = config.sops.secrets.paperless_env.path;
    settings = {
      PAPERLESS_URL = "https://${host}";
      PAPERLESS_OCR_LANGUAGE = "eng+por";
      PAPERLESS_TIME_ZONE = "Europe/Lisbon";
      PAPERLESS_ADMIN_USER = vars.username;
    };
  };

  sops.secrets = {
    paperless_admin_password = {
      owner = "paperless";
      group = "paperless";
      mode = "0400";
      restartUnits = ["paperless-web.service"];
    };
    paperless_env = {
      owner = "paperless";
      group = "paperless";
      mode = "0400";
      restartUnits = ["paperless-web.service" "paperless-task-queue.service"];
    };
  };

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy ${backend}
    '';
  };
}
