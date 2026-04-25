# sops-nix secrets framework for darwin (home-manager)
# No secrets wired yet — this sets up the identity and default config.
# Actual secrets will be added when YubiKey / key management is configured.
{vars, ...}: {
  sops = {
    age.keyFile = "${vars.homePrefix}/${vars.username}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
  };
}
