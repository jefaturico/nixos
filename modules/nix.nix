{ inputs, ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    # `nix shell nixpkgs#foo` resolves to the same nixpkgs the system uses.
    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  # New, from the backburner list. `nix-locate bin/foo` finds the package
  # that has a file, typing a missing command suggests where to get it, and
  # `, foo` runs a program without installing it. The database is prebuilt
  # (nix-index-database input).
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  nixpkgs = {
    # Needed by steam, claude-code.
    config.allowUnfree = true;

    overlays = [
      # pkgs.unstable.<name> for the few packages taken from nixos-unstable.
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          inherit (prev.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        };
      })
    ];
  };
}
