{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  batteryCheck = pkgs.writeShellScriptBin "battery-check" ''
    # battery-check.sh
    # Checks battery level and notifies if low
    set -euo pipefail

    # Find the first battery with capacity
    BATS=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" -print)
    CHOSEN_BAT=""
    for bat in $BATS; do
        if [ -e "$bat/capacity" ]; then
            CHOSEN_BAT="$bat"
            break
        fi
    done

    if [ -z "$CHOSEN_BAT" ]; then
        # No battery found
        exit 0
    fi

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
      (writeShellScriptBin "dwl-startup" ''
        # dwl-startup
        # Runs INSIDE dwl via -s flag, after WAYLAND_DISPLAY is set

        # 1. Propagate environment to systemd + dbus so portals can start
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user start graphical-session.target

        # 2. Restart portal services so they pick up the new env
        systemctl --user restart xdg-desktop-portal-wlr.service
        systemctl --user restart xdg-desktop-portal.service

        # 3. Start foot server for fast terminal spawning via footclient
        foot --server <&- &

        # 4. Run wallpaper startup script if it exists
        [ -f "$HOME/.wbg" ] && bash "$HOME/.wbg"
      '')

      (writeShellScriptBin "dwl-session" ''
        # dwl-session
        # Wraps dwl execution - display manager calls this

        # 1. Set environment before dwl starts
        export XDG_CURRENT_DESKTOP=wlroots
        export XDG_SESSION_TYPE=wayland

        # 2. Exec dwl with startup script
        #    -s runs dwl-startup AFTER the Wayland socket is ready
        exec dwl -s dwl-startup > /tmp/dwl.log 2>&1
      '')

      (writeShellScriptBin "wlsetbg" ''
        # wlsetbg - Optimized & Smart Wallpaper Setter
        # Usage: wlsetbg [-r]

        export LC_ALL=C

        WALL_DIR="$HOME/images/wallpapers"
        STARTUP_SCRIPT="$HOME/.wbg"
        HISTORY_FILE="$HOME/.cache/wsetbg_history"
        FILELIST_CACHE="$HOME/.cache/wsetbg_filelist"
        CURRENT_WALL=""

        # Ensure cache dir exists
        mkdir -p "$HOME/.cache"

        # 1. Fast retrieval of current wallpaper (single awk, no pipe)
        if [[ -f "$STARTUP_SCRIPT" ]]; then
            CURRENT_WALL=$(${pkgs.gawk}/bin/awk -F'"' '/wbg/{print $2; exit}' "$STARTUP_SCRIPT" 2>/dev/null)
        fi

        # Helper: get file list (cached by directory mtime)
        get_file_list() {
            WALL_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$WALL_DIR" 2>/dev/null || echo 0)
            CACHE_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$FILELIST_CACHE" 2>/dev/null || echo 0)
            if [[ "$WALL_MTIME" -gt "$CACHE_MTIME" ]] || [[ ! -s "$FILELIST_CACHE" ]]; then
                ${pkgs.fd}/bin/fd --type f --absolute-path . "$WALL_DIR" > "$FILELIST_CACHE"
            fi
            ${pkgs.coreutils}/bin/cat "$FILELIST_CACHE"
        }

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

        if [[ "$1" == "-r" ]]; then
            FULL_PATH=$(get_smart_random_wallpaper)
            if [[ -z "$FULL_PATH" ]]; then
                FULL_PATH=$(get_file_list | ${pkgs.coreutils}/bin/shuf -n 1)
            fi
        else
            cd "$WALL_DIR" || exit 1
            CHOICE=$(${pkgs.fd}/bin/fd --type f | ${pkgs.fuzzel}/bin/fuzzel -d -p "Select Wallpaper: ")
            [[ -z "$CHOICE" ]] && exit 0
            FULL_PATH="$WALL_DIR/$CHOICE"
        fi

        [[ -z "$FULL_PATH" || ! -f "$FULL_PATH" ]] && exit 1

        # 2. Apply Wallpaper (Instant feedback)
        # Use -x for exact match; brief wait to avoid race with new wbg
        ${pkgs.procps}/bin/pkill -x wbg || true
        sleep 0.05
        wbg "$FULL_PATH" > /dev/null 2>&1 &

        # 2b. Generate Colors with wallust (runs in background)
        # wallust reads templates from ~/.config/wallust/ and outputs to ~/.cache/wallust/
        ${pkgs.wallust}/bin/wallust run -q "$FULL_PATH" &
        WALLUST_PID=$!

        # 2c. Wait for wallust to finish, then reload mako
        (
            wait $WALLUST_PID 2>/dev/null
            ${pkgs.mako}/bin/makoctl reload 2>/dev/null
        ) &

        # 3. Update History
        echo "$(${pkgs.coreutils}/bin/date +%s) $FULL_PATH" >> "$HISTORY_FILE"

        # 4. Background Maintenance — single-pass compaction
        (
            if [ -f "$HISTORY_FILE" ]; then
                TMP_HIST="/tmp/wsetbg_history_$$"
                ${pkgs.gawk}/bin/awk '{data[$2] = $0} END {for (k in data) print data[k]}' "$HISTORY_FILE" \
                    | ${pkgs.coreutils}/bin/sort -n > "$TMP_HIST"
                mv "$TMP_HIST" "$HISTORY_FILE"
            fi
        ) &

        # 5. Persist startup script
        {
            echo "#!/usr/bin/env bash"
            echo "wbg \"$FULL_PATH\" &"
            echo "${pkgs.wallust}/bin/wallust run -s -q \"$FULL_PATH\""
        } > "$STARTUP_SCRIPT"
        chmod +x "$STARTUP_SCRIPT"

        exit 0
      '')

      (writeShellScriptBin "wdoc-find" ''
        # wdoc-find.sh - Fast Document Selector
        # Usage: wdoc-find.sh

        # 1. Use fd to search specific directories.
        # 2. Sort by Zathura history (bookmarks.sqlite) because filesystem is noatime.
        # 3. Select with fuzzel and open with zathura.
        fd --type f -e pdf -e epub --follow --absolute-path . ~/college ~/library ~/downloads ~/workbench 2>/dev/null | \
        ${pkgs.python3}/bin/python3 -c "
        import sys, sqlite3, os

        # 1. Read all input first (robustness)
        try:
            files = sys.stdin.read().splitlines()
        except Exception:
            sys.exit(0)

        if not files:
            sys.exit(0)

        # 2. Try to sort using History and Mtime
        try:
            history = {}
            db_path = os.path.expanduser('~/.local/share/zathura/bookmarks.sqlite')

            if os.path.exists(db_path):
                # uri=True allows read-only mode if supported, but standard connect is fine
                conn = sqlite3.connect(db_path)
                c = conn.cursor()
                for row in c.execute('SELECT file, time FROM fileinfo'):
                    history[row[0]] = row[1]
                conn.close()

            def get_sort_key(f):
                # Primary: Zathura access time (ISO String or \"\")
                # Secondary: Filesystem modification time (Float or 0.0)
                # Python compares tuples element-by-element safely provided types match position-wise
                z_time = history.get(f) or \"\"
                try:
                    m_time = os.path.getmtime(f)
                except OSError:
                    m_time = 0.0
                return (z_time, m_time)

            files.sort(key=get_sort_key, reverse=True)
        except Exception:
            # If DB fails or sort crashes, ignore and print original list (Graceful Degradation)
            pass

        # 3. Output
        for f in files:
            print(f)
        " | \
        fuzzel -d --no-sort -p "Select Document: " -w 70 | \
        {
            if read -r file; then
                if [ -n "$file" ]; then
                    setsid zathura "$file" >/dev/null 2>&1 &
                fi
            fi
        }
        exit 0
      '')

      (writeShellScriptBin "fuzzel-bookmarks" ''
        # fuzzel-bookmarks
        # Usage: fuzzel-bookmarks [-a|--add]

        BOOKMARK_FILE="$HOME/nixos/common/bookmarks.txt"
        mkdir -p "$(dirname "$BOOKMARK_FILE")"
        [ ! -f "$BOOKMARK_FILE" ] && touch "$BOOKMARK_FILE"

        # Helper for input using fuzzel dmenu mode
        # Hack: We echo an empty string to ensure fuzzel opens.
        # Users must type and likely need to press Shift+Enter or just Enter dependent on config for "custom input"
        # But since we can't guarantee 'print-no-match', using footclient is safer?
        # User insisted on fuzzel: we try to use it as a selector for "Cancel" or just input.
        get_input() {
            # Prompt is passed as $1
            # We use a trick: If we pass no lines, fuzzel shows nothing.
            # But many configs accept unknown input.
            # If not, we might need a fallback.
            echo "" | fuzzel -d -p "$1" -w 40 --lines 0 | head -n1
        }

        if [[ "$1" == "-a" || "$1" == "--add" ]]; then
            URL=$(get_input "Enter URL: ")
            [[ -z "$URL" ]] && exit 0

            NAME=$(get_input "Enter Name: ")
            [[ -z "$NAME" ]] && NAME="$URL"

            echo "$NAME $URL" >> "$BOOKMARK_FILE"
            notify-send "Bookmark Added" "$NAME"
            exit 0
        fi

        # Normal Mode: Select & Open

        # 1. Read Bookmarks & Select
        # Format: "Name URL"
        if [ ! -s "$BOOKMARK_FILE" ]; then
            # Populate with defaults if empty
            cat <<EOF > "$BOOKMARK_FILE"
        GitHub https://github.com
        NixOS-Search https://search.nixos.org/packages
        YouTube https://youtube.com
        EOF
        fi

        # Display ONLY the name (everything except the last field)
        # We assume the name is unique enough for lookup.
        # awk logic: iterate fields 1 to NF-1, then print newline
        SELECTED_NAME=$(awk '{for(i=1;i<NF;i++) printf "%s%s", $i, (i==NF-1?"":" "); print ""}' "$BOOKMARK_FILE" | fuzzel -d -p "Bookmarks: " -w 50)

        if [ -z "$SELECTED_NAME" ]; then
            exit 0
        fi

        # 2. Extract URL
        # We grep the line starting with the selected name to find the full line, then extract the last field.
        # This handles spaces in names correctly if name is unique.
        # If duplicates exist, it picks the first one.
        URL=$(grep -F -m 1 "$SELECTED_NAME " "$BOOKMARK_FILE" | awk '{print $NF}')

        if [ -z "$URL" ]; then
            # Fallback: Search DuckDuckGo
            # If no URL found (meaning user typed something new), treat as search query.
            URL="https://duckduckgo.com/?q=$SELECTED_NAME"
        fi

        setsid xdg-open "$URL" >/dev/null 2>&1 &

        # 3. Simple Focus: Switch to Workspace 1 (Browser)
        # dwl: We assume browser is on Tag 10.
        # Since we can't switch/tag from script easily, we just ensure browser is launched.
        # User might need to switch to Tag 10 manually if it's already running elsewere.
        # Or we could use wlrctl? No, wlrctl can't switch dwl tags yet (protocol limitation).

      '')

      (writeShellScriptBin "systeminfo" ''
        TIME=$(${pkgs.coreutils}/bin/date +%H:%M)

        # Find all batteries
        BATS=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" -print)

        CHOSEN_BAT=""
        for bat in $BATS; do
            if [ -e "$bat/capacity" ]; then
                CHOSEN_BAT="$bat"
                break
            fi
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
