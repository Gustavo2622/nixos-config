{
  lib,
  config,
  ...
}: let 
  inherit (lib) mkOption types;
in {
  options.monitors = mkOption {
    type = types.listOf (
      types.submodule {
	options = {
	  name = mkOption {
	    type = types.str;
	    example = "DP-1";
	  };
	  primary = mkOption {
	    type = types.bool;
	    default = false;
	  };
	  width = mkOption {
	    type = types.int;
	    example = 1920;
	  };
	  height = mkOption {
	    type = types.int;
	    example = 1080;
	  };
	  refreshRate = mkOption {
	    type = types.int;
	    example = 1080;
	  };
	  position = mkOption {
	    type = types.str;
	    example = "1920x1080";
	    description = "Position as either auto or horiz x vert (in pixels)";
	  };
	  refreshRate = mkOption {
	    type = types.int;
	    example = 60;
	  };
	  dpi = mkOption {
	    type = types.int;
	    example = 80;
	  };
	  scale = mkOption {
	    type = types.int;
	    example = 2;
	  };
	  workspace = mkOption {
	    type  = types.nullOr types.str;
	    default = null;
	  };
	  edid = mkOption {
	    type  = types.nullOr types.str;
	    default = null;
	  };
	};
      }
    );
    default = [];
  };
  config = {
    assertions = [
      {
	assertion =
	  ((lib.length config.monitors) != 0)
	  -> ((lib.length (lib.filter (m: m.primary) config.monitors)) == 1);
	message = "Exactly one monitor must be set to primary.";
      };
    ];
  };
}
