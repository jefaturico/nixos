{
  inputs,
  pkgs,
  ...
}:

# LibreWolf is the browser; Brave is installed unconfigured as a fallback for
# the occasional site that will not work in anything else.
let
  firefoxAddons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  browserApplications = [
    "librewolf.desktop"
    "brave-browser.desktop"
  ];
in
{
  home = {
    packages = [ pkgs.brave ];
    sessionVariables = {
      BROWSER = "librewolf";
      DEFAULT_BROWSER = "librewolf";
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = browserApplications;
    "application/pdf" = browserApplications;
    "x-scheme-handler/http" = browserApplications;
    "x-scheme-handler/https" = browserApplications;
    "x-scheme-handler/about" = browserApplications;
    "x-scheme-handler/unknown" = browserApplications;
  };

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
      settings = {
        # Extensions installed from the Nix store land in a scope Firefox
        # disables by default; without this the two above install disabled.
        "extensions.autoDisableScopes" = 0;
      };
    };
  };
}
