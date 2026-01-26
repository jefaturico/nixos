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
    (writeShellScriptBin "river-lof" ''
      # launch-or-focus.sh
      # Usage: launch-or-focus.sh <APP_PATTERN> <COMMAND> <WORKSPACE_INDEX>

      if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
          echo "Usage: $(basename "$0") <APP_PATTERN> <COMMAND> <WORKSPACE_INDEX>"
          exit 1
      fi

      APP_PATTERN="$1"
      CMD="$2"
      WS_INDEX="$3"
      EXTRA_MASK="''${4:-0}"

      # 1. Switch workspace immediately for responsiveness
      # Calculate the tag bitmask (1 << (WS_INDEX - 1)) | EXTRA_MASK
      riverctl set-focused-tags $(( (1 << (WS_INDEX - 1)) | EXTRA_MASK ))

      # 2. Check if running & Focus (The wlrctl way)
      # wlrctl window focus returns 0 if it found and focused a window matching the ID or title.
      if wlrctl window focus "$APP_PATTERN"; then
          exit 0
      fi

      # 3. Startup Check (Spam Protection)
      # If wlrctl didn't find it, it might be starting up.
      # We use pgrep -f for flexibility.
      # We explicitly exclude THIS script's PID ($$) to prevent self-match.
      if pgrep -f "$APP_PATTERN" | grep -v -q "^$$\$"; then
          exit 0
      fi

      # 4. Spam protection lock (Double layer)
      LOCK_FILE="/tmp/river_lof_''${WS_INDEX}.lock"
      exec 200>"$LOCK_FILE"

      # Try to acquire lock (non-blocking)
      if ! flock -n 200; then
          exit 0
      fi

      # Double-check (race condition)
      if pgrep -f "$APP_PATTERN" | grep -v -q "^$$\$"; then
          exit 0
      fi

      # 4. Launch
      # setsid to detach.
      setsid "$CMD" >/dev/null 2>&1 &

      # Keep lock held briefly to cover startup time
      sleep 0.5
    '')

    (writeShellScriptBin "river-setbg" ''
      # wsetbg.sh - Optimized & Smart Wallpaper Setter
      # Usage: wsetbg.sh [-r]

      WALL_DIR="$HOME/images/wallpapers"
      STARTUP_SCRIPT="$HOME/.wbg"
      HISTORY_FILE="$HOME/.cache/wsetbg_history"
      CURRENT_WALL=""

      # Ensure history file exists
      mkdir -p "$(dirname "$HISTORY_FILE")"
      touch "$HISTORY_FILE"

      # 1. Fast retrieval of current wallpaper
      if [[ -f "$STARTUP_SCRIPT" ]]; then
          CURRENT_WALL=$(grep -o '"[^"]*"' "$STARTUP_SCRIPT" 2>/dev/null | tr -d '"')
      fi

      get_smart_random_wallpaper() {
          # Pipe absolute paths from fd to awk script
          # Awk replacement for Python: significantly faster startup (<5ms vs ~50ms).
          # Logic: Weight = (NOW - LastSeen)^2. Unseen files have massive weight.
          fd --type f --absolute-path . "$WALL_DIR" | \
          awk -v hist_file="$HISTORY_FILE" -v current_wall="$CURRENT_WALL" -v NOW="$(date +%s)" '
          BEGIN {
              srand();
              # Load history: map path -> timestamp
              while ((getline line < hist_file) > 0) {
                  # History format: timestamp path
                  # We use only the first space as separator to handle spaces in paths
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

              last_seen = (path in history) ? history[path] : 0;

              # Weight calculation
              # Unseen files (last_seen=0) -> delta = NOW -> weight = huge.
              delta = NOW - last_seen;
              weight = delta * delta;

              candidates[count] = path;
              weights[count] = weight;
              total_weight += weight;
              count++;
          }

          END {
              if (count == 0) exit 1;

              # Weighted Random Selection
              r = rand() * total_weight;
              running_sum = 0;

              for (i = 0; i < count; i++) {
                  running_sum += weights[i];
                  if (r <= running_sum) {
                      print candidates[i];
                      exit 0;
                  }
              }
              # Fallback
              print candidates[count-1];
          }
          '
      }

      if [[ "$1" == "-r" ]]; then
          FULL_PATH=$(get_smart_random_wallpaper)
          # Fallback to simple random if smart selector failed (e.g. no python or empty list)
          if [[ -z "$FULL_PATH" ]]; then
              FULL_PATH=$(fd --type f --absolute-path . "$WALL_DIR" | shuf -n 1)
          fi
      else
          # Interactive Mode
          cd "$WALL_DIR" || exit 1
          # Use relative paths for better UI
          CHOICE=$(fd --type f | fuzzel -d -p "Select Wallpaper: ")
          [[ -z "$CHOICE" ]] && exit 0
          FULL_PATH="$WALL_DIR/$CHOICE"
      fi

      [[ -z "$FULL_PATH" || ! -f "$FULL_PATH" ]] && exit 1

      # 2. Apply Wallpaper (Instant feedback)
      pkill wbg
      wbg "$FULL_PATH" > /dev/null 2>&1 &



      # 3. Update History (Append only for speed)
      echo "$(date +%s) $FULL_PATH" >> "$HISTORY_FILE"

      # 4. Persist startup script
      {
          echo "#!/usr/bin/env bash"
          echo "wbg \"$FULL_PATH\" &"
      } > "$STARTUP_SCRIPT"
      chmod +x "$STARTUP_SCRIPT"

      # 5. Background Heavy Tasks
      (
          # Generate colors using standard wal backend
          wal -n -q -b 000000 -i "$FULL_PATH"

          # Static logic
          if [ -f "$HOME/.cache/wal/colors.sh" ]; then
              . "$HOME/.cache/wal/colors.sh"

              riverctl border-color-focused "0x''${color4#\#}ff"
              riverctl border-color-unfocused "0x00000000"
          fi
      ) &

      exit 0
    '')

    (writeShellScriptBin "wdoc-find" ''
      # wdoc-find.sh - Fast Document Selector
      # Usage: wdoc-find.sh

      # 1. Use fd to search specific directories.
      # 2. Sort by Zathura history (bookmarks.sqlite) because filesystem is noatime.
      # 3. Select with fuzzel and open with zathura.
      fd --type f -e pdf -e epub --follow --absolute-path . ~/college ~/library ~/downloads 2>/dev/null | \
      python3 -c "
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
      fuzzel -d -p "Select Document: " -w 100 | \
      {
          if read -r file; then
              setsid zathura "$file" >/dev/null 2>&1 &
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

      # 3. Simple Focus: Switch to Workspace 1
      # User requested to just switch to workspace 1 where browser typically lives.
      riverctl set-focused-tags 1
    '')

    (writeShellScriptBin "river-toggle-scratch" ''
      # river-toggle-scratch
      # Usage: river-toggle-scratch <TAG_MASK> <APP_ID>

      TAG_MASK=$1
      APP_ID="''${2:-scratchpad}"

      if [ -z "$TAG_MASK" ]; then
          exit 1
      fi

      # Toggle-and-Chase Logic
      # We always toggle the tag mask.
      # 1. If it was hidden, it becomes visible -> We loop to steal focus.
      # 2. If it was visible, it becomes hidden -> We loop to focus (fails harmlessly), effectively hiding it.

      riverctl toggle-focused-tags $TAG_MASK

      # Try to focus the window if it became visible.
      # We assume if wlrctl succeeds, we are done.
      # If it fails repeatedly, we assume it's hidden.
      # Lower sleep time for snappiness.
      for i in {1..20}; do
         if wlrctl window focus "$APP_ID"; then
             exit 0
         fi
         sleep 0.05
      done
    '')
    (writeShellScriptBin "shonke" ''
      # shonke - Zettelkasten Selector
      # Usage: shonke

      NOTES_DIR="$HOME/zettelkasten"
      MAIN_DIR="$NOTES_DIR/main"

      # Ensure main directory exists
      mkdir -p "$MAIN_DIR"

      # cd to NOTES_DIR to make paths relative
      cd "$NOTES_DIR" || exit 1

      # Find files, pipe to fuzzel
      SELECTION=$(fd --type f --extension md | fuzzel -d -p "Zettel: " -w 50)

      if [ -z "$SELECTION" ]; then
          exit 0
      fi

      if [ -f "$SELECTION" ]; then
          # Open existing note
          exec footclient -D "$NOTES_DIR" -e hx "$SELECTION"
      else
          # Create new note in main directory
          exec footclient -D "$MAIN_DIR" -e hx "$SELECTION.md"
      fi
    '')

    (writeShellScriptBin "task-fuzzel" ''
      # task-fuzzel.sh - Fuzzel interface for Taskwarrior
      # Usage: task-fuzzel

      set -euo pipefail

      # Configuration
      TERMINAL="footclient"
      FUZZEL_ARGS=(-d -w 50)

      # Helper: Prompt for input using fuzzel dmenu mode
      get_input() {
          echo "" | fuzzel "''${FUZZEL_ARGS[@]}" -p "$1" --lines 0 | head -n1 || true
      }

      # Helper: Notify
      notify() {
          notify-send "Taskwarrior" "$1"
      }

      # 1. Add Task
      add_task() {
          INPUT=$(get_input "Add Task: ")
          if [ -n "$INPUT" ]; then
              # shellcheck disable=SC2086
              if task rc.hooks=off add $INPUT; then
                  notify "Task added: $INPUT"
              else
                  notify "Failed to add task"
              fi
          fi
      }

      # 2. Browse & Action
      browse_tasks() {
          FILTER="$1"

          while true; do
              # Fetch data as JSON
              EXPORT_DATA=$(task rc.verbose=nothing rc.hooks=off $FILTER export 2>/dev/null)

              if [ -z "$EXPORT_DATA" ] || [ "$EXPORT_DATA" == "[]" ]; then
                   notify "No tasks found."
                   return
              fi

              # Parse JSON with Python
              # Note: Indentation of python code must match base indent to be stripped correctly by Nix
              PARSED_LIST=$(echo "$EXPORT_DATA" | python3 -c "
      import sys, json

      try:
          data = json.load(sys.stdin)
          # Sort by urgency (descending)
          data.sort(key=lambda x: x.get('urgency', 0), reverse=True)

          for t in data:
              uuid = t.get('uuid', ''')
              desc = t.get('description', ''')
              proj = t.get('project', ''')

              if proj:
                  proj = f'[{proj}] '

              display = f'{proj}{desc}'
              display = display.replace('\n', ' ')

              print(f'{uuid} {display}')
      except:
          pass
      ")

              if [ -z "$PARSED_LIST" ]; then
                  notify "No tasks parsed."
                  return
              fi

              declare -a UUIDS
              declare -a DISPLAY_LINES

              # Reset arrays
              UUIDS=()
              DISPLAY_LINES=()

              while IFS= read -r line; do
                  UUIDS+=("''${line%% *}")
                  DISPLAY_LINES+=("''${line#* }")
              done <<< "$PARSED_LIST"

              # Dynamic line count
              COUNT=''${#DISPLAY_LINES[@]}
              [ "$COUNT" -gt 30 ] && COUNT=30

              # Show Task List
              # If Esc pressed (exit code != 0), return to Main Menu
              if ! CHOICE_INDEX=$(printf "%s\n" "''${DISPLAY_LINES[@]}" | fuzzel "''${FUZZEL_ARGS[@]}" --dmenu --index -l "$COUNT" -p "Select Task: "); then
                  return
              fi

              if [ -z "$CHOICE_INDEX" ]; then return; fi

              SELECTED_UUID="''${UUIDS[$CHOICE_INDEX]}"
              SELECTED_DESC="''${DISPLAY_LINES[$CHOICE_INDEX]}"

              # Truncate description for prompt (max 20 chars)
              if [ ''${#SELECTED_DESC} -gt 20 ]; then
                   PROMPT_DESC="''${SELECTED_DESC:0:20}..."
              else
                   PROMPT_DESC="$SELECTED_DESC"
              fi

              # Action Loop
              while true; do
                  if ! ACTION=$(printf "Done\nModify\nAnnotate\nInfo\nDelete" | fuzzel "''${FUZZEL_ARGS[@]}" -d -l 5 -p "Action [$PROMPT_DESC]: "); then
                      # Esc on Action Menu -> Back to Task List
                      break
                  fi

                  case "$ACTION" in
                      "Done")
                          task rc.hooks=off "$SELECTED_UUID" done
                          notify "Task marked completed."
                          break # Back to list
                          ;;
                      "Modify")
                          MOD=$(get_input "Modify [$PROMPT_DESC]: ")
                          if [ -n "$MOD" ]; then
                              # shellcheck disable=SC2086
                              task rc.hooks=off "$SELECTED_UUID" modify $MOD
                              notify "Task modified."
                              break # Back to list
                          fi
                          # If cancelled/empty, stay in Action Menu
                          ;;
                      "Annotate")
                          ANN=$(get_input "Annotate [$PROMPT_DESC]: ")
                          if [ -n "$ANN" ]; then
                              # shellcheck disable=SC2086
                              task rc.hooks=off "$SELECTED_UUID" annotate $ANN
                              notify "Task annotated."
                              break # Back to list
                          fi
                          # If cancelled/empty, stay in Action Menu
                          ;;
                      "Delete")
                          if CONFIRM=$(printf "No\nYes" | fuzzel "''${FUZZEL_ARGS[@]}" -d -l 2 -p "Delete [$PROMPT_DESC]? "); then
                              if [ "$CONFIRM" == "Yes" ]; then
                                  task rc.hooks=off rc.confirmation=no "$SELECTED_UUID" delete
                                  notify "Task deleted."
                                  break # Back to list
                              fi
                          fi
                          # If No or Esc, continue loop (back to Action Menu)
                          ;;
                      "Info")
                          # Custom Info Display

                          # Fetch JSON for specific task
                          # Using a temp file to avoid shell expansion issues with echo
                          TMP_JSON="/tmp/task-info-$$.json"
                          task rc.hooks=off rc.verbose=nothing "$SELECTED_UUID" export > "$TMP_JSON" 2>/dev/null

                          # Debug: Check if file empty
                          if [ ! -s "$TMP_JSON" ]; then
                              notify "Error: No data fetched for task."
                              rm -f "$TMP_JSON"
                              continue
                          fi

                          # Parse and format with Python
                          # Reading from file instead of echo pipe
                          INFO_TEXT=$(python3 -c "
      import sys, json, datetime, textwrap

      def fmt_date(iso_str):
          if not iso_str: return '''
          try:
              dt = datetime.datetime.strptime(iso_str, '%Y%m%dT%H%M%SZ')
              return dt.strftime('%Y-%m-%d %H:%M')
          except Exception as e:
              return iso_str

      try:
          with open('$TMP_JSON', 'r') as f:
              data = json.load(f)

          if not data:
              print('No data in JSON')
              sys.exit(0)

          t = data[0]

          lines = []

          def add_wrapped(label, text, indent='  '):
              if not text: return
              full_text = f'{label}: {text}' if label else text
              wrapped = textwrap.wrap(full_text, width=45)
              for i, line in enumerate(wrapped):
                  if i > 0 and label:
                      lines.append(f'{indent}{line}')
                  else:
                      lines.append(line)

          desc = t.get('description', '(No description)')
          add_wrapped('Task', desc)

          proj = t.get('project')
          if proj:
              lines.append(f'Project: {proj}')

          due = t.get('due')
          if due:
              lines.append(f'Due: {fmt_date(due)}')

          sched = t.get('scheduled')
          if sched:
              lines.append(f'Scheduled: {fmt_date(sched)}')

          annots = t.get('annotations', [])
          if annots:
              lines.append('Annotations:')
              for a in annots:
                  txt = a.get('description', ''')
                  # wrap annotation text
                  wrapped_annot = textwrap.wrap(txt, width=45)
                  for i, line in enumerate(wrapped_annot):
                      if i == 0:
                          lines.append(f'  - {line}')
                      else:
                          lines.append(f'    {line}')

          print('\n'.join(lines))
      except Exception as e:
          print(f'Error parsing task info: {e}')
      ")
                          rm -f "$TMP_JSON"

                          if [ -n "$INFO_TEXT" ]; then
                              # Calculate line count (max 20)
                              LINE_COUNT=$(echo "$INFO_TEXT" | wc -l)
                              [ "$LINE_COUNT" -gt 20 ] && LINE_COUNT=20

                              # Display via fuzzel (ignore exit code)
                              echo "$INFO_TEXT" | fuzzel "''${FUZZEL_ARGS[@]}" -l "$LINE_COUNT" -p "Info [$PROMPT_DESC]: " >/dev/null 2>&1 || true
                          else
                              notify "Error: Failed to parse info."
                          fi
                          # Continue Action loop (Show Action Menu again)
                          ;;
                  esac
              done
          done
      }

      # Main Menu
      while true; do
          MENU="Add Task\nReady Tasks\nAll Tasks\nOpen Terminal"
          # Count lines in MENU (4 fixed)
          if ! SELECTION=$(echo -e "$MENU" | fuzzel "''${FUZZEL_ARGS[@]}" -d -l 4 -p "Taskwarrior: "); then
              # Exit script on Esc from Main Menu
              exit 0
          fi

          case "$SELECTION" in
              "Add Task")
                  add_task
                  ;;
              "Ready Tasks")
                  browse_tasks "status:pending +READY"
                  ;;
              "All Tasks")
                  browse_tasks "status:pending"
                  ;;
              "Open Terminal")
                  setsid "$TERMINAL" sh -c "task ready; exec $SHELL" >/dev/null 2>&1 &
                  ;;
          esac
      done
    '')

    (writeShellScriptBin "systeminfo" ''
      # systeminfo - Fast System Status
      # Usage: systeminfo

      # 1. Date & Time
      TIME=$(date +%I:%M\ %p)

      # 2. Battery (Smart Detection)
      # Find first BAT directory
      BAT_DIR=$(find /sys/class/power_supply -name "BAT*" -print -quit)

      if [ -n "$BAT_DIR" ]; then
          CAP=$(cat "$BAT_DIR/capacity")
          STATUS=$(cat "$BAT_DIR/status")
          BODY="Battery: $CAP% ($STATUS)"
      else
          BODY=""
      fi

      notify-send -r 5555 -u normal "It's $TIME" "$BODY"
    '')
    (writeShellScriptBin "capture-thought" ''
       # capture-thought
       # Usage: capture-thought

       INBOX_FILE="$HOME/zettelkasten/inbox.md"
       mkdir -p "$(dirname "$INBOX_FILE")"
       [ ! -f "$INBOX_FILE" ] && touch "$INBOX_FILE"

       # Prompt for thought
       THOUGHT=$(echo "" | fuzzel -d -p "Capture a thought: " -w 60 --lines 0 | head -n1)

       if [ -n "$THOUGHT" ]; then
           TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
           echo "" >> "$INBOX_FILE"
           echo "- [$TIMESTAMP] $THOUGHT" >> "$INBOX_FILE"
           notify-send "Thought Captured" "$THOUGHT"
       fi
    '')

    (writeShellScriptBin "open-focus" ''
      # open-focus
      # Usage: open-focus <URL>
      
      URL="$1"
      if [ -z "$URL" ]; then
          exit 1
      fi

      setsid xdg-open "$URL" >/dev/null 2>&1 &
      # Wait a tiny bit for the window to potentially exist/register if it wasn't open
      # But mostly we just want to focus the existing instance.
      sleep 0.2
      wlrctl window focus helium
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
