{
  description = "NixOS Flake for Galileo, Ekman, and Coriolis"; 

  # Inputs define where we pull our packages and modules from.
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11"; 
      # Ensures home-manager uses the same nixpkgs version as the system.
      inputs.nixpkgs.follows = "nixpkgs"; 
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  # Outputs define the final system configurations.
  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: 
    let
      # Import unstable nixpkgs for cherry-picking newer packages.
      pkgs-unstable = import nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      # Shared Home Manager setup across all hosts to avoid repetition.
      homeManagerConf = {
        home-manager = {
          useGlobalPkgs = true; 
          useUserPackages = true; 
          extraSpecialArgs = { inherit inputs pkgs-unstable; }; 
          users.jefaturico = import ./common/home.nix; 
          backupFileExtension = "backup"; 
        };
      };
    in {
      # nixosConfigurations is the standard output for full system builds.
      nixosConfigurations = {
        # Main Desktop (Galileo)
        galileo = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux"; 
          # specialArgs passes 'inputs' to all modules, allowing them to reference other flake inputs.
          specialArgs = { inherit inputs; }; 
          modules = [
            ./hosts/galileo/software.nix
            home-manager.nixosModules.home-manager 
            inputs.nix-flatpak.nixosModules.nix-flatpak
            homeManagerConf
          ];
        };

        # Laptop (Ekman)
        ekman = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux"; 
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/ekman/software.nix
            home-manager.nixosModules.home-manager
            inputs.nix-flatpak.nixosModules.nix-flatpak
            homeManagerConf
          ];
        };

        # ThinkPad X201i (Coriolis)
        coriolis = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/coriolis/software.nix
            home-manager.nixosModules.home-manager
            inputs.nix-flatpak.nixosModules.nix-flatpak
            homeManagerConf
          ];
        };
      };
    };
}
