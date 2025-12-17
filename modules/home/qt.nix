# Enables Qt support using the qtct platform theme for consistent Qt app styling.
{lib, ...}: {
  qt = {
    enable = true;
    platformTheme.name = lib.mkForce "qtct";
  };
}
