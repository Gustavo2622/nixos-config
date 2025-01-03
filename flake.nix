# /etc/nixos/flake.nix
{
  description = "flake for gustavo-Desktop";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    nixpkgs-stable = {
      url = "github:NixOS/nixpkgs/nixos-24.11";
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
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
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
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    nixOsConfig = ./nixos/configuration.nix;
    hmConfig = ./home/home.nix;
    nixvimLib = inputs.nixvim.lib.x86_64-linux;
    nixvim' = inputs.nixvim.legacyPackages.x86_64-linux;
    nixvimModule = {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      module = ./home/nixvim/config;
      extraSpecialArgs = {
	# Any extra args to nixvim module
      };
    };
    nvim = nixvim'.makeNixvimWithModule nixvimModule;
  in rec {
    packages =
      forAllSystems (system: (import ./pkgs nixpkgs.legacyPackages.${system})
      // { inherit nvim; });
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    overlays = import ./overlays {inherit inputs;};
    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;
    nixosConfigurations = {
      gustavo-Desktop = let 
	pkgs = import nixpkgs { inherit overlays; };
      in
      nixpkgs.lib.nixosSystem rec {
	system = "x86_64-linux";
	specialArgs = {inherit inputs outputs home-manager hmConfig;}; # Extra params to configuration
	modules = [
	  nixOsConfig

	  # make home-manager as a module of nixos
	  # so that its config will be deployed automatically
	  inputs.stylix.nixosModules.stylix
	];
      };
    };

    homeConfigurations = {
      "gustavo@Gustavo-Desktop" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          hmConfig
          inputs.stylix.homeManagerModules.stylix
        ];
      };
    };
  };
}
