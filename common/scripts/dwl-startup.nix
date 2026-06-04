{ pkgs }:
''
        #!${pkgs.dash}/bin/dash

        # 1. Restore wallpaper IMMEDIATELY for perceived speed.
        [ -f "$HOME/.wbg" ] && . "$HOME/.wbg"

        # 2. Propagate environment (fast).
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

        # 3. Start session and services in the background.
        systemctl --user start --no-block graphical-session.target
        (
            systemctl --user restart xdg-desktop-portal-wlr.service
            systemctl --user restart xdg-desktop-portal.service
        ) &

        # 4. Apply theme and dark mode in the background.
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"

        (
            STATE_FILE="$HOME/.cache/wltheme_state"
            if [ -f "$STATE_FILE" ]; then
                . "$STATE_FILE"
                [ "$DARK_THEME" = "Dynamic" ] && \
                    { [ -f "$HOME/.wbg_path" ] && ${pkgs.wallust}/bin/wallust run -q "$(cat "$HOME/.wbg_path")"; } || \
                    ${pkgs.wallust}/bin/wallust theme -q "$DARK_THEME"
                ${pkgs.mako}/bin/makoctl reload
            fi
        ) &
''
