# /etc/nixos/flake.nix
{
  description = "flake for gustavo-Desktop";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    # home-manager for home management : )
    home-manager = {
      url = "github:nix-community/home-manager";
      # The follows keyword in inputs is used for inheritance
      # Here inputs.nixpkgs of home-manager is kept consistent with
      # the inputs.nixpkgs of the current flake
      # to avoid problems due to version mismatch
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
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
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak?ref=latest";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    alejandra,
    nix-flatpak,
    # sops-nix,
    nvf,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    hmConfig = ./modules/home;
    overlays = import ./overlays {inherit inputs;};
    overlay-set = overlays.default;
    pkgs = system:
      import nixpkgs {
        inherit system;
        overlays = [overlay-set];
      };
    flakePath = "${self}";
    vars = import ./modules/variables {host = "desktop";};
    theme = import ./modules/theme {themeName = vars.theme;};
    neovimModule = system:
      nvf.lib.neovimConfiguration {
        pkgs = pkgs system;
        modules = [./modules/nvim.nix];
        extraSpecialArgs = {
          inherit inputs flakePath nvf;
        };
      };
    nxc = system:
      (pkgs system).callPackage ./pkgs/nxc {
        hostName = vars.host;
        flakeRoot = "/etc/nixos";
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
        packages = [p.alejandra p.nil p.statix p.deadnix p.nix-diff p.ssh-to-age (nxc system)];
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

    nixosConfigurations = let
      system = "x86_64-linux";
      inherit (neovimModule system) neovim;
      nxcPkg = nxc system;
    in {
      gustavo-Desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs outputs neovim home-manager hmConfig vars theme nxcPkg;};
        modules = [
          {
            nixpkgs.overlays = [overlay-set];
          }
          ./modules/nixos
          nix-flatpak.nixosModules.nix-flatpak
        ];
      };
    };

    homeConfigurations = let
      system = "x86_64-linux";
    in {
      "gustavo@Gustavo-Desktop" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs system;
        extraSpecialArgs = {inherit inputs self outputs;};
        modules = [
          hmConfig
          inputs.stylix.homeManagerModules.stylix
        ];
      };
    };
  };
}
