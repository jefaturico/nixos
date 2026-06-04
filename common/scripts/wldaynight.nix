{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        set -eu
        STATE_FILE="$HOME/.cache/wltheme_state"
        
        # Initialize defaults if not present
        DARK_THEME="Modus-Vivendi"
        LIGHT_THEME="Modus-Operandi"
        [ -f "$STATE_FILE" ] && . "$STATE_FILE"

        CUR_MODE=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme || echo "'prefer-dark'")
        
        if [ "$CUR_MODE" = "'prefer-dark'" ]; then
            # Switching to Light
            ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
            THEME="$LIGHT_THEME"
        else
            # Switching to Dark
            ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
            THEME="$DARK_THEME"
        fi

        if [ "$THEME" = "Dynamic" ]; then
            [ -f "$HOME/.wbg_path" ] && ${pkgs.wallust}/bin/wallust run -q "$(cat "$HOME/.wbg_path")"
        else
            ${pkgs.wallust}/bin/wallust theme -q "$THEME"
        fi
        
        ${pkgs.mako}/bin/makoctl reload
''
