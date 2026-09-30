{
  description = "coriolis: Framework 13 (AMD Ryzen AI 300), NixOS + Home Manager";

  inputs = {
    # Stable is the base. Packages that warrant it come from unstable, see
    # modules/nix.nix for the overlay and home/packages.nix for who uses it.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt nix-index database, so `nix-locate` and `,` work without
    # spending ten minutes indexing locally.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative flatpaks: list app IDs in modules/flatpak.nix.
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Secure Boot. Wired in but switched off, see hosts/coriolis/default.nix.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets, encrypted in secrets/secrets.yaml and decrypted at login. See
    # home/secrets.nix.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # One palette and one set of fonts for the whole system. See
    # modules/theme.nix.
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      disko,
      nixos-hardware,
      nix-index-database,
      nix-flatpak,
      lanzaboote,
      stylix,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "jefaturico";
    in
    {
      nixosConfigurations.coriolis = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username; };
        modules = [
          disko.nixosModules.disko
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          home-manager.nixosModules.home-manager
          nix-index-database.nixosModules.nix-index
          nix-flatpak.nixosModules.nix-flatpak
          lanzaboote.nixosModules.lanzaboote
          stylix.nixosModules.stylix

          ./hosts/coriolis

          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # Files already present in $HOME are renamed instead of making
              # the activation fail.
              backupFileExtension = "hm-bak";
              extraSpecialArgs = { inherit inputs username; };
              users.${username} = import ./home;
            };
          }
        ];
      };

      # The same system with Secure Boot and TPM unlock off. A fresh install
      # has no Secure Boot keys yet, so install.sh installs this one, and
      # setup.sh switches to the real one once the keys exist.
      nixosConfigurations.coriolis-install = self.nixosConfigurations.coriolis.extendModules {
        modules = [
          {
            coriolis.secureBoot = nixpkgs.lib.mkForce false;
            coriolis.tpmUnlock = nixpkgs.lib.mkForce false;
          }
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
