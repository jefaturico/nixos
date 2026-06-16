{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        set -eu
        STATE_FILE="$HOME/.cache/wltheme_state"
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

        LIGHT_THEMES="Ayu-Light
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

        if [ "$CUR_MODE" = "'prefer-light'" ]; then
            THEMES="$LIGHT_THEMES"
            PROMPT="Light Theme: "
        else
            THEMES="$DARK_THEMES"
            PROMPT="Dark Theme: "
        fi

        SELECTED=$(echo "$THEMES" | ${pkgs.fuzzel}/bin/fuzzel -d -p "$PROMPT" -w 30)
        [ -z "$SELECTED" ] && exit 0

        # Update the theme state file to remember the choice for this mode (LIGHT/DARK).
        if [ "$CUR_MODE" = "'prefer-dark'" ]; then
            grep -q "^DARK_THEME=" "$STATE_FILE" && sed -i "s/^DARK_THEME=.*/DARK_THEME=$SELECTED/" "$STATE_FILE" || printf "DARK_THEME=$SELECTED\n" >> "$STATE_FILE"
        else
            grep -q "^LIGHT_THEME=" "$STATE_FILE" && sed -i "s/^LIGHT_THEME=.*/LIGHT_THEME=$SELECTED/" "$STATE_FILE" || printf "LIGHT_THEME=$SELECTED\n" >> "$STATE_FILE"
        fi

        # Apply
        if [ "$SELECTED" = "Dynamic" ]; then
            [ -f "$HOME/.wbg_path" ] && ${pkgs.wallust}/bin/wallust run -q "$(cat "$HOME/.wbg_path")"
        else
            ${pkgs.wallust}/bin/wallust theme -q "$SELECTED"
        fi

        ${pkgs.systemd}/bin/systemctl --user kill --kill-whom=main --signal=SIGUSR1 foot-server.service 2>/dev/null || true
        ${pkgs.mako}/bin/makoctl reload

        # Update Niri colors directly in the config file
        COLOR_SH="$HOME/.cache/wallust/colors.sh"
        NIRI_CONFIG="$HOME/nixos/dots/niri/config.kdl"
        if [ -s "$COLOR_SH" ] && [ -f "$NIRI_CONFIG" ]; then
            . "$COLOR_SH"
            # Sync both border and focus-ring with color3 (matching fuzzel)
            sed -i "s/active-color \".*\" \/\/ {color3}/active-color \"$color3\" \/\/ {color3}/g" "$NIRI_CONFIG"
        fi

        ${pkgs.niri}/bin/niri msg action load-config-file
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "Theme Applied" "$SELECTED"
''
