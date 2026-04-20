# Per-host variable loader.
# Usage: import ./variables { host = "desktop"; }
# Returns a flat attrset — shared values overridden by host-specific ones.
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
in
  shared // hostVars
