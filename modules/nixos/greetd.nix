# Greetd login manager using tuigreet with --time flag; session launches Hyprland.
{
  pkgs,
  vars,
  ...
}: let
  inherit (vars) username;
in {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = username;
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      };
    };
  };
}
