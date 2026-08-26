{ lib, ... }:

# kitty, one independent process per window — same shape as foot before it.
# There is no shared daemon, so there is no daemon-cwd-vs-window-cwd bug to
# have: every window is its own process, started fresh from whatever
# directory launched it. That was foot's model precisely because a shared
# server reads its configuration once and never re-reads it; kitty instead
# reloads its *running* configuration on SIGUSR1, which home-manager already
# wires into `kitty.conf`'s `onChange` (`pkill -USR1 kitty`) for us, so a
# rebuild reaches every open window on its own.
#
# Light/dark has no portal subscription to piggyback on the way Ghostty's
# did, so it is done the same way foot did it: a `current-theme.conf` symlink
# — the same trick `desktop-theme` already uses for fuzzel — is included from
# `kitty.conf`, and `desktop-theme` flips the symlink and sends SIGUSR1 to
# reload it live.
let
  palette = import ../../lib/palette.nix;

  # kitty wants `colorN #rrggbb`, one setting per line; palette.nix stores
  # bare hex so each consumer can spell it its own way. Selection and cursor
  # are deliberately left unset: unset means reverse-video, which is what
  # foot did by default.
  kittyTheme = variant: ''
    background #${variant.ui.background}
    foreground #${variant.ui.text}
    ${lib.concatStrings (
      lib.imap0 (i: colour: "color${toString i} #${colour}\n") variant.ansi
    )}'';
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 16;
    };

    settings = {
      window_padding_width = 24;

      # niri's touchpad `scroll-factor` is set low so Brave — Chromium, which
      # has no scroll-speed setting of its own — is bearable. That factor hits
      # every app, so kitty multiplies it back out here. Only the touchpad
      # path is compensated: `wheel_scroll_multiplier`, which governs a real
      # mouse wheel, is left at its default since niri scales the touchpad
      # alone and a wheel never saw the reduction.
      touch_scroll_multiplier = "10.0";
    };

    extraConfig = ''
      include current-theme.conf
    '';
  };

  xdg.configFile."kitty/kitty-dark.conf".text = kittyTheme palette.dark;
  xdg.configFile."kitty/kitty-light.conf".text = kittyTheme palette.light;
}
