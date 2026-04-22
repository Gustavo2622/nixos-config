# Compose all query modules into a single attrset.
# Takes { config, lib } and returns a flat structure of serializable data.
{
  config,
  lib,
}: {
  networking = import ./networking.nix {inherit config lib;};
  packages = import ./packages.nix {inherit config lib;};
  services = import ./services.nix {inherit config lib;};
  system = import ./system.nix {inherit config lib;};
}
