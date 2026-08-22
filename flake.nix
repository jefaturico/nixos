{
  description = "NixOS Flake for Titan, Tethys, and Iapetus";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    # Keep the fast-moving Codex CLI current without moving the system off the
    # stable NixOS release.
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tinty = {
      url = "github:tinted-theming/tinty";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tinted-schemes = {
      url = "github:tinted-theming/schemes/spec-0.11";
      flake = false;
    };
    tinted-terminal = {
      url = "github:tinted-theming/tinted-terminal";
      flake = false;
    };
    tinted-vim = {
      url = "github:tinted-theming/tinted-vim";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      # Graphical hosts additionally get Home Manager and SOPS. Headless
      # hosts deliberately evaluate neither.
      mkDesktopHost =
        host:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            (./hosts + "/${host}")
            home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
            {
              # Individual features attach their own Home Manager modules
              # through `home-manager.users.jefaturico.imports`.
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs; };
                backupFileExtension = "backup";
              };
            }
          ];
        };

      mkServerHost =
        host:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [ (./hosts + "/${host}") ];
        };
    in
    {
      nixosConfigurations = {
        titan = mkDesktopHost "titan";
        tethys = mkDesktopHost "tethys";
        iapetus = mkServerHost "iapetus";
      };
    };
}
