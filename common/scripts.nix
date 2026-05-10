{
  pkgs,
  ...
}:

let
  batteryCheck = pkgs.writeScriptBin "battery-check" ''
    #!${pkgs.dash}/bin/dash
    set -eu

    # Find AC and Battery paths once
    AC_PATH=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "AC*" -o -name "ADP*" -o -name "ACAD" | ${pkgs.coreutils}/bin/head -n1)
    BAT_PATH=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" | ${pkgs.coreutils}/bin/head -n1)

    # If no battery exists, just exit (desktops)
    [ -z "$BAT_PATH" ] && exit 0

    LAST_AC=""
    LOW_NOTIFIED=0
    CRIT_NOTIFIED=0

    # Notification tags
    STATUS_TAG="string:x-canonical-private-synchronous:status"
    BATTERY_TAG="string:x-canonical-private-synchronous:battery-low"

    while true; do
        # 1. Read capacity and status using shell builtins to avoid forks
        read -r CAPACITY < "$BAT_PATH/capacity"
        
        # Check AC status (if available)
        if [ -n "$AC_PATH" ]; then
            read -r AC_ONLINE < "$AC_PATH/online"
        else
            # Fallback to battery status if no AC path found
            read -r STATUS < "$BAT_PATH/status"
            [ "$STATUS" = "Charging" ] && AC_ONLINE=1 || AC_ONLINE=0
        fi

        # 2. Handle AC state changes (Plug/Unplug)
        if [ "$AC_ONLINE" != "$LAST_AC" ]; then
            if [ "$AC_ONLINE" = "1" ]; then
                # Plugged in: Notify Charging + ALWAYS dismiss battery alerts
                [ -n "$LAST_AC" ] && ${pkgs.libnotify}/bin/notify-send -h "$STATUS_TAG" -i battery-charging "Charging" "Battery is now charging"
                ${pkgs.libnotify}/bin/notify-send -h "$BATTERY_TAG" " " -t 1 # Quick dismiss
                LOW_NOTIFIED=0
                CRIT_NOTIFIED=0
            fi
            LAST_AC="$AC_ONLINE"
        fi

        # 3. Handle Low Battery Thresholds (only if discharging)
        if [ "$AC_ONLINE" = "0" ]; then
            if [ "$CAPACITY" -le 10 ]; then
                if [ "$CRIT_NOTIFIED" -eq 0 ]; then
                    ${pkgs.libnotify}/bin/notify-send -u critical -h "$BATTERY_TAG" -i battery-empty "Battery Critical" "Level: ''${CAPACITY}%"
                    CRIT_NOTIFIED=1
                fi
            elif [ "$CAPACITY" -le 15 ]; then
                if [ "$LOW_NOTIFIED" -lt 2 ]; then
                    ${pkgs.libnotify}/bin/notify-send -u normal -h "$BATTERY_TAG" -i battery-low "Battery Low" "Level: ''${CAPACITY}%"
                    LOW_NOTIFIED=2
                fi
            elif [ "$CAPACITY" -le 20 ]; then
                if [ "$LOW_NOTIFIED" -lt 1 ]; then
                    ${pkgs.libnotify}/bin/notify-send -u normal -h "$BATTERY_TAG" -i battery-low "Battery Low" "Level: ''${CAPACITY}%"
                    LOW_NOTIFIED=1
                fi
            else
                # Reset notifications if battery goes above 20%
                LOW_NOTIFIED=0
                CRIT_NOTIFIED=0
            fi
        fi

        ${pkgs.coreutils}/bin/sleep 1
    done
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
      '')

      # dwl-session: Wrapper script called by the display manager (Ly).
      (writeScriptBin "dwl-session" ''
        #!${pkgs.dash}/bin/dash
        export XDG_CURRENT_DESKTOP=wlroots
        export XDG_SESSION_TYPE=wayland

        # Exec dwl with our startup script using the -s flag.
        exec dwl -s dwl-startup > /tmp/dwl.log 2>&1
      '')

      # wlsetbg: Pure wallpaper manager (no theme logic).
      (writeScriptBin "wlsetbg" ''
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
      '')

      # wlsettheme: Curated theme picker with mode-aware filtering.
      (writeScriptBin "wlsettheme" ''
        #!${pkgs.dash}/bin/dash
        set -eu
        STATE_FILE="$HOME/.cache/wltheme_state"
        mkdir -p "$(dirname "$STATE_FILE")"
        [ -f "$STATE_FILE" ] || printf "DARK_THEME=Modus-Vivendi\nLIGHT_THEME=Modus-Operandi\n" > "$STATE_FILE"
        . "$STATE_FILE"

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

        # Update state persistence carefully
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
        
        ${pkgs.mako}/bin/makoctl reload
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "Theme Applied" "$SELECTED"
      '')

      # wldaynight: Toggle between light/dark, remembering specifically chosen themes.
      (writeScriptBin "wldaynight" ''
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
            ${pkgs.findutils}/bin/find -L ~/college ~/library ~/downloads ~/workbench -maxdepth 4 -type f \( -name "*.pdf" -o -name "*.epub" \) -printf "F\t%T@\t%p\n" 2>/dev/null
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

        ${pkgs.wlrctl}/bin/wlrctl keyboard type "0" SUPER

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
          ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "It's $TIME" "Battery at $CAPACITY% capacity"
        else
          ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "It's $TIME"
        fi
      '')

      # wlbrightness: Minimalist brightness control with a hard 10% floor.
      (writeScriptBin "wlbrightness" ''
        #!${pkgs.dash}/bin/dash
        set -eu

        # 1. Hard floor: clamp any decrease to 10%
        case "$1" in
            *-) 
                PRE=$(${pkgs.brightnessctl}/bin/brightnessctl i -m)
                tmp=''${PRE%,*}; perc=''${tmp##*,}; v=''${perc%%%}
                [ "$v" -le 10 ] && set -- 10%
                ;;
        esac

        # 2. Apply change and notify
        NEW=$(${pkgs.brightnessctl}/bin/brightnessctl set "$1" -m | cut -d, -f4)
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "Brightness: $NEW"
      '')

      # wlvolume: Minimalist volume control.
      (writeScriptBin "wlvolume" ''
        #!${pkgs.dash}/bin/dash
        set -eu

        # 1. Update hardware
        case "$1" in
            mute) ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
            *)    ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1" -l 1.5 ;;
        esac

        # 2. Format and notify
        INFO=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@)
        case "$INFO" in
            *MUTED*) TEXT="Volume: MUTED" ;;
            *)
                v=''${INFO##* }
                v=''${v%.*}''${v#*.}
                v=''${v#0}; v=''${v#0}
                TEXT="Volume: ''${v:-0}%"
                ;;
        esac
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "$TEXT"
      '')

      # wlscreenshot: Screenshot utility using grim and slurp.
      (writeScriptBin "wlscreenshot" ''
        #!${pkgs.dash}/bin/dash
        set -eu
        SCREENSHOT_DIR="$HOME/images/screenshots"
        mkdir -p "$SCREENSHOT_DIR"
        FILE="$SCREENSHOT_DIR/$(date +'%Y%m%d_%H%M%S').png"

        if [ "$#" -gt 0 ] && [ "$1" = "-s" ]; then
            GEOM=$(${pkgs.slurp}/bin/slurp)
            [ -z "$GEOM" ] && exit 0
            ${pkgs.grim}/bin/grim -g "$GEOM" "$FILE"
        else
            ${pkgs.grim}/bin/grim "$FILE"
        fi

        ${pkgs.wl-clipboard}/bin/wl-copy < "$FILE"
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:screenshot "Screenshot Taken" "Saved to $(basename "$FILE") and copied to clipboard" -i camera-photo
      '')

      # fuzzel-history-run: Smart bash history search/execution.
      # Silent/Small -> Notification | Large/Long/TUI -> Terminal
      (pkgs.writeScriptBin "fuzzel-history-run" ''
        #!${pkgs.bash}/bin/bash
        HISTFILE="$HOME/.bash_history"
        CMD=$(${pkgs.coreutils}/bin/tac "$HISTFILE" 2>/dev/null | ${pkgs.gawk}/bin/awk '!x[$0]++' | \
          ${pkgs.fuzzel}/bin/fuzzel -d -p "Run: " -w 80 \
            --no-sort \
            --placeholder="e.g. sudo nixos-rebuild switch")
        
        [ -z "$CMD" ] && exit 0
 
        # 1. Safeguard for destructive commands
        # Matches commands starting with rm, mv, cp, dd (optionally with sudo)
        DESTRUCTIVES="rm|mv|cp|dd|nix-collect-garbage"
        if [[ "$CMD" =~ ^(sudo\ )?($DESTRUCTIVES)(\ |$) ]]; then
            CONFIRM=$(printf "No\nYes" | ${pkgs.fuzzel}/bin/fuzzel -d -p "Destructive! Confirm? " -w 30)
            [ "$CONFIRM" != "Yes" ] && exit 0
        fi

        # 1. TUI/Interactive Detection (includes sudo for password prompt)
        TUIs="hx|top|htop|btop|iotop|nmtui|calcurse|pwvucontrol|nnn|less|man|vi|vim|nano|python|gh|ip|sudo"
        if [[ "$CMD" =~ ^($TUIs) ]] || [[ "$CMD" == *" -e "* ]] || [[ "$CMD" == *" --execute "* ]]; then
            exec setsid ${pkgs.foot}/bin/foot bash -i -c "$CMD; exec bash" >/dev/null 2>&1
        fi

        # 2. Smart Capture Path
        OUT_FILE=$(mktemp /tmp/fuzzel_run_XXXXXX)
        (eval "$CMD") > "$OUT_FILE" 2>&1 &
        PID=$!
        
        # Wait to check if it's a "quick" background task or a long/noisy one
        sleep 0.8
        
        if kill -0 $PID 2>/dev/null; then
            # Still running after 0.8s: Open terminal and follow output
            ${pkgs.libnotify}/bin/notify-send "Long Process Started" "$CMD"
            exec setsid ${pkgs.foot}/bin/foot bash -c "tail -f $OUT_FILE --pid=$PID; echo -e '\n--- Process Finished ---'; rm -f $OUT_FILE; exec bash" >/dev/null 2>&1
        else
            # Finished quickly: check output volume
            LINES=$(wc -l < "$OUT_FILE")
            if [ "$LINES" -gt 15 ]; then
                # Large output: show in terminal
                exec setsid ${pkgs.foot}/bin/foot bash -c "cat $OUT_FILE; echo -e '\n--- Output End ---'; rm -f $OUT_FILE; exec bash" >/dev/null 2>&1
            else
                # Small output: notify
                CONTENT=$(cat "$OUT_FILE" | head -c 1000)
                ${pkgs.libnotify}/bin/notify-send "Done: $CMD" "''${CONTENT:-[No Output]}"
                rm -f "$OUT_FILE"
            fi
        fi
      '')

      (pkgs.writeScriptBin "single-instance" ''
        #!${pkgs.dash}/bin/dash
        PROCS=$1; shift
        for p in $PROCS; do
            ${pkgs.procps}/bin/pgrep -x "$p" >/dev/null && exit 0
        done
        exec "$@" >/dev/null 2>&1
      '')
    ]
    ++ [
      batteryCheck
    ];

  systemd.user.services.battery-check = {
    Unit.Description = "Battery Status Monitor Service";
    Service = {
      Type = "simple";
      ExecStart = "${batteryCheck}/bin/battery-check";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
