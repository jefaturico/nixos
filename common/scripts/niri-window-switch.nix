{ pkgs }:
let
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  jq = "${pkgs.jq}/bin/jq";
  niri = "${pkgs.niri}/bin/niri";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
  curl = "${pkgs.curl}/bin/curl";
  awk = "${pkgs.gawk}/bin/awk";
  stat = "${pkgs.coreutils}/bin/stat";
in
''
  #!${pkgs.bash}/bin/bash

  BRAVE_DEBUG_URL="http://127.0.0.1:9222"
  CACHE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/niri-window-switch"
  BRAVE_TABS_CACHE="$CACHE_DIR/brave-tabs.tsv"
  BRAVE_TABS_TTL=30

  notify() {
      ${notifySend} -h string:x-canonical-private-synchronous:status "Window Switcher" "$1"
  }

  clean_cache() {
      local now mtime
      [ -s "$BRAVE_TABS_CACHE" ] || return 1
      now=$(${pkgs.coreutils}/bin/date +%s)
      mtime=$(${stat} -c %Y "$BRAVE_TABS_CACHE" 2>/dev/null || printf 0)
      [ $((now - mtime)) -le "$BRAVE_TABS_TTL" ]
  }

  refresh_brave_tabs() (
      local workspace="$1"
      local tmp="$BRAVE_TABS_CACHE.$$"

      ${pkgs.coreutils}/bin/mkdir -p "$CACHE_DIR"
      ${curl} -fsS --connect-timeout 0.08 --max-time 0.35 "$BRAVE_DEBUG_URL/json" 2>/dev/null \
          | ${jq} -r --arg workspace "''${workspace:-?}" '
              def clean:
                  tostring
                  | gsub("[\t\r\n]+"; " ")
                  | gsub("^ +| +$"; "");

              .[]
              | select(.type == "page")
              | (.title // .url // "Untitled" | clean) as $title
              | "\(.id)\tbrave-tab\t[\($workspace)] Brave - \($title)"
          ' > "$tmp" 2>/dev/null \
          && [ -s "$tmp" ] \
          && ${pkgs.coreutils}/bin/mv "$tmp" "$BRAVE_TABS_CACHE"
      ${pkgs.coreutils}/bin/rm -f "$tmp"
  )

  WINDOWS_JSON="$(${niri} msg -j windows 2>/dev/null)"
  if [ -z "$WINDOWS_JSON" ]; then
      notify "Could not read niri windows"
      exit 1
  fi

  BRAVE_INFO="$(printf '%s\n' "$WINDOWS_JSON" | ${jq} -r '
      [
          (.windows? // .)[]
          | select(.app_id == "brave-browser" or .app_id == "brave")
      ]
      | sort_by(.focus_timestamp.secs // 0, .focus_timestamp.nanos // 0)
      | last
      | if . == null then "\t" else "\(.id)\t\(.workspace_id // "?")" end
  ')"
  IFS=$'\t' read -r BRAVE_WINDOW_ID BRAVE_WORKSPACE <<< "$BRAVE_INFO"

  # Never block the launcher on Brave's remote-debugging endpoint. Use the latest
  # warm cache for this invocation and refresh it in the background for the next.
  if [ -n "$BRAVE_WINDOW_ID" ]; then
      refresh_brave_tabs "$BRAVE_WORKSPACE" >/dev/null 2>&1 &
  fi

  BRAVE_TABS=""
  if clean_cache; then
      BRAVE_TABS="$(cat "$BRAVE_TABS_CACHE")"
  fi

  WINDOWS="$(printf '%s\n' "$WINDOWS_JSON" | ${jq} -r --arg hide_brave "$([ -n "$BRAVE_TABS" ] && printf true || printf false)" '
      def clean:
          tostring
          | gsub("[\t\r\n]+"; " ")
          | gsub("^ +| +$"; "");

      (.windows? // .)[]
      | select(
          $hide_brave != "true"
          or ((.app_id == "brave-browser" or .app_id == "brave") | not)
        )
      | (.workspace_id // "?" | tostring) as $workspace
      | ((.title // "Untitled") | clean) as $title
      | "\(.id)\twindow\t[\($workspace)] \($title)"
  ')"

  ENTRIES="$(printf '%s\n%s\n' "$WINDOWS" "$BRAVE_TABS" | ${awk} -F '\t' '
      NF >= 3 {
          rows[++n] = $0
          labels[n] = $3
          counts[$3]++
      }
      END {
          for (i = 1; i <= n; i++) {
              suffix = ""
              if (counts[labels[i]] > 1) {
                  seen[labels[i]]++
                  suffix = " (" seen[labels[i]] ")"
              }
              print rows[i] suffix
          }
      }
  ')"

  if [ -z "$ENTRIES" ]; then
      notify "No open windows or browser tabs"
      exit 0
  fi

  SELECTED="$(printf '%s\n' "$ENTRIES" | ${awk} -F '\t' '{ print $3 }' | ${fuzzel} -d --no-sort -p "Focus a window: " -w 80 || true)"
  if [ -z "$SELECTED" ]; then
      exit 0
  fi

  SELECTED_ENTRY="$(printf '%s\n' "$ENTRIES" | ${awk} -F '\t' -v selected="$SELECTED" '$3 == selected { print; exit }')"
  if [ -z "$SELECTED_ENTRY" ]; then
      notify "Could not parse selection"
      exit 1
  fi

  IFS=$'\t' read -r TARGET_ID TARGET_KIND _ <<< "$SELECTED_ENTRY"

  case "$TARGET_KIND" in
      window)
          ${niri} msg action focus-window --id "$TARGET_ID"
          ;;
      brave-tab)
          if [ -n "$BRAVE_WINDOW_ID" ]; then
              ${niri} msg action focus-window --id "$BRAVE_WINDOW_ID"
          fi
          ${curl} -fsS --connect-timeout 0.08 --max-time 1 -X PUT "$BRAVE_DEBUG_URL/json/activate/$TARGET_ID" >/dev/null \
              || notify "Could not activate Brave tab"
          ;;
      *)
          notify "Unknown selection type: $TARGET_KIND"
          exit 1
          ;;
  esac
''
