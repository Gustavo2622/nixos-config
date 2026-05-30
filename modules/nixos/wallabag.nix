# Wallabag: read-later service (Symfony PHP — no native nixpkgs module).
#
# Runs as a Podman OCI container; Caddy fronts read.gxdelerue.dedyn.io.
# SQLite backend (single user); persistent data + images bind-mounted from
# /var/lib/wallabag/. Symfony secret from sops via environmentFiles.
#
# First-run setup (interactive, one-time):
#   sudo docker exec -it wallabag \
#     /var/www/wallabag/bin/console fos:user:create --super-admin
#
# After that, log in at https://read.gxdelerue.dedyn.io/ and disable
# registration in Internal Settings if you want belt+braces.
{
  config,
  vars,
  ...
}: let
  host = "read.${vars.deSecDomain}";
  port = 8484;
in {
  # Reuses the existing Docker daemon enabled in modules/nixos/virtualization.nix.
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.wallabag = {
    image = "wallabag/wallabag:2.6.13";
    autoStart = true;
    ports = ["127.0.0.1:${toString port}:80"];
    environment = {
      SYMFONY__ENV__DOMAIN_NAME = "https://${host}";
      SYMFONY__ENV__SERVER_NAME = "nxc wallabag";
      SYMFONY__ENV__DATABASE_DRIVER = "pdo_sqlite";
      SYMFONY__ENV__DATABASE_NAME = "wallabag";
      SYMFONY__ENV__FOSUSER_REGISTRATION = "false";
      SYMFONY__ENV__FOSUSER_CONFIRMATION = "false";
      SYMFONY__ENV__TWOFACTOR_AUTH = "false";
    };
    environmentFiles = [config.sops.secrets.wallabag_env.path];
    volumes = [
      "/var/lib/wallabag/data:/var/www/wallabag/data"
      "/var/lib/wallabag/images:/var/www/wallabag/web/assets/images"
    ];
  };

  sops.secrets.wallabag_env = {
    mode = "0400"; # default root-only; docker-wallabag runs as root
    restartUnits = ["docker-wallabag.service"];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/wallabag       0755 root root - -"
    "d /var/lib/wallabag/data   0755 root root - -"
    "d /var/lib/wallabag/images 0755 root root - -"
  ];

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy 127.0.0.1:${toString port}
    '';
  };
}
