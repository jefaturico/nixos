{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  batteryCheck = pkgs.writeScriptBin "battery-check" ''
    #!${pkgs.dash}/bin/dash
    set -eu

    # Find the first battery with capacity
    BATS=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" -print)
    CHOSEN_BAT=""
    for bat in $BATS; do
        if [ -e "$bat/capacity" ]; then
            CHOSEN_BAT="$bat"
            break
        fi
    done

    [ -z "$CHOSEN_BAT" ] && exit 0

    CAPACITY=$(${pkgs.coreutils}/bin/cat "$CHOSEN_BAT/capacity")
    STATUS=$(${pkgs.coreutils}/bin/cat "$CHOSEN_BAT/status")

    if [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le 20 ]; then
        ${pkgs.libnotify}/bin/notify-send -u critical "Battery Low" "Level: ''${CAPACITY}%"
    fi
  '';
in
{
  home.packages =
    with pkgs;
    [
      # dwl-startup: Runs WITHIN dwl via the -s flag.
      # This is crucial because it executes AFTER the Wayland socket is initialized.
      (writeScriptBin "dwl-startup" ''
        #!${pkgs.dash}/bin/dash

        # 1. Propagate environment to systemd + dbus.
        # This allows XDG portals (screen sharing, file pickers) to function correctly.
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user start graphical-session.target

        # 2. Restart portal services to ensure they recognize the new environment.
        systemctl --user restart xdg-desktop-portal-wlr.service
        systemctl --user restart xdg-desktop-portal.service

        # 3. Start foot server after Wayland is up.
        ${pkgs.foot}/bin/foot --server &

        # 4. Restore last wallpaper.
        [ -f "$HOME/.wbg" ] && . "$HOME/.wbg"
      '')

      # dwl-session: Wrapper script called by the display manager (Ly).
      (writeScriptBin "dwl-session" ''
        #!${pkgs.dash}/bin/dash
        export XDG_CURRENT_DESKTOP=wlroots
        export XDG_SESSION_TYPE=wayland

        # Exec dwl with our startup script using the -s flag.
        exec dwl -s dwl-startup > /tmp/dwl.log 2>&1
      '')

      # wlsetbg: Smart wallpaper rotator with history and dynamic theming.
      # It uses wallust to generate color schemes for foot/fuzzel/etc.
      (writeScriptBin "wlsetbg" ''
        #!${pkgs.dash}/bin/dash
        # Usage: wlsetbg [-r for random]

        export LC_ALL=C
        WALL_DIR="$HOME/images/wallpapers"
        STARTUP_SCRIPT="$HOME/.wbg"
        HISTORY_FILE="$HOME/.cache/wsetbg_history"
        FILELIST_CACHE="$HOME/.cache/wsetbg_filelist"
        CURRENT_WALL=""

        mkdir -p "$HOME/.cache"

        # Extract current wallpaper from persistence script.
        [ -f "$STARTUP_SCRIPT" ] && CURRENT_WALL=$(${pkgs.gawk}/bin/awk -F'"' '/wbg/{print $2; exit}' "$STARTUP_SCRIPT" 2>/dev/null)

        get_file_list() {
            WALL_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$WALL_DIR" 2>/dev/null || echo 0)
            CACHE_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$FILELIST_CACHE" 2>/dev/null || echo 0)
            if [ "$WALL_MTIME" -gt "$CACHE_MTIME" ] || [ ! -s "$FILELIST_CACHE" ]; then
                ${pkgs.fd}/bin/fd --type f --absolute-path . "$WALL_DIR" > "$FILELIST_CACHE"
            fi
            ${pkgs.coreutils}/bin/cat "$FILELIST_CACHE"
        }

        # Selects a wallpaper that hasnt been seen recently, or a fresh one.
        get_smart_random_wallpaper() {
            get_file_list | \
            ${pkgs.gawk}/bin/awk -v hist_file="$HISTORY_FILE" -v current_wall="$CURRENT_WALL" '
            BEGIN {
                srand();
                while ((getline line < hist_file) > 0) {
                    match(line, /^[0-9]+ /);
                    if (RLENGTH > 0) {
                        ts = substr(line, 1, RLENGTH-1);
                        p = substr(line, RLENGTH+1);
                        history[p] = ts;
                    }
                }
                close(hist_file);
            }

            {
                path = $0;
                if (path == "" || path == current_wall) next;

                if (!(path in history)) {
                    unseen[u_count++] = path;
                } else {
                    seen[path] = history[path];
                    s_count++;
                }
            }

            END {
                if (u_count > 0) {
                    print unseen[int(rand() * u_count)];
                    exit 0;
                }

                if (s_count == 0) exit 1;

                PROCINFO["sorted_in"] = "@val_num_asc";
                cutoff = int(s_count * 0.2) + 1;
                if (cutoff < 1) cutoff = 1;

                k = 0;
                for (p in seen) {
                    candidates[k++] = p;
                    if (k >= cutoff) break;
                }
                print candidates[int(rand() * k)];
            }
            '
        }

        if [ "$1" = "-r" ] ; then
            FULL_PATH=$(get_smart_random_wallpaper)
            [ -z "$FULL_PATH" ] && FULL_PATH=$(get_file_list | ${pkgs.coreutils}/bin/shuf -n 1)
        else
            cd "$WALL_DIR" || exit 1
            CHOICE=$(${pkgs.fd}/bin/fd --type f | ${pkgs.fuzzel}/bin/fuzzel -d -p "Select Wallpaper: ")
            [ -z "$CHOICE" ] && exit 0
            FULL_PATH="$WALL_DIR/$CHOICE"
        fi

        [ -z "$FULL_PATH" ] || [ ! -f "$FULL_PATH" ] && exit 1

        # Apply Wallpaper immediately.
        ${pkgs.procps}/bin/pkill -x wbg || true
        ${pkgs.coreutils}/bin/sleep 0.05
        wbg "$FULL_PATH" > /dev/null 2>&1 &

        # Background theming generation with wallust.
        ${pkgs.wallust}/bin/wallust run -q "$FULL_PATH" &
        WALLUST_PID=$!

        (
            wait $WALLUST_PID 2>/dev/null
            ${pkgs.mako}/bin/makoctl reload 2>/dev/null
        ) &

        echo "$(${pkgs.coreutils}/bin/date +%s) $FULL_PATH" >> "$HISTORY_FILE"

        # Background maintenance of history file (deduplication).
        (
            if [ -f "$HISTORY_FILE" ]; then
                TMP_HIST="/tmp/wsetbg_history_$$"
                ${pkgs.gawk}/bin/awk '{data[$2] = $0} END {for (k in data) print data[k]}' "$HISTORY_FILE" \
                    | ${pkgs.coreutils}/bin/sort -n > "$TMP_HIST"
                mv "$TMP_HIST" "$HISTORY_FILE"
            fi
        ) &

        # Save current wallpaper command for restoration on next login.
        cat <<EOF > "$STARTUP_SCRIPT"
#!/usr/bin/env dash
wbg "$FULL_PATH" &
${pkgs.wallust}/bin/wallust run -s -q "$FULL_PATH"
EOF
        chmod +x "$STARTUP_SCRIPT"
        exit 0
      '')

      # wdoc-find: Specialized document picker that prioritizes recently opened files in Zathura.
      (writeScriptBin "wdoc-find" ''
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
            ${pkgs.findutils}/bin/find ~/college ~/library ~/downloads ~/workbench -maxdepth 4 -type f \( -name "*.pdf" -o -name "*.epub" \) -printf "F\t%T@\t%p\n" 2>/dev/null
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
      '')

      (writeScriptBin "fuzzel-bookmarks" ''
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

        setsid xdg-open "$URL" >/dev/null 2>&1 &
      '')

      (writeScriptBin "systeminfo" ''
        #!${pkgs.dash}/bin/dash
        TIME=$(${pkgs.coreutils}/bin/date +%H:%M)

        # Smart battery detection.
        BATS=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" -print)
        CHOSEN_BAT=""
        for bat in $BATS; do
            [ -e "$bat/capacity" ] && CHOSEN_BAT="$bat" && break
        done

        if [ -n "$CHOSEN_BAT" ]; then
          CAPACITY=$(${pkgs.coreutils}/bin/cat "$CHOSEN_BAT/capacity")
          ${pkgs.libnotify}/bin/notify-send "It's $TIME" "Battery at $CAPACITY% capacity"
        else
          ${pkgs.libnotify}/bin/notify-send "It's $TIME"
        fi
      '')

    ]
    ++ lib.optionals (osConfig.networking.hostName == "ekman") [
      batteryCheck
    ];

  systemd.user.services.battery-check = lib.mkIf (osConfig.networking.hostName == "ekman") {
    Unit.Description = "Battery Low Warning Service";
    Service = {
      Type = "oneshot";
      ExecStart = "${batteryCheck}/bin/battery-check";
    };
  };

  systemd.user.timers.battery-check = lib.mkIf (osConfig.networking.hostName == "ekman") {
    Timer = {
      OnCalendar = "*:0/5";
      Unit = "battery-check.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
