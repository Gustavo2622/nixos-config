{pkgs, ...}: {
  home.packages = with pkgs; [
    dockutil # Declarative dock management
  ];
}
