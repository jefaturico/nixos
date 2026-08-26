{ ... }:

# The Nix daemon itself: flakes, garbage collection, deduplication.
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Deduplicate out of band. `auto-optimise-store` hashes every newly built
    # path inline, which lengthens each rebuild instead of the weekly job.
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-generations +5";
    };
  };
}
