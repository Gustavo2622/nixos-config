# Query: networking — hostname, firewall ports
{
  config,
  lib,
}: {
  hostname = config.networking.hostName or null;
  tcpPorts = lib.attrByPath ["networking" "firewall" "allowedTCPPorts"] null config;
  udpPorts = lib.attrByPath ["networking" "firewall" "allowedUDPPorts"] null config;
}
