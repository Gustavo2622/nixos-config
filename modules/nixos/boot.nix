# Boot: Linux Zen kernel, v4l2loopback for virtual cameras, Plymouth splash,
# AppImage binfmt, systemd-boot (5-config limit), EDK2 UEFI shell.
{
  lib,
  pkgs,
  config,
  inputs,
  ...
} @ args: {
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    kernelModules = [
      "v4l2loopback"
    ];
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
    ];

    plymouth.enable = true;
    # AppImage support
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };

    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot = let
      efi-shell-rel-path = "efi/shell.efi";
      efi-shell-path = "/${efi-shell-rel-path}";
    in {
      enable = true;
      configurationLimit = 5;
      #  sortKey = "nixos";

      # Copy EDK2 Shell to boot partition
      extraFiles."${efi-shell-rel-path}" = "${pkgs.edk2-uefi-shell}/shell.efi";
      extraEntries = {
        # Make EDK2 Shell available as boot option
        "edk2-uefi-shell.conf" = ''
          title EDK2 UEFI Shell
          efi ${efi-shell-path}
          sort-key y_edk2
        '';
      };
    };
  };
}
