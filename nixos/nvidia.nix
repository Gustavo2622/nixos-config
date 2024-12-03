{ config, lib, pkgs, ... }:

{
  # Enable graphics
  hardware.graphics = {
    enable = true;
  };

  services.xserver.videoDrivers = ["nvidia"];
  
  hardware.nvidia = {
  
    # Modesetting is required
    modesetting.enable = true;
 
    powerManagement.enable = true;

    powerManagement.finegrained = false;

    open = false;

    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}

