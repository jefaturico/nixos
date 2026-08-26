{ ... }:

# The notification daemon, started on demand through D-Bus when the first
# notification arrives.
{
  home-manager.users.jefaturico =
    { ... }:
    let
      palette = import ../lib/palette.nix;
    in
    {
      services.mako = {
        enable = true;
        settings = {
          font = "JetBrainsMono Nerd Font 12";
          # Not cosmetic: mako's own default is 0, which means notifications never
          # expire and the volume popups would stack up forever.
          default-timeout = 5000;
          anchor = "top-center";
          border-radius = 5;

          # mako keys its layer-shell surfaces on (output, anchor, layer), so two
          # notifications that share an anchor but not a layer become two separate
          # surfaces drawn at the same spot: the `overlay` one covers the `top` one
          # instead of stacking under it. Everything therefore lives on one layer.
          # `overlay` is the one to pick, because the alerts that matter most --
          # critical urgency and the on-demand system-info readout -- are the ones
          # that have to survive a fullscreen window.
          layer = "overlay";

          # The globals are the dark theme; `desktop-theme` selects the light
          # override with `makoctl mode`, which takes effect on notifications
          # already on screen without rewriting or reloading anything. Both come
          # from the shared Monokai Pro palette, so notifications match the
          # terminal and fuzzel.
          background-color = "#${palette.dark.ui.background}";
          text-color = "#${palette.dark.ui.text}";
          border-color = "#${palette.dark.ui.border}";
          progress-color = "over #${palette.dark.ui.selection}";

          # Criteria are applied in file order and Home Manager emits them
          # alphabetically, so this one lands after `mode=light`; keep it to
          # options the light theme does not set.
          "urgency=critical" = {
            # Never expires; dismissed only by hand.
            default-timeout = 0;
            anchor = "center";
          };

          # The appointment popup carries a countdown and a description, so it
          # gets the same room the system-info readout does rather than being
          # clipped by mako's 300x100 default.
          "app-name=calcurse" = {
            width = 360;
            height = 200;
          };

          # The system-info popup is a full sentence rather than a one-line
          # readout, so it gets room to render: mako's 300x100 default clips the
          # text. `height` is a maximum and the box still shrinks to its content,
          # so only the width changes what is seen.
          "app-name=systeminfo" = {
            width = 360;
            height = 200;
          };

          "mode=light" = {
            background-color = "#${palette.light.ui.background}";
            text-color = "#${palette.light.ui.text}";
            border-color = "#${palette.light.ui.border}";
            progress-color = "over #${palette.light.ui.selection}";
          };
        };
      };
    };
}
