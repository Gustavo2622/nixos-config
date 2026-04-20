# OpenSSH: key-only auth, no root login, SFTP enabled.
# Password auth disabled — use SSH keys distributed via Tailscale.
_: {
  services.openssh = {
    enable = true;
    allowSFTP = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    ports = [22];
  };
}
