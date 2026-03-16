{
  pkgs,
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
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user start graphical-session.target

        # 2. Restart portal services to ensure they recognize the new environment.
        systemctl --user restart xdg-desktop-portal-wlr.service
        systemctl --user restart xdg-desktop-portal.service
        
        # 3. Always start in dark mode.
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"

        # 4. Restore last wallpaper and theme.
        [ -f "$HOME/.wbg" ] && . "$HOME/.wbg"
        
        # Restore theme state
        STATE_FILE="$HOME/.cache/wltheme_state"
        if [ -f "$STATE_FILE" ]; then
            . "$STATE_FILE"
            if [ "$DARK_THEME" = "Dynamic" ]; then
                [ -f "$HOME/.wbg_path" ] && ${pkgs.wallust}/bin/wallust run -q "$(cat "$HOME/.wbg_path")" &
            else
                ${pkgs.wallust}/bin/wallust theme -q "$DARK_THEME" &
            fi
            WPID=$!; ( wait $WPID; ${pkgs.mako}/bin/makoctl reload ) &
        fi
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
          ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "It's $TIME" "Battery at $CAPACITY% capacity"
        else
          ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "It's $TIME"
        fi
      '')

      # wlbrightness: Minimalist brightness control with a hard 10% floor.
      (writeScriptBin "wlbrightness" ''
        #!${pkgs.dash}/bin/dash
        set -eu

        # 1. Read pre-state (format: device,class,cur,max,pct%)
        PRE=$(${pkgs.brightnessctl}/bin/brightnessctl i -m)
        tmp=''${PRE%,*}; perc=''${tmp##*,}; v=''${perc%%%}

        # 2. Hard floor: clamp any decrease to 10%
        case "$1" in
            *-) [ "$v" -le 10 ] && set -- 10% ;;
        esac

        ${pkgs.brightnessctl}/bin/brightnessctl set "$1" -q

        # 3. Read post-state and notify with progress bar
        POST=$(${pkgs.brightnessctl}/bin/brightnessctl i -m)
        tmp=''${POST%,*}; perc=''${tmp##*,}; v=''${perc%%%}
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status -h int:value:"$v" "Brightness: $perc"
      '')

      # wlvolume: Minimalist volume control with atomic locking and % progress bar.
      (writeScriptBin "wlvolume" ''
        #!${pkgs.dash}/bin/dash
        set -eu

        # Atomic lock (mkdir fails if already exists, preventing races)
        LOCK="/tmp/wlvolume.lock"
        mkdir "$LOCK" 2>/dev/null || exit 0
        trap 'rmdir "$LOCK"' EXIT

        # 1. Update hardware (strict 100% cap)
        case "$1" in
            mute) ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
            *)    ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1" -l 1.0 ;;
        esac

        # 2. Format and notify
        # wpctl output format: "Volume: 0.55" or "Volume: 0.55 [MUTED]"
        INFO=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@)
        if [ "''${INFO#*MUTED}" != "$INFO" ]; then
            ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "Volume: MUTED"
        else
            vol=''${INFO##* }            # "0.55"
            v=''${vol%.*}''${vol#*.}     # "055"
            v=''${v#0}; v=''${v#0}       # "55"
            [ -z "$v" ] && v=0
            ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status -h int:value:"$v" "Volume: $v%"
        fi
      '')

    ]
    ++ [
      batteryCheck
    ];

  systemd.user.services.battery-check = {
    Unit.Description = "Battery Low Warning Service";
    Service = {
      Type = "oneshot";
      ExecStart = "${batteryCheck}/bin/battery-check";
    };
  };

  systemd.user.timers.battery-check = {
    Timer = {
      OnCalendar = "*:0/5";
      Unit = "battery-check.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
