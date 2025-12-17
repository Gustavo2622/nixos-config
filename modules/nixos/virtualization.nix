# Docker daemon, libvirtd with QEMU and swtpm (TPM emulation); installs
# virt-viewer, lazydocker, docker-compose, virtiofsd, and spice clients.
{pkgs, ...}: {
  virtualisation = {
    docker.enable = true;

    podman.enable = false;

    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
      };
    };
  };

  programs = {
    virt-manager.enable = true;
  };

  environment.systemPackages = with pkgs; [
    virt-viewer
    lazydocker
    docker-client
    docker-compose
    virtiofsd
    spice
    spice-gtk
    spice-protocol
  ];
}
