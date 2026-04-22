# Per-host variable loader.
# Usage: import ./variables { host = "desktop"; }
# Returns a flat attrset — shared values overridden by host-specific ones.
# Theme can be overridden via state/theme-override.nix (written by `nxc theme lock`).
{host ? "desktop"}: let
  shared = import ./shared.nix;
  hostVars =
    {
      "desktop" = import ./desktop.nix;
      "macbook" = import ./macbook.nix;
    }
    .${
      host
    };
  overridePath = ../../state/theme-override.nix;
  themeOverride =
    if builtins.pathExists overridePath
    then let
      raw = import overridePath;
    in
      assert builtins.isAttrs raw && raw ? theme; {inherit (raw) theme;}
    else {};
in
  shared // hostVars // themeOverride
