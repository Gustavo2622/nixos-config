# Vaultwarden: self-hosted Bitwarden-compatible password manager.
#
# Listens on localhost only; Caddy fronts vault.gxdelerue.dedyn.io (LE cert
# via DNS-01). SQLite backend — fine for a single user. Admin token is a
# sops-rendered env file. SIGNUPS_ALLOWED is open initially so the first
# user can register; flip to false after that in a small follow-up commit.
{
  config,
  vars,
  ...
}: let
  host = "vault.${vars.deSecDomain}";
  backend = "127.0.0.1:8222";
in {
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    environmentFile = config.sops.secrets.vaultwarden_admin_token.path;
    config = {
      DOMAIN = "https://${host}";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      # Closed after first account was registered; new users via admin invite.
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = true;
      WEBSOCKET_ENABLED = true;
    };
  };

  sops.secrets.vaultwarden_admin_token = {
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "0400";
    restartUnits = ["vaultwarden.service"];
  };

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy ${backend}
    '';
  };
}
