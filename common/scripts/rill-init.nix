{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  set -eu

  # 1. Ensure portals and systemd are aware of the Wayland environment
  ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all
  ${pkgs.systemd}/bin/systemctl --user import-environment

  # 1.1 Restart portals and start graphical-session (critical fix from working baseline)
  ${pkgs.systemd}/bin/systemctl --user start --no-block graphical-session.target
  ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal-wlr.service || true
  ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal.service || true

  # 2. Force dark mode at startup
  ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"

  # 3. Initialize terminal and app colors via wallust
  STATE_FILE="$HOME/.cache/wltheme_state"
  if [ -f "$STATE_FILE" ]; then
      . "$STATE_FILE"
      ${pkgs.wallust}/bin/wallust theme -q "$DARK_THEME"
  else
      ${pkgs.wallust}/bin/wallust theme -q "Modus-Vivendi"
  fi

  # 4. Start background services
  ${pkgs.mako}/bin/mako &
''
