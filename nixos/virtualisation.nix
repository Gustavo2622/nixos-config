{
  config,
  lib,
  pkgs,
  ...
}: rec {
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    virtiofsd
    spice
    spice-gtk
    spice-protocol
  ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
      ovmf = {
	enable = true;
	packages = [ pkgs.OVMFFull.fd pkgs.pkgsCross.aarch64-multiplatform.OVMF.fd ];
      };
    };
  };
  virtualisation.spiceUSBRedirection.enable = true; # maybe remove this later, gives unpriviledged access to USB

  services.spice-vdagentd.enable = true;

  users.users.gustavo.extraGroups = [ "libvirtd" ];
}
