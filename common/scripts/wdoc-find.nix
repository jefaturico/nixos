{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        DB_PATH="$HOME/.local/share/zathura/bookmarks.sqlite"
        CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/wdoc-find"
        MAP_CACHE="$CACHE_DIR/map.tsv"
        WATCH_ROOTS="$HOME/documents $HOME/downloads $HOME/projects"
        WATCH_REGEX='.*\.[pP][dD][fF]$|.*\.[eE][pP][uU][bB]$'

        refresh_cache() {
            mkdir -p "$CACHE_DIR"
            HIST_CACHE="$CACHE_DIR/hist.$$"
            TMP_CACHE="$CACHE_DIR/map.$$.tmp"

            # Pull most recently accessed files from Zathuras internal database.
            if [ -f "$DB_PATH" ]; then
                ${pkgs.sqlite}/bin/sqlite3 -separator '' "$DB_PATH" "SELECT file, time FROM fileinfo" > "$HIST_CACHE" 2>/dev/null
            else
                : > "$HIST_CACHE"
            fi

            {
                ${pkgs.gawk}/bin/awk -F'' '{print "H\t" $2 "\t" $1}' "$HIST_CACHE"
                ${pkgs.findutils}/bin/find -L "$HOME/documents" "$HOME/downloads" "$HOME/projects" -maxdepth 4 -type f \( -name "*.pdf" -o -name "*.epub" \) -printf "F\t%T@\t%p\n" 2>/dev/null
            } | ${pkgs.gawk}/bin/awk -F'\t' '
                /^H/ {
                    hist[$3] = $2
                    next
                }
                /^F/ {
                    t = $2
                    path = $3
                    z_time = hist[path] ? hist[path] : 0
                    n = split(path, parts, "/")
                    bname = parts[n]
                    print z_time "\t" t "\t" bname "\t" path
                }
            ' | ${pkgs.coreutils}/bin/sort -t'	' -rn | ${pkgs.coreutils}/bin/cut -f3- > "$TMP_CACHE"

            mv "$TMP_CACHE" "$MAP_CACHE"
            rm -f "$HIST_CACHE"
        }

        watch_cache() {
            refresh_cache

            while :; do
                WATCH_ARGS=""
                for root in $WATCH_ROOTS; do
                    [ -d "$root" ] && WATCH_ARGS="$WATCH_ARGS $root"
                done

                if [ -z "$WATCH_ARGS" ]; then
                    sleep 30
                    continue
                fi

                ${pkgs.inotify-tools}/bin/inotifywait -q -m -r \
                    --include "$WATCH_REGEX" \
                    --format '%w%f' \
                    -e close_write -e moved_to -e moved_from -e create -e delete \
                    $WATCH_ARGS 2>/dev/null | while IFS= read -r _changed_path; do
                    now=$(${pkgs.coreutils}/bin/date +%s)
                    if [ -n "''${LAST_REFRESH:-}" ] && [ $((now - LAST_REFRESH)) -lt 2 ]; then
                        continue
                    fi

                    ${pkgs.coreutils}/bin/sleep 1
                    refresh_cache
                    LAST_REFRESH=$(${pkgs.coreutils}/bin/date +%s)
                done

                sleep 2
            done
        }

        case "''${1:-}" in
            --refresh)
                refresh_cache
                exit 0
                ;;
            --watch)
                watch_cache
                ;;
        esac

        if [ ! -s "$MAP_CACHE" ]; then
            refresh_cache
        fi

        FILE=$(${pkgs.fuzzel}/bin/fuzzel -d --no-sort --with-nth=1 --match-nth=1 --accept-nth=2 -p "Select Document: " -w 70 < "$MAP_CACHE")

        if [ -n "$FILE" ] && [ -f "$FILE" ]; then
            exec setsid ${pkgs.zathura}/bin/zathura "$FILE" >/dev/null 2>&1
        fi
''
