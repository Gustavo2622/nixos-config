# SOPS-nix secrets with age encryption using SSH key at ~/.ssh/id_ed25519;
# currently manages the bitwarden master password secret.
{
  sops-nix,
  pkgs,
  vars,
  ...
} @ inputs: rec {
  imports = [
    sops-nix.nixosModules.sops
  ];

  config = {
    sops = {
      defaultSopsFile = ./secrets/secrets.yaml;

      age.sshKeyPaths = ["/home/${vars.username}/.ssh/id_ed25519"];
      secrets = {
        "bitwarden/master-pass" = {};
      };
    };
    environment.systemPackages = with pkgs; [
      sops
      ssh-to-age # to allow secrets management
    ];
  };
}
