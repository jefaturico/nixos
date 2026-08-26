{ config, pkgs, ... }:

# The session's own user-level pieces: the live-reloaded niri configuration,
# the launcher, the notification daemon, the wallpaper, and idle handling.
let
  palette = import ../theme/palette.nix;

  desktopWallpaper = pkgs.writeShellApplication {
    name = "desktop-wallpaper";
    runtimeInputs = [ pkgs.wbg ];
    text = ''
      set -euo pipefail

      dir="''${XDG_PICTURES_DIR:-$HOME/pictures}/wallpapers"
      shopt -s nullglob
      images=("$dir"/*)
      shopt -u nullglob

      if [ "''${#images[@]}" -ne 1 ]; then
        echo "desktop-wallpaper: expected exactly one image in $dir, found ''${#images[@]}" >&2
        exit 1
      fi

      exec wbg "''${images[0]}"
    '';
  };
in
{
  # fuzzel has no include directive and no reload, so both configurations
  # are generated in full and `desktop-theme` points ~/.config/fuzzel.ini at
  # one of them. Every launch is a fresh process, so that is enough.
  programs.fuzzel.enable = true;

  xdg.configFile =
    let
      fuzzelConfig = colors: ''
        [main]
        font=JetBrainsMono Nerd Font:size=12
        prompt="λ "
        icons-enabled=no

        [colors]
        background=${colors.background}ff
        text=${colors.text}ff
        prompt=${colors.text}ff
        placeholder=${colors.dim}ff
        input=${colors.text}ff
        match=${colors.accent}ff
        selection=${colors.selection}ff
        selection-text=${colors.selectionText}ff
        selection-match=${colors.accent}ff
        border=${colors.border}ff

        [border]
        width=2
        radius=5
      '';
    in
    {
      # Checked in beside this module and linked out of the Nix store, so
      # edits apply through niri's live reload without a rebuild.
      "niri/config.kdl".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/features/compositor/config.kdl";

      # Monokai Pro, the same palette the terminal uses; the `ff` appended above makes
      # every colour fully opaque, so the launcher never shows what is behind
      # it. `desktop-theme` swaps the symlink between these two.
      "fuzzel/fuzzel-dark.ini".text = fuzzelConfig palette.dark.ui;
      "fuzzel/fuzzel-light.ini".text = fuzzelConfig palette.light.ui;
    };

  # Started on demand through D-Bus when the first notification arrives.
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

  services.swayidle = {
    enable = true;
    # Hold the sleep inhibitor until the locker has actually mapped its
    # surface, so the screen is never briefly visible on resume.
    extraArgs = [ "-w" ];
    timeouts = [
      {
        timeout = 600;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
    events = {
      before-sleep = "${pkgs.waylock}/bin/waylock -fork-on-lock";
      lock = "${pkgs.waylock}/bin/waylock -fork-on-lock";
    };
  };

  # wbg takes a single image path, so the "only file in the directory" rule is
  # resolved at start time rather than baked into the service. The service is
  # part of the graphical session: it starts with it and dies with it.
  systemd.user.services.wbg = {
    Unit = {
      Description = "Wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${desktopWallpaper}/bin/desktop-wallpaper";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
