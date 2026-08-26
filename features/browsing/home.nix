{
  inputs,
  pkgs,
  ...
}:

# Brave is the browser. LibreWolf is kept as a fallback for the occasional
# site Brave will not do, and its configuration declares its extensions and
# nothing else — see the note on the profile below.
let
  # Opening a link with xdg-open hands the URL to an already running browser,
  # which draws no new window for niri to focus: the tab appears on whatever
  # workspace the browser lives on and the compositor never hears about it.
  # This wrapper does the focusing itself, right after the handoff.
  xdgOpenAndFocus = pkgs.writeShellScriptBin "xdg-open" ''
    ${pkgs.xdg-utils}/bin/xdg-open "$@"
    status=$?

    case "$1" in
      http://* | https://* | about:*)
        id=$(${pkgs.niri}/bin/niri msg -j windows \
          | ${pkgs.jq}/bin/jq '[.[] | select(.app_id != null and (.app_id | test("brave|librewolf|firefox"; "i")))] | first | .id // empty')
        [ -n "$id" ] && ${pkgs.niri}/bin/niri msg action focus-window --id "$id"
        ;;
    esac

    exit $status
  '';

  firefoxAddons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  browserApplications = [
    "brave-browser.desktop"
    "librewolf.desktop"
  ];
in
{
  home = {
    # The wrapper must come first so it shadows xdg-utils' own xdg-open.
    packages = [
      xdgOpenAndFocus
      pkgs.brave
    ];
    sessionVariables = {
      BROWSER = "brave";
      DEFAULT_BROWSER = "brave";
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = browserApplications;
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
      # Extensions and nothing else. LibreWolf pins prefers-color-scheme to
      # light through resistFingerprinting and offers no per-target opt-out,
      # so following the desktop theme in web content means turning its own
      # privacy default off. Not a trade worth making for a fallback browser:
      # the chrome still follows the session, only page content stays light.
      settings = {
        # Extensions installed from the Nix store land in a scope Firefox
        # disables by default; without this the two above install disabled.
        "extensions.autoDisableScopes" = 0;
      };
    };
  };
}
