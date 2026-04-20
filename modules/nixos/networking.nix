# Hostname from variables.nix, NetworkManager, DHCP, NTP pool; firewall opens
# TCP 22/80/443. Additional ports opened by service-specific modules.
{
  pkgs,
  lib,
  inputs,
  options,
  vars,
  ...
}: let
  inherit (vars) host;
in {
  networking = {
    hostName = host;
    useDHCP = lib.mkForce true;
    networkmanager.enable = true;
    timeServers = options.networking.timeServers.default ++ ["pool.ntp.org"];
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
      ];
      allowedUDPPorts = [];
    };
  };
  environment.systemPackages = with pkgs; [networkmanagerapplet];
}
