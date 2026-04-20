# Hostname from variables.nix, NetworkManager, DHCP, NTP pool; firewall opens
# TCP/UDP 22/80/443 and 59010-59011.
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
        59010
        59011
        8080
      ];
      allowedUDPPorts = [
        59010
        59011
      ];
    };
  };
  environment.systemPackages = with pkgs; [networkmanagerapplet];
}
