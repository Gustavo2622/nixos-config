# /etc/nixos/flake.nix
{
  description = "Unified NixOS + nix-darwin flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin: macOS system configuration
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew: declarative Homebrew tap/cask/brew management
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Pinned Homebrew tap sources (plain git repos, not flakes)
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gl = {
      url = "github:nix-community/nixgl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=latest";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    darwin,
    nix-homebrew,
    homebrew-bundle,
    homebrew-core,
    homebrew-cask,
    alejandra,
    nix-flatpak,
    sops-nix,
    nvf,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = import ./overlays {inherit inputs;};
    overlay-set = overlays.default;
    pkgs = system:
      import nixpkgs {
        inherit system;
        overlays = [overlay-set];
      };
    flakePath = "${self}";

    # Per-host variable sets
    desktopVars = import ./modules/variables {host = "desktop";};
    macbookVars = import ./modules/variables {host = "macbook";};

    # Theme loader (shared, keyed by vars.theme)
    themeFor = vars: import ./modules/theme {themeName = vars.theme;};

    # Neovim (NVF) — built per-system
    neovimModule = system:
      nvf.lib.neovimConfiguration {
        pkgs = pkgs system;
        modules = [./modules/nvim.nix];
        extraSpecialArgs = {
          inherit inputs flakePath nvf;
        };
      };

    # nxc CLI — built per-system, per-host
    nxc = {
      system,
      vars,
      flakeRoot,
    }:
      (pkgs system).callPackage ./pkgs/nxc {
        hostName = vars.host;
        inherit flakeRoot;
        themeName = vars.theme;
      };
  in {
    inherit overlays;

    packages = forAllSystems (
      system:
        (import ./pkgs (pkgs system))
        // {inherit (neovimModule system) neovim;}
    );

    formatter = forAllSystems (system: alejandra.packages.${system}.default);

    devShells = forAllSystems (system: let
      p = pkgs system;
    in {
      default = p.mkShell {
        packages = [
          p.alejandra
          p.nil
          p.statix
          p.deadnix
          p.nix-diff
          p.ssh-to-age
          (nxc {
            inherit system;
            vars = desktopVars;
            flakeRoot = "/etc/nixos";
          })
        ];
        shellHook = ''
          export SOPS_AGE_KEY=$(ssh-to-age -i ~/.ssh/id_ed25519 -private-key 2>/dev/null || echo "")
        '';
      };
    });

    configData = {
      "gustavo-Desktop" = import ./pkgs/nxc/queries {
        inherit (nixpkgs) lib;
        config = self.nixosConfigurations.gustavo-Desktop.config;
      };
    };

    # ── NixOS (desktop) ──────────────────────────────────────────
    nixosConfigurations = let
      system = "x86_64-linux";
      vars = desktopVars;
      theme = themeFor vars;
      inherit (neovimModule system) neovim;
      nxcPkg = nxc {
        inherit system vars;
        flakeRoot = "/etc/nixos";
      };
      hmConfig = ./modules/home;
    in {
      gustavo-Desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs outputs neovim home-manager hmConfig vars theme nxcPkg;};
        modules = [
          {nixpkgs.overlays = [overlay-set];}
          ./modules/nixos
          nix-flatpak.nixosModules.nix-flatpak
        ];
      };
    };

    # ── nix-darwin (macbook) ─────────────────────────────────────
    darwinConfigurations = let
      system = "aarch64-darwin";
      vars = macbookVars;
      theme = themeFor vars;
      inherit (neovimModule system) neovim;
      nxcPkg = nxc {
        inherit system vars;
        flakeRoot = "~/nixos-config";
      };
      username = vars.username;
    in {
      gdel-macbook = darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {inherit inputs outputs vars theme neovim nxcPkg;};
        modules = [
          ./modules/darwin
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bck";
              extraSpecialArgs = {inherit inputs outputs vars theme neovim nxcPkg;};
              users.${username} = {
                imports = [
                  ./modules/home/darwin
                  sops-nix.homeManagerModules.sops
                ];
              };
            };
          }
          # nix-homebrew removed: brew manages its own taps/binary to avoid
          # nix store permission errors. nix-darwin's homebrew module handles
          # declarative cask/brew management. TODO Phase 10: revisit nix-homebrew.
          {nixpkgs.overlays = [overlay-set];}
        ];
      };
    };

    # ── Standalone home-manager (NixOS) ──────────────────────────
    homeConfigurations = let
      system = "x86_64-linux";
    in {
      "gustavo@Gustavo-Desktop" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs system;
        extraSpecialArgs = {inherit inputs self outputs;};
        modules = [
          ./modules/home
          inputs.stylix.homeManagerModules.stylix
        ];
      };
    };
  };
}
