{
  description = "NixOS Flake for Galileo, Ekman, and Odin";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

      mkDesktopHost =
        host:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (./hosts + "/${host}/software.nix")
            home-manager.nixosModules.home-manager
            inputs.nix-flatpak.nixosModules.nix-flatpak
            inputs.sops-nix.nixosModules.sops
            homeManagerConf
          ];
        };

      mkServerHost =
        host:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (./hosts + "/${host}/software.nix")
          ];
        };
    in
    {
      nixosConfigurations = {
        galileo = mkDesktopHost "galileo";
        ekman = mkDesktopHost "ekman";
        odin = mkServerHost "odin";
      };
    };
}
