# Miniflux: lightweight RSS reader (Go + Postgres).
#
# Bound to localhost; Caddy fronts rss.gxdelerue.dedyn.io. Postgres DB +
# user created locally via the module's createDatabaseLocally. Admin user
# from a sops-rendered env file (`ADMIN_USERNAME=…`, `ADMIN_PASSWORD=…`).
{
  config,
  vars,
  ...
}: let
  host = "rss.${vars.deSecDomain}";
  port = 8086;
in {
  services.miniflux = {
    enable = true;
    adminCredentialsFile = config.sops.secrets.miniflux_admin.path;
    config = {
      LISTEN_ADDR = "127.0.0.1:${toString port}";
      BASE_URL = "https://${host}/";
      # Trust X-Forwarded-* from Caddy
      FORCE_REFRESH_INTERVAL = "30";
    };
  };

  # No owner/group: miniflux uses DynamicUser so the user isn't around at
  # sops activation time. systemd reads the EnvironmentFile path as root
  # before dropping privileges, so root:root mode 0400 is enough.
  sops.secrets.miniflux_admin = {
    mode = "0400";
    restartUnits = ["miniflux.service"];
  };

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy 127.0.0.1:${toString port}
    '';
  };
}
