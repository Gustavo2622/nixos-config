# OpenSSH on port 22 with SFTP, root login disabled, password and
# keyboard-interactive auth allowed.
{lib, ...} @ args: {
  services.openssh = {
    enable = true;
    allowSFTP = true;
    settings = {
      PermitRootLogin = "no"; # No root logins from SSH
      PasswordAuthentication = true; # Allow keyboard auth
      KbdInteractiveAuthentication = true;
    };
    ports = [22];
  };
}
