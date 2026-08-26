{ ... }:

# Brave is the browser: the default handler for links and HTML, with
# LibreWolf's desktop entry kept as the fallback in each association.
{
  home-manager.users.jefaturico =
    { pkgs, ... }:
    let
      # Opening a link with xdg-open hands the URL to an already running
      # browser, which draws no new window for niri to focus: the tab appears
      # on whatever workspace the browser lives on and the compositor never
      # hears about it. This wrapper does the focusing itself, right after the
      # handoff. It stays inline rather than in scripts/: the store path to
      # xdg-utils' real xdg-open is what keeps a binary named xdg-open from
      # calling itself.
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
    };
}
