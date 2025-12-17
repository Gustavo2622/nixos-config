{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    bitwarden-cli
    bitwarden-menu
    bitwarden-desktop
  ];
}
