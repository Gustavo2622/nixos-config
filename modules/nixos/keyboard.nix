# US keyboard layout with Ctrl/Caps Lock swap via XKB options, applied to both
# X11 and the console.
{
  pkgs,
  inputs,
  ...
} @ args: {
  services.xserver.xkb = {
    layout = "us";
    variant = "";
    options = "ctrl:swapcaps";
  };

  console.useXkbConfig = true;
}
