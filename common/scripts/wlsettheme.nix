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

          save_current_theme() {
              SELECTED_THEME="$1"
              if [ "$CUR_MODE" = "'prefer-dark'" ]; then
                  grep -q "^DARK_THEME=" "$STATE_FILE" && sed -i "s/^DARK_THEME=.*/DARK_THEME=$SELECTED_THEME/" "$STATE_FILE" || printf "DARK_THEME=$SELECTED_THEME\n" >> "$STATE_FILE"
              else
                  grep -q "^LIGHT_THEME=" "$STATE_FILE" && sed -i "s/^LIGHT_THEME=.*/LIGHT_THEME=$SELECTED_THEME/" "$STATE_FILE" || printf "LIGHT_THEME=$SELECTED_THEME\n" >> "$STATE_FILE"
              fi
          }

          switch_mode() {
              if [ "$CUR_MODE" = "'prefer-dark'" ]; then
                  ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
                  THEME="$LIGHT_THEME"
                  MODE_LABEL="Light"
              else
                  ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
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

          if [ "$CUR_MODE" = "'prefer-light'" ]; then
              THEMES="$LIGHT_THEMES"
              PROMPT="Light Theme: "
              CURRENT_THEME="$LIGHT_THEME"
              MODE_ACTION="Switch to Dark Mode"
          else
              THEMES="$DARK_THEMES"
              PROMPT="Dark Theme: "
              CURRENT_THEME="$DARK_THEME"
              MODE_ACTION="Switch to Light Mode"
          fi

          SELECTED=$(printf '%s\n%s\n' "$MODE_ACTION" "$THEMES" | ${pkgs.fuzzel}/bin/fuzzel -d --no-sort -p "$PROMPT(current: $CURRENT_THEME): " -w 80)
          [ -z "$SELECTED" ] && exit 0

          if [ "$SELECTED" = "$MODE_ACTION" ]; then
              switch_mode
              exit 0
          fi

          # Update the theme state file to remember the choice for this mode (LIGHT/DARK).
          save_current_theme "$SELECTED"

          # Apply
          apply_theme "$SELECTED"

          ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "Theme Applied" "$SELECTED"
''
