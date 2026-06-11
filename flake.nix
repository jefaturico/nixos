{
  description = "NixOS Flake for Galileo and Ekman";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      homeManagerConf = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.jefaturico = import ./common/home.nix;
          backupFileExtension = "backup";
        };
      };

      mkHost = host:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (./hosts + "/${host}/software.nix")
            home-manager.nixosModules.home-manager
            inputs.nix-flatpak.nixosModules.nix-flatpak
            homeManagerConf
          ];
        };
    in
    {
      nixosConfigurations = {
        galileo = mkHost "galileo";
        ekman = mkHost "ekman";
      };
    };
}
