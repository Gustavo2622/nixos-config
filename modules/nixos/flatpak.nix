# Enables Flatpak with XDG portal (Hyprland backend) and auto-update on activation.
{pkgs, ...}: {
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-hyprland];
    configPackages = [pkgs.hyprland];
    config.common.default = "gtk";
  };
  services = {
    flatpak = {
      enable = true;

      packages = [
        #"com.github.tchx84.Flatseal"     # Manage flatpak permissions - should always have this
        #"com.rtosta.zapzap"              # WhatsApp client
        #"io.github.flattool.Warehouse"   # Manage flatpaks, clean data, remove flatpaks and deps
        #"it.mijorus.gearlever"           # Manage and support AppImages
        #"io.github.dvlv.boxbuddyrs"      # Manage distroboxes
        #"de.schmidhuberj.tubefeeder"     # Watch YT videos
      ];

      update.onActivation = true;
    };
  };
}
