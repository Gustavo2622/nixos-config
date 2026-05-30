# Linkding: bookmark manager.
#
# SQLite backend (single user, low traffic). Bound to localhost; Caddy fronts
# links.gxdelerue.dedyn.io. Django secret + superuser come from sops via
# environmentFile.
{
  config,
  vars,
  ...
}: let
  host = "links.${vars.deSecDomain}";
  port = 9090;
in {
  services.linkding = {
    enable = true;
    address = "127.0.0.1";
    port = port;
    environmentFile = config.sops.secrets.linkding_env.path;
    settings = {
      # Recommended for behind-Caddy:
      LD_REQUEST_TIMEOUT = "120";
      LD_CSRF_TRUSTED_ORIGINS = "https://${host}";
    };
  };

  # Linkding service runs as a DynamicUser (no static `linkding` user); systemd
  # reads EnvironmentFile as root before privilege drop, so root:root works.
  sops.secrets.linkding_env = {
    mode = "0400";
    restartUnits = ["linkding.service"];
  };

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy 127.0.0.1:${toString port}
    '';
  };
}
