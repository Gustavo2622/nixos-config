# SearXNG: private meta-search engine.
#
# Runs under uwsgi, bound to localhost on :8080. Caddy fronts
# search.gxdelerue.dedyn.io with the LE cert via DNS-01. Secret key from
# sops (interpolated into settings.yml via $SEARXNG_SECRET_KEY env var).
{
  config,
  vars,
  pkgs,
  ...
}: let
  host = "search.${vars.deSecDomain}";
  backend = "127.0.0.1:8080";
in {
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    runInUwsgi = true;
    environmentFile = config.sops.secrets.searxng_secret_key.path;

    # Bind uwsgi to localhost only — Caddy proxies on the public subdomain.
    uwsgiConfig = {
      http = "127.0.0.1:8080";
    };

    settings = {
      server = {
        base_url = "https://${host}/";
        secret_key = "$SEARXNG_SECRET_KEY"; # filled by envsubst from EnvironmentFile
      };
      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
        default_lang = "auto";
        formats = ["html" "json"];
      };
      ui = {
        infinite_scroll = true;
        default_theme = "simple";
        theme_args.simple_style = "auto";
      };
    };
  };

  sops.secrets.searxng_secret_key = {
    owner = "searx";
    group = "searx";
    mode = "0400";
    restartUnits = ["uwsgi.service"];
  };

  services.caddy.virtualHosts."${host}" = {
    extraConfig = ''
      import le_desec
      reverse_proxy ${backend}
    '';
  };
}
