{inputs, ...}: {
  # This brings custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # Change versions, add patches, set compilation flags, anything
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    anki-bin = prev.anki-bin.overrideAttrs (old: {
      postInstall = ''
	wrapProgram "$out/bin/anki" --suffix LD_LOAD_PATH "${final.xorg.libxshmfence}/lib/"
      '';
    });
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  # When applied, the stable nixpkgs set (declared in the flake inputs) will be accessible
  # through 'pkgs.stable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
