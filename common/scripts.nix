{ pkgs, lib, osConfig, ... }:

let
  batteryCheck = pkgs.writeShellScriptBin "battery-check" ''
    # battery-check.sh
    # Checks battery level and notifies if low
    set -euo pipefail

    # Find the first battery
    BAT=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" | ${pkgs.coreutils}/bin/head -n 1)

    if [ -z "$BAT" ]; then
        # No battery found
        exit 0
    fi

    CAPACITY=$(${pkgs.coreutils}/bin/cat "$BAT/capacity")
    STATUS=$(${pkgs.coreutils}/bin/cat "$BAT/status")

    if [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le 20 ]; then
        ${pkgs.libnotify}/bin/notify-send -u critical "Battery Low" "Level: ''${CAPACITY}%"
    fi
  '';
in
{
  home.packages = with pkgs; [
    (writeShellScriptBin "dwl-session" ''
      # dwl-session
      # Wraps dwl execution with startup tasks

      # 1. Environment
      export XDG_CURRENT_DESKTOP=wlroots
      export XDG_SESSION_TYPE=wayland
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

      # 2. Key components
      systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
      systemctl --user start graphical-session.target

      # 3. Exec Dwl (log to file for debug)
      # Run wallpaper script using -s flag to ensure Wayland socket is ready
      STARTUP=""
      [ -f "$HOME/.wbg" ] && STARTUP="-s $HOME/.wbg"

      exec dwl $STARTUP > /tmp/dwl.log 2>&1
    '')


    (writeShellScriptBin "wlsetbg" ''
      # wsetbg.sh - Optimized & Smart Wallpaper Setter
      # Usage: wsetbg.sh [-r]

      export LC_ALL=C

      WALL_DIR="$HOME/images/wallpapers"
      STARTUP_SCRIPT="$HOME/.wbg"
      HISTORY_FILE="$HOME/.cache/wsetbg_history"
      CURRENT_WALL=""

      # Ensure history file exists
      mkdir -p "$(dirname "$HISTORY_FILE")"
      touch "$HISTORY_FILE"

      # 1. Fast retrieval of current wallpaper
      if [[ -f "$STARTUP_SCRIPT" ]]; then
          CURRENT_WALL=$(${pkgs.gnugrep}/bin/grep -o '"[^"]*"' "$STARTUP_SCRIPT" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d '"')
      fi

      get_smart_random_wallpaper() {
          ${pkgs.fd}/bin/fd --type f --absolute-path . "$WALL_DIR" | \
          ${pkgs.gawk}/bin/awk -v hist_file="$HISTORY_FILE" -v current_wall="$CURRENT_WALL" '
          BEGIN {
              srand();
              # Load history: map path -> timestamp
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
                  # Tier 1: Unseen
                  unseen[u_count++] = path;
              } else {
                  # Tier 2: Seen
                  seen[path] = history[path];
                  s_count++;
              }
          }

          END {
              # Tier 1: Pick Unseen if any
              if (u_count > 0) {
                  print unseen[int(rand() * u_count)];
                  exit 0;
              }

              if (s_count == 0) exit 1;

              # Tier 2: Pick from Oldest 20%
              # Use gawk sorted traversal
              PROCINFO["sorted_in"] = "@val_num_asc";

              cutoff = int(s_count * 0.2) + 1;
              if (cutoff < 1) cutoff = 1;

              k = 0;
              for (p in seen) {
                  candidates[k++] = p;
                  if (k >= cutoff) break;
              }
              
              # Pick random from candidates
              print candidates[int(rand() * k)];
          }
          '
      }

      if [[ "$1" == "-r" ]]; then
          FULL_PATH=$(get_smart_random_wallpaper)
          # Fallback
          if [[ -z "$FULL_PATH" ]]; then
              FULL_PATH=$(${pkgs.fd}/bin/fd --type f --absolute-path . "$WALL_DIR" | ${pkgs.coreutils}/bin/shuf -n 1)
          fi
      else
          # Interactive Mode
          cd "$WALL_DIR" || exit 1
          CHOICE=$(${pkgs.fd}/bin/fd --type f | ${pkgs.fuzzel}/bin/fuzzel -d -p "Select Wallpaper: ")
          [[ -z "$CHOICE" ]] && exit 0
          FULL_PATH="$WALL_DIR/$CHOICE"
      fi

      [[ -z "$FULL_PATH" || ! -f "$FULL_PATH" ]] && exit 1

      # 2. Apply Wallpaper (Instant feedback)
      pkill wbg
      wbg "$FULL_PATH" > /dev/null 2>&1 &

      # 3. Update History (Append)
      # We append now, compact later
      echo "$(date +%s) $FULL_PATH" >> "$HISTORY_FILE"

      # 4. Background Maintenance (Compaction)
      # Compact history: Keep only latest timestamp per file
      (
          if [ -f "$HISTORY_FILE" ]; then
              TMP_HIST="/tmp/wsetbg_history_$$"
              # tac + awk !seen is typically fast enough for ~1000 lines
              tac "$HISTORY_FILE" | awk '!seen[$2]++' | tac > "$TMP_HIST"
              mv "$TMP_HIST" "$HISTORY_FILE"
          fi
      ) &

      # 5. Persist startup script
      {
          echo "#!/usr/bin/env bash"
          echo "wbg \"$FULL_PATH\" &"
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
      fuzzel -d --no-sort -p "Select Document: " -w 100 | \
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











  ] ++ lib.optionals (osConfig.networking.hostName == "ekman") [
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
