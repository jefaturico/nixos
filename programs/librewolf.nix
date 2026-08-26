{ ... }:

# LibreWolf is kept as a fallback for the occasional site Brave will not do,
# and its configuration declares its extensions and nothing else — see the
# note on the profile below.
{
  home-manager.users.jefaturico =
    { inputs, pkgs, ... }:
    let
      firefoxAddons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      programs.librewolf = {
        enable = true;
        # LibreWolf 154 follows the XDG profile root, while Home Manager 26.05
        # still defaults to the legacy ~/.librewolf location.
        configPath = ".config/librewolf/librewolf";
        profilesPath = ".config/librewolf/librewolf";

        profiles.default = {
          extensions.packages = with firefoxAddons; [
            bitwarden
            vimium-c
          ];
          # Extensions and nothing else. LibreWolf pins prefers-color-scheme
          # to light through resistFingerprinting and offers no per-target
          # opt-out, so following the desktop theme in web content means
          # turning its own privacy default off. Not a trade worth making for
          # a fallback browser: the chrome still follows the session, only
          # page content stays light.
          settings = {
            # Extensions installed from the Nix store land in a scope Firefox
            # disables by default; without this the two above install
            # disabled.
            "extensions.autoDisableScopes" = 0;
          };
        };
      };
    };
}
