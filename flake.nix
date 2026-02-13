{
  description = "NixOS Flake for Galileo and Ekman"; 

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11"; 
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11"; 
      inputs.nixpkgs.follows = "nixpkgs"; 
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake"; 
      inputs.nixpkgs.follows = "nixpkgs"; 
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: 
    let
      # Shared Home Manager logic to avoid duplication
      homeManagerConf = {
        home-manager = {
          useGlobalPkgs = true; 
          useUserPackages = true; 
          extraSpecialArgs = { inherit inputs; }; 
          users.jefaturico = import ./common/home.nix; 
          backupFileExtension = "backup"; 
        };
      };
    in {
      nixosConfigurations = {
        # Desktop Configuration
        galileo = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux"; 
          specialArgs = { inherit inputs; }; 
          modules = [
            ./hosts/galileo/software.nix
            home-manager.nixosModules.home-manager 
            inputs.nix-flatpak.nixosModules.nix-flatpak
            homeManagerConf

          ];
        };

        # Laptop Configuration
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
      };
    };
}
