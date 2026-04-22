# Query: services — enabled systemd services
{
  config,
  lib,
}: let
  allServices = lib.attrByPath ["systemd" "services"] {} config;
  enabledNames = lib.filter (name: let
    svc = allServices.${name};
  in
    (svc.enable or true) && !(svc.enableStrictShellChecks or false))
  (builtins.attrNames allServices);
in {
  count = builtins.length enabledNames;
  names = enabledNames;
}
