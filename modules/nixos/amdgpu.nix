# AMD GPU setup: enables 32-bit graphics, overdrive, OpenCL, initrd loading,
# and the LACT GPU controller daemon.
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # LACT - Linux AMDGPU ConTroller
  services.lact.enable = true;

  # AMDGPU Module Options
  hardware.amdgpu = {
    overdrive.enable = true; # Enable overclocking (the wiki told me to do it -><-)
    opencl.enable = true; # Enable OpenCL support
    initrd.enable = true; # Enable driver in initrd to get nice res on boot
  };

}
