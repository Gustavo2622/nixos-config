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
    # home-manager for home management : )
    home-manager = {
      url = "github:nix-community/home-manager";
      # The follows keyword in inputs is used for inheritance
      # Here inputs.nixpkgs of home-manager is kept consistent with
      # the inputs.nixpkgs of the current flake
      # to avoid problems due to version mismatch
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    nixvim = {
      url = "./home/nixvim";

      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self,
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
  in {
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system}) 
     // inputs.nixvim.packages;
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    overlays = import ./overlays { inherit inputs; };
    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;
    nixosConfigurations = {
      gustavo-Desktop = nixpkgs.lib.nixosSystem rec {
	system = "x86_64-linux";
	specialArgs = {inherit inputs outputs; }; # Extra params to configuration
	modules = [
	  nixOsConfig

	  # make home-manager as a module of nixos
	  # so that its config will be deployed automatically
	  home-manager.nixosModules.home-manager {
	    home-manager.useGlobalPkgs = true;
            home-manager.extraSpecialArgs = { inherit inputs outputs; }; # Extra params to home-manager

	    home-manager.users.gustavo = import hmConfig;
	  }
	];
      };

      gustavo-Desktop-noHome = nixpkgs.lib.nixosSystem rec {
	system = "x86_64-linux";
	specialArgs = {inherit inputs outputs;};
	modules = [
	  nixOsConfig
	];
      };
    };

    homeConfigurations = {
      "gustavo@Gustavo-Desktop" = home-manager.lib.homeManagerConfiguration {
	pkgs = nixpkgs.legacyPackages.x86_64-linux;
	extraSpecialArgs = { inherit inputs outputs; };
	modules = [
	  hmConfig
	];
      };
    };
  };
}
