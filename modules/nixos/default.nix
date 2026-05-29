# NixOS module aggregator: imports all system-level modules and conditionally loads
# the display manager (greetd/ly/sddm) based on displayManager in variables.nix.
{
  pkgs,
  inputs,
  vars,
  ...
}: {
  imports = [
    # Include graphics card configuration
    ./amdgpu.nix
    ./atuin.nix
    ./audio.nix
    ./boot.nix
    ./cachix.nix
    ./caddy.nix
    ./editor.nix
    ./flatpak.nix
    ./fonts.nix
    ./forgejo.nix
    # Include the results of the hardware scan.
    # ./greetd.nix
    ./hardware-configuration.nix
    ./hyprlandwm.nix
    # NixOS hardware imports
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.stylix.nixosModules.stylix
    ./keyboard.nix
    ./locale.nix
    (
      if vars.displayManager == "tui"
      then ./greetd.nix
      else if vars.displayManager == "ly"
      then ./ly.nix
      else ./sddm.nix
    )
    # ../modules/config/desktop-monitor-cfg.nix
    ./networking.nix
    ./nh.nix
    ./nix.nix
    ./ntfy.nix
    ./ollama.nix
    ./paperless.nix
    ./postgresql.nix
    ./printing.nix
    ./rtc-wake.nix
    ./quickshell.nix
    ./security.nix
    ./services.nix
    ./searxng.nix
    ./sops.nix
    ./ssh.nix
    ./steam.nix
    ./syncthing.nix
    ./tailscale.nix
    ./stylix.nix
    ./uptime-kuma.nix
    ./user.nix
    ./vaultwarden.nix
    ./utils.nix
    ./virtualization.nix
    ./windows.nix
  ];
}
