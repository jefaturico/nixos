{ pkgs }:
let
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  jq = "${pkgs.jq}/bin/jq";
  niri = "${pkgs.niri}/bin/niri";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
  curl = "${pkgs.curl}/bin/curl";
in
''
  #!${pkgs.bash}/bin/bash

  BRAVE_DEBUG_URL="http://127.0.0.1:9222"

  notify() {
      ${notifySend} -h string:x-canonical-private-synchronous:status "Window Switcher" "$1"
  }

  WINDOWS_JSON="$(${niri} msg -j windows 2>/dev/null)"
  if [ -z "$WINDOWS_JSON" ]; then
      notify "Could not read niri windows"
      exit 1
  fi

  BRAVE_WINDOW="$(printf '%s\n' "$WINDOWS_JSON" | ${jq} -r '
      [
          (.windows? // .)[]
          | select(.app_id == "brave-browser" or .app_id == "brave")
      ]
      | sort_by(.focus_timestamp.secs // 0, .focus_timestamp.nanos // 0)
      | last
      | if . == null then empty else "\(.id)\t\(.workspace_id // "?")" end
  ')"
  BRAVE_WINDOW_ID="$(printf '%s\n' "$BRAVE_WINDOW" | ${pkgs.gawk}/bin/awk -F '\t' '{ print $1 }')"
  BRAVE_WORKSPACE="$(printf '%s\n' "$BRAVE_WINDOW" | ${pkgs.gawk}/bin/awk -F '\t' '{ print $2 }')"

  BRAVE_TABS_JSON="$(${curl} -fsS --max-time 0.4 "$BRAVE_DEBUG_URL/json" 2>/dev/null || true)"
  BRAVE_TABS=""
  if [ -n "$BRAVE_TABS_JSON" ]; then
      BRAVE_TABS="$(printf '%s\n' "$BRAVE_TABS_JSON" | ${jq} -r --arg workspace "''${BRAVE_WORKSPACE:-?}" '
          def clean:
              tostring
              | gsub("[\t\r\n]+"; " ")
              | gsub("^ +| +$"; "");

          .[]
          | select(.type == "page")
          | (.title // .url // "Untitled" | clean) as $title
          | "\(.id)\tbrave-tab\t[\($workspace)] Brave - \($title)"
      ' 2>/dev/null || true)"
  fi

  WINDOWS="$(printf '%s\n' "$WINDOWS_JSON" | ${jq} -r --arg hide_brave "$([ -n "$BRAVE_TABS" ] && printf true || printf false)" '
      def clean:
          tostring
          | gsub("[\t\r\n]+"; " ")
          | gsub("^ +| +$"; "");

      (.windows? // .) as $raw
      | $raw[]
      | . as $window
      | select(
          $hide_brave != "true"
          or (($window.app_id == "brave-browser" or $window.app_id == "brave") | not)
        )
      | ($window.workspace_id // "?" | tostring) as $workspace
      | (($window.title // "Untitled") | clean) as $title
      | "\($window.id)\twindow\t[\($workspace)] \($title)"
  ')"

  ENTRIES="$(printf '%s\n%s\n' "$WINDOWS" "$BRAVE_TABS" | ${pkgs.gawk}/bin/awk -F '\t' '
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

  SELECTED="$(printf '%s\n' "$ENTRIES" | ${pkgs.coreutils}/bin/cut -f3- | ${fuzzel} -d --no-sort -p "Focus a window: " -w 80 || true)"
  if [ -z "$SELECTED" ]; then
      exit 0
  fi

  SELECTED_ENTRY="$(printf '%s\n' "$ENTRIES" | ${pkgs.gawk}/bin/awk -F '\t' -v selected="$SELECTED" '$3 == selected { print; exit }')"
  if [ -z "$SELECTED_ENTRY" ]; then
      notify "Could not parse selection"
      exit 1
  fi

  TARGET_ID="$(printf '%s\n' "$SELECTED_ENTRY" | ${pkgs.gawk}/bin/awk -F '\t' '{ print $1 }')"
  TARGET_KIND="$(printf '%s\n' "$SELECTED_ENTRY" | ${pkgs.gawk}/bin/awk -F '\t' '{ print $2 }')"

  case "$TARGET_KIND" in
      window)
          ${niri} msg action focus-window --id "$TARGET_ID"
          ;;
      brave-tab)
          if [ -n "$BRAVE_WINDOW_ID" ]; then
              ${niri} msg action focus-window --id "$BRAVE_WINDOW_ID"
          fi
          ${curl} -fsS --max-time 1 -X PUT "$BRAVE_DEBUG_URL/json/activate/$TARGET_ID" >/dev/null \
              || notify "Could not activate Brave tab"
          ;;
      *)
          notify "Unknown selection type: $TARGET_KIND"
          exit 1
          ;;
  esac
''
