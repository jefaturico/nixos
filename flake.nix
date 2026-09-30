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

    # ---- Backburner -------------------------------------------------------
    # Not wired in yet. Each one has a stub in modules/backburner.nix that
    # explains what enabling it involves.
    #
    # stylix = {
    #   url = "github:nix-community/stylix/release-26.05";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # agenix = {
    #   url = "github:ryantm/agenix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      disko,
      nixos-hardware,
      nix-index-database,
      nix-flatpak,
      lanzaboote,
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

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
