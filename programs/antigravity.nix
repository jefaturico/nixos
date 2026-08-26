{ ... }:

# Google's Antigravity CLI, packaged by the antigravity-nix flake.
{
  home-manager.users.jefaturico =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
      ];
    };
}
