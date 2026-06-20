{ pkgs }:
''
          #!${pkgs.dash}/bin/dash
          set -eu
          STATE_FILE="$HOME/.cache/wltheme_state"
          TOGGLE_MODE=0

          while getopts "t" opt; do
              case "$opt" in
                  t) TOGGLE_MODE=1 ;;
                  *) exit 1 ;;
              esac
          done

          mkdir -p "$(dirname "$STATE_FILE")"
          [ -f "$STATE_FILE" ] || printf "DARK_THEME=Modus-Vivendi\nLIGHT_THEME=Modus-Operandi\n" > "$STATE_FILE"
          . "$STATE_FILE"

          # Check the current GNOME color-scheme preference via dconf.
          CUR_MODE=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme || echo "'prefer-dark'")
          case "$CUR_MODE" in
              "'prefer-light'") CURRENT_MODE="light" ;;
              *) CURRENT_MODE="dark" ;;
          esac

          DARK_THEMES="Dynamic
  Aci
  Afterglow
  Apprentice
  Argonaut
  Arthur
  Atom
  Ayu-Dark
  Ayu-Mirage
  Belafonte-Night
  Blazer
  Borland
  Breeze
  Broadcast
  Brogrammer
  Catppuccin-Frappé
  Catppuccin-Macchiato
  Catppuccin-Mocha
  Chalk
  Chalkboard
  Clone-Of-Ubuntu
  Cobalt-Neon
  Dark-Pastel
  Darkside
  Desert
  Doom-One
  Dracula
  Earthsong
  Elemental
  Elementary
  Elic
  Espresso
  Espresso-Libre
  Everforest-Dark-Hard
  Flat
  Flatland
  Github-Dark
  Grape
  Grass
  Gruvbox
  Gruvbox-Material-Dark
  Horizon-Dark
  Kanagawa-Dragon
  Kanagawa-Wave
  Modus-Vivendi
  Nord
  Oceanic-Next
  One-Dark
  Palenight
  Rosé-Pine
  Snazzy
  Solarized-Dark
  Tokyo-Night
  Tomorrow-Night"

          LIGHT_THEMES="Dynamic
  Ayu-Light
  Belafonte-Day
  Catppuccin-Latte
  Github-Light
  Gruvbox-Material-Light
  Modus-Operandi
  One-Light
  Papercolor-Light
  Rosé-Pine-Dawn
  Solarized-Light
  Tokyo-Night-Light"

          GSETTINGS_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"

          set_interface_setting() {
              KEY="$1"
              GSETTINGS_VALUE="$2"
              DCONF_VALUE="$3"

              XDG_DATA_DIRS="$GSETTINGS_DATA_DIRS''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}" \
                  ${pkgs.glib.bin}/bin/gsettings set org.gnome.desktop.interface "$KEY" "$GSETTINGS_VALUE" 2>/dev/null || \
                  ${pkgs.dconf}/bin/dconf write "/org/gnome/desktop/interface/$KEY" "$DCONF_VALUE"
          }

          apply_theme() {
              THEME="$1"
              if [ "$THEME" = "Dynamic" ]; then
                  [ -f "$HOME/.wbg_path" ] && ${pkgs.wallust}/bin/wallust run -q "$(${pkgs.coreutils}/bin/cat "$HOME/.wbg_path")"
              else
                  ${pkgs.wallust}/bin/wallust theme -q "$THEME"
              fi

              ${pkgs.systemd}/bin/systemctl --user kill --kill-whom=main --signal=SIGUSR1 foot-server.service 2>/dev/null || true
              ${pkgs.mako}/bin/makoctl reload
          }

          set_mode_preference() {
              MODE="$1"

              case "$MODE" in
                  dark)
                      COLOR_SCHEME="prefer-dark"
                      GTK_THEME="Adwaita-dark"
                      ;;
                  light)
                      COLOR_SCHEME="prefer-light"
                      GTK_THEME="Adwaita"
                      ;;
                  *) exit 1 ;;
              esac

              set_interface_setting gtk-theme "$GTK_THEME" "'$GTK_THEME'"
              set_interface_setting color-scheme "$COLOR_SCHEME" "'$COLOR_SCHEME'"
          }

          save_current_theme() {
              SELECTED_THEME="$1"
              if [ "$CURRENT_MODE" = "dark" ]; then
                  grep -q "^DARK_THEME=" "$STATE_FILE" && sed -i "s/^DARK_THEME=.*/DARK_THEME=$SELECTED_THEME/" "$STATE_FILE" || printf "DARK_THEME=$SELECTED_THEME\n" >> "$STATE_FILE"
              else
                  grep -q "^LIGHT_THEME=" "$STATE_FILE" && sed -i "s/^LIGHT_THEME=.*/LIGHT_THEME=$SELECTED_THEME/" "$STATE_FILE" || printf "LIGHT_THEME=$SELECTED_THEME\n" >> "$STATE_FILE"
              fi
          }

          switch_mode() {
              TARGET_MODE="''${1:-}"
              if [ -z "$TARGET_MODE" ]; then
                  [ "$CURRENT_MODE" = "dark" ] && TARGET_MODE="light" || TARGET_MODE="dark"
              fi

              if [ "$TARGET_MODE" = "light" ]; then
                  set_mode_preference light
                  THEME="$LIGHT_THEME"
                  MODE_LABEL="Light"
              else
                  set_mode_preference dark
                  THEME="$DARK_THEME"
                  MODE_LABEL="Dark"
              fi

              apply_theme "$THEME"
              ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:wlsettheme-mode "Mode Switched" "$MODE_LABEL: $THEME"
          }

          if [ "$TOGGLE_MODE" -eq 1 ]; then
              switch_mode
              exit 0
          fi

          if [ "$CURRENT_MODE" = "light" ]; then
              THEMES="$LIGHT_THEMES"
              PROMPT="Light Theme: "
              CURRENT_THEME="$LIGHT_THEME"
              MODE_ACTION="Switch to Dark Mode"
              MODE_ACTION_TARGET="dark"
          else
              THEMES="$DARK_THEMES"
              PROMPT="Dark Theme: "
              CURRENT_THEME="$DARK_THEME"
              MODE_ACTION="Switch to Light Mode"
              MODE_ACTION_TARGET="light"
          fi

          SELECTED=$(printf '%s\n%s\n' "$MODE_ACTION" "$THEMES" | ${pkgs.fuzzel}/bin/fuzzel -d --no-sort -p "$PROMPT(current: $CURRENT_THEME): " -w 80)
          [ -z "$SELECTED" ] && exit 0

          if [ "$SELECTED" = "$MODE_ACTION" ]; then
              switch_mode "$MODE_ACTION_TARGET"
              exit 0
          fi

          # Update the theme state file to remember the choice for this mode (LIGHT/DARK).
          save_current_theme "$SELECTED"

          # Apply
          apply_theme "$SELECTED"

          ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "Theme Applied" "$SELECTED"
''
