{ ... }:

# Codex tracks unstable so it stays current without moving the system off
# the stable release.
{
  home-manager.users.jefaturico =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codex
      ];
    };
}
