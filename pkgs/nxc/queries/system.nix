# Query: system — architecture, display manager, WM, theme
{
  config,
  lib,
}: {
  nixosVersion = config.system.nixos.release or null;
  stateVersion = config.system.stateVersion or null;
}
