{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        DB_PATH="$HOME/.local/share/zathura/bookmarks.sqlite"
        HIST_CACHE="/tmp/wdoc_hist_$$"

        # 1. Pull most recently accessed files from Zathuras internal database.
        if [ -f "$DB_PATH" ]; then
            ${pkgs.sqlite}/bin/sqlite3 -separator '' "$DB_PATH" "SELECT file, time FROM fileinfo" > "$HIST_CACHE" 2>/dev/null
        fi

        # 2. Join Zathura history with filesystem search, then sort by 'relevance'.
        MAP_CACHE="/tmp/wdoc_map_$$"
        {
            [ -f "$HIST_CACHE" ] && ${pkgs.gawk}/bin/awk -F'' '{print "H\t" $2 "\t" $1}' "$HIST_CACHE"
            ${pkgs.findutils}/bin/find -L ~/college ~/library ~/downloads -maxdepth 4 -type f \( -name "*.pdf" -o -name "*.epub" \) -printf "F\t%T@\t%p\n" 2>/dev/null
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
        ' | ${pkgs.coreutils}/bin/sort -t'	' -rn | ${pkgs.coreutils}/bin/cut -f3- > "$MAP_CACHE"

        # 3. Present cleanly sorted list to user via Fuzzel.
        SELECTED=$(${pkgs.coreutils}/bin/cut -f1 "$MAP_CACHE" | \
                   ${pkgs.fuzzel}/bin/fuzzel -d --no-sort -p "Select Document: " -w 70)

        if [ -n "$SELECTED" ]; then
            FILE=$(${pkgs.gawk}/bin/awk -F'\t' -v s="$SELECTED" '$1 == s { print $2; exit }' "$MAP_CACHE")
            if [ -f "$FILE" ]; then
                exec setsid ${pkgs.zathura}/bin/zathura "$FILE" >/dev/null 2>&1
            fi
        fi
        rm -f "$MAP_CACHE" "$HIST_CACHE"
''
