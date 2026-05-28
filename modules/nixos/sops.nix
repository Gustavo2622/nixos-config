# sops-nix: declarative secrets on NixOS.
#
# Server-side secrets live in `secrets/server.yaml` (sops-encrypted to the
# desktop host age key + the user's personal age key). At activation,
# sops-nix decrypts and mounts each declared secret at /run/secrets/<name>
# with the configured owner/mode.
#
# Editing: `sops secrets/server.yaml` (using either age identity). The host
# private key lives at /var/lib/sops-nix/key.txt (root-only, NOT in /nix/store).
# Migration to YubiKey via age-plugin-yubikey is Phase-16 work.
{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.sops-nix.nixosModules.sops];

  sops = {
    defaultSopsFile = ../../secrets/server.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets.caddy_desec_env = {
      owner = "caddy";
      group = "caddy";
      mode = "0400";
      restartUnits = ["caddy.service"];
    };
  };

  environment.systemPackages = with pkgs; [sops age];
}
