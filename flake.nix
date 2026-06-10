{
  description = "NixOS Flake for Galileo, Ekman, and Coriolis";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      homeManagerConf = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.jefaturico = import ./common/home.nix;
          backupFileExtension = "backup";
        };
      };
    in {
      nixosConfigurations = {
        galileo = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/galileo/software.nix
            home-manager.nixosModules.home-manager
            inputs.nix-flatpak.nixosModules.nix-flatpak
            homeManagerConf
          ];
        };

        ekman = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
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
