# Postgres extras for the research-mining DB.
#
# Postgres itself is brought up by services.atuin (database.createLocally=true).
# Here we add pgvector + an nxcmine database/role on the same instance. Peer
# auth on the unix socket: any process running as user `nxcmine` (or `gustavo`,
# via the local trust below) can connect without a password.
{
  pkgs,
  lib,
  ...
}: {
  services.postgresql = {
    extensions = ps: [ps.pgvector];

    ensureDatabases = ["nxcmine"];
    ensureUsers = [
      {
        name = "nxcmine";
        ensureDBOwnership = true;
      }
    ];

    # Allow the local user `gustavo` to connect to nxcmine via the unix socket
    # for ad-hoc psql / debugging (peer auth maps OS user → PG role).
    identMap = ''
      nxc-research gustavo  nxcmine
      nxc-research nxcmine  nxcmine
      nxc-research postgres nxcmine
    '';
    # Restrict to PG role `nxcmine` so the postgres superuser (and others) fall
    # through to the default local rule. Without this scoping our rule grabs
    # every connection to the nxcmine DB and rejects users not in the map.
    authentication = ''
      local nxcmine nxcmine peer map=nxc-research
    '';
  };

  # pgvector isn't marked trusted in this build, so the DB owner can't
  # CREATE EXTENSION on its own. A oneshot service runs once postgres is up,
  # waits for the nxcmine DB to exist (it's created by the postgres module's
  # own ExecStartPost), then enables vector. `IF NOT EXISTS` makes it idempotent.
  systemd.services.postgresql-nxcmine-ext = {
    description = "Enable pgvector in the nxcmine database";
    wantedBy = ["multi-user.target"];
    after = ["postgresql.service"];
    requires = ["postgresql.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      RemainAfterExit = true;
    };
    script = ''
      until ${pkgs.postgresql}/bin/psql -d nxcmine -tAc 'SELECT 1' >/dev/null 2>&1; do
        sleep 1
      done
      ${pkgs.postgresql}/bin/psql -d nxcmine -tAc 'CREATE EXTENSION IF NOT EXISTS vector;'
    '';
  };
}
