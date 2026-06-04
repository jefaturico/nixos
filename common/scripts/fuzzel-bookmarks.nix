{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        BOOKMARK_FILE="$HOME/nixos/common/bookmarks.txt"
        mkdir -p "$(dirname "$BOOKMARK_FILE")"
        [ ! -f "$BOOKMARK_FILE" ] && touch "$BOOKMARK_FILE"

        get_input() {
            echo "" | fuzzel -d -p "$1" -w 40 --lines 0 | head -n1
        }

        if [ "$1" = "-a" ] || [ "$1" = "--add" ]; then
            URL=$(get_input "Enter URL: ")
            [ -z "$URL" ] && exit 0
            NAME=$(get_input "Enter Name: ")
            [ -z "$NAME" ] && NAME="$URL"
            echo "$NAME $URL" >> "$BOOKMARK_FILE"
            notify-send "Bookmark Added" "$NAME"
            exit 0
        fi

        if [ ! -s "$BOOKMARK_FILE" ]; then
            cat <<EOF > "$BOOKMARK_FILE"
GitHub https://github.com
NixOS-Search https://search.nixos.org/packages
YouTube https://youtube.com
EOF
        fi

        SELECTED_NAME=$(awk '{for(i=1;i<NF;i++) printf "%s%s", $i, (i==NF-1?"":" "); print ""}' "$BOOKMARK_FILE" | fuzzel -d -p "Bookmarks: " -w 50)
        [ -z "$SELECTED_NAME" ] && exit 0
        URL=$(grep -F -m 1 "$SELECTED_NAME " "$BOOKMARK_FILE" | awk '{print $NF}')

        if [ -z "$URL" ]; then
            URL="https://duckduckgo.com/?q=$SELECTED_NAME"
        fi

        riverctl set-focused-tags $((1 << 9))

        setsid xdg-open "$URL" >/dev/null 2>&1 &
''
