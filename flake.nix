{
  description = "NixOS Flake for Titan, Tethys, Prometheus, and Iapetus";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    # Keep the fast-moving Codex CLI current without moving the system off the
    # stable NixOS release.
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
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
          extraSpecialArgs = { inherit inputs; };
          users.jefaturico = import ./common/home.nix;
          backupFileExtension = "backup";
        };
      };

      mkDesktopHost =
        host:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
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
        titan = mkDesktopHost "titan";
        tethys = mkDesktopHost "tethys";
        prometheus = mkDesktopHost "prometheus";
        iapetus = mkServerHost "iapetus";

        # Temporary aliases for rebuilding machines that still have their old hostname.
        galileo = mkDesktopHost "titan";
        ekman = mkDesktopHost "tethys";
        odin = mkServerHost "iapetus";
      };
    };
}
