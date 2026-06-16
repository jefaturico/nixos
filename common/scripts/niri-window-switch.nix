{ pkgs }:
let
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  jq = "${pkgs.jq}/bin/jq";
  niri = "${pkgs.niri}/bin/niri";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
  awk = "${pkgs.gawk}/bin/awk";
in
''
  #!${pkgs.bash}/bin/bash

  notify() {
      ${notifySend} -h string:x-canonical-private-synchronous:status "Window Switcher" "$1"
  }

  WINDOWS_JSON="$(${niri} msg -j windows 2>/dev/null)"
  if [ -z "$WINDOWS_JSON" ]; then
      notify "Could not read niri windows"
      exit 1
  fi

  ENTRIES="$(printf '%s\n' "$WINDOWS_JSON" | ${jq} -r '
      def clean:
          tostring
          | gsub("[\t\r\n]+"; " ")
          | gsub("^ +| +$"; "");

      (.windows? // .)[]
      | (.workspace_id // "?" | tostring) as $workspace
      | ((.title // "Untitled") | clean) as $title
      | "\(.id)\t[\($workspace)] \($title)"
  ' | ${awk} -F '\t' '
      NF >= 2 {
          rows[++n] = $0
          labels[n] = $2
          counts[$2]++
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
      notify "No open windows"
      exit 0
  fi

  SELECTED="$(printf '%s\n' "$ENTRIES" | ${awk} -F '\t' '{ print $2 }' | ${fuzzel} -d --no-sort -p "Focus a window: " -w 80 || true)"
  if [ -z "$SELECTED" ]; then
      exit 0
  fi

  SELECTED_ENTRY="$(printf '%s\n' "$ENTRIES" | ${awk} -F '\t' -v selected="$SELECTED" '$2 == selected { print; exit }')"
  if [ -z "$SELECTED_ENTRY" ]; then
      notify "Could not parse selection"
      exit 1
  fi

  IFS=$'\t' read -r TARGET_ID _ <<< "$SELECTED_ENTRY"
  ${niri} msg action focus-window --id "$TARGET_ID"
''
