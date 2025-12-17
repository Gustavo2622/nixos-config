# NixOS module aggregator: imports all system-level modules and conditionally loads
# the display manager (greetd/ly/sddm) based on displayManager in variables.nix.
{
  pkgs,
  inputs,
  ...
}: let
  vars = import ../variables.nix;
in {
  imports = [
    # Include graphics card configuration
    ./amdgpu.nix
    ./audio.nix
    ./boot.nix
    ./cachix.nix
    ./editor.nix
    ./flatpak.nix
    ./fonts.nix
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
    ./printing.nix
    ./quickshell.nix
    ./security.nix
    ./services.nix
    # ./sops.nix
    ./ssh.nix
    ./steam.nix
    ./stylix.nix
    ./user.nix
    ./utils.nix
    ./virtualization.nix
    ./windows.nix
  ];
}
