# Syncthing file synchronization. Folder config TBD after Tailscale pairing.
{vars, ...}: {
  services.syncthing = {
    enable = true;
    user = vars.username;
    group = "users";
    dataDir = "${vars.homePrefix}/${vars.username}";
    configDir = "${vars.homePrefix}/${vars.username}/.config/syncthing";
    openDefaultPorts = true; # TCP 22000 + UDP 21027
  };
}
