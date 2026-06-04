{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        set -eu
        export LC_ALL=C

        WALL_DIR="$HOME/images/wallpapers"
        STARTUP_SCRIPT="$HOME/.wbg"
        PATH_STORAGE="$HOME/.wbg_path"
        HISTORY_FILE="$HOME/.cache/wlsetbg_history"
        FILELIST_CACHE="$HOME/.cache/wlsetbg_filelist"
        STATE_FILE="$HOME/.cache/wltheme_state"

        RANDOM_MODE=0
        mkdir -p "$HOME/.cache"
        [ -d "$WALL_DIR" ] || exit 1

        while getopts "r" opt; do
            case "$opt" in
                r) RANDOM_MODE=1 ;;
                *) exit 1 ;;
            esac
        done

        # Extract current wallpaper
        CURRENT_WALL=""
        [ -f "$PATH_STORAGE" ] && CURRENT_WALL=$(cat "$PATH_STORAGE")

        get_file_list() {
            WALL_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$WALL_DIR" 2>/dev/null || echo 0)
            CACHE_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$FILELIST_CACHE" 2>/dev/null || echo 0)
            if [ "$WALL_MTIME" -gt "$CACHE_MTIME" ] || [ ! -s "$FILELIST_CACHE" ]; then
                ${pkgs.fd}/bin/fd --type f --absolute-path . "$WALL_DIR" > "$FILELIST_CACHE"
            fi
            cat "$FILELIST_CACHE"
        }

        if [ "$RANDOM_MODE" -eq 1 ]; then
            FULL_PATH=$(get_file_list | ${pkgs.coreutils}/bin/shuf -n 1)
        else
            CHOICE=$(${pkgs.fd}/bin/fd --type f --base-directory "$WALL_DIR" | ${pkgs.fuzzel}/bin/fuzzel -d -p "Select Wallpaper: ")
            [ -z "$CHOICE" ] && exit 0
            FULL_PATH="$WALL_DIR/$CHOICE"
        fi

        [ -f "$FULL_PATH" ] || exit 1

        # Apply Wallpaper
        pkill -x wbg || true
        wbg "$FULL_PATH" > /dev/null 2>&1 &
        echo "$FULL_PATH" > "$PATH_STORAGE"

        # Update Dynamic theme if active
        if [ -f "$STATE_FILE" ]; then
            . "$STATE_FILE"
            CUR_MODE=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme || echo "'prefer-dark'")
            [ "$CUR_MODE" = "'prefer-dark'" ] && THEME="$DARK_THEME" || THEME="$LIGHT_THEME"
            if [ "$THEME" = "Dynamic" ]; then
                ${pkgs.wallust}/bin/wallust run -q "$FULL_PATH" && ${pkgs.mako}/bin/makoctl reload &
            fi
        fi

        # Save startup script
        echo "wbg \"$FULL_PATH\" &" > "$STARTUP_SCRIPT"
        chmod +x "$STARTUP_SCRIPT"
''
