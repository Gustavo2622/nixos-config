# Creates the gustavo user (from variables.nix) with zsh, home-manager integration,
# and groups: wheel, docker, libvirtd, networkmanager, adbusers, scanner, lp, vboxusers.
{
  pkgs,
  inputs,
  outputs,
  hmConfig,
  ...
}: let
  inherit (import ../variables.nix) username gitUsername;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
  config = {
    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = false;
      extraSpecialArgs = {inherit inputs username outputs;};
      backupFileExtension = "bck";
      users.${username} = { 
        home = {
          username = "${username}";
          homeDirectory = "/home/${username}";
          stateVersion = "24.11";
        };
        imports = [
          hmConfig
        ];
      };
    };
    users.mutableUsers = true;
    users.users.${username} = {
      isNormalUser = true;
      description = "${gitUsername}";
      extraGroups = [
        "adbusers"
        "docker"
        "libvirtd"
        "lp"
        "networkmanager" 
        "scanner"
        "vboxusers"
        "wheel"
      ];
      shell = pkgs.zsh;
      ignoreShellProgramCheck = true;
    };
    nix.settings.allowed-users = ["${username}"];
  };
}
