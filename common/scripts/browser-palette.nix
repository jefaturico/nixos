{ pkgs }:
let
  awk = "${pkgs.gawk}/bin/awk";
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  jq = "${pkgs.jq}/bin/jq";
  niri = "${pkgs.niri}/bin/niri";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
in
''
  #!${pkgs.bash}/bin/bash

  BOOKMARK_FILE="$HOME/nixos/common/bookmarks.txt"

  notify() {
      ${notifySend} -h string:x-canonical-private-synchronous:browser "Browser" "$1"
  }

  focus_window() {
      ${niri} msg action focus-window --id "$1"
  }

  open_url() {
      setsid chromium-app "$1" >/dev/null 2>&1 &
  }

  WINDOWS_JSON="$(${niri} msg -j windows 2>/dev/null)"
  if [ -z "$WINDOWS_JSON" ]; then
      notify "Could not read niri windows"
      exit 1
  fi

  ENTRIES="$(
      {
          printf '%s\n' "$WINDOWS_JSON" | ${jq} -r '
              def clean:
                  tostring
                  | gsub("[\t\r\n]+"; " ")
                  | gsub("^ +| +$"; "");

              def browser_app_id:
                  . == "chromium" or
                  . == "chromium-browser" or
                  . == "ungoogled-chromium" or
                  . == "chromium-app" or
                  startswith("chrome-");

              [
                  (.windows? // .)[]
                  | select((.app_id // "") | browser_app_id)
              ]
              | sort_by(.focus_timestamp.secs // 0, .focus_timestamp.nanos // 0)
              | reverse
              | .[]
              | ((.title // "Untitled") | clean) as $title
              | "window\t\(.id)\tWindow: \($title)"
          '

          if [ -f "$BOOKMARK_FILE" ]; then
              ${awk} '
          NF >= 2 {
              url=$NF
              label=$0
              sub(/[[:space:]][^[:space:]]+$/, "", label)
              gsub(/[\t\r\n]+/, " ", label)
              gsub(/^ +| +$/, "", label)
              print "bookmark" "\t" url "\tBookmark: " label
          }
      ' "$BOOKMARK_FILE"
          fi
      }
  )"

  SELECTED="$(printf '%s\n' "$ENTRIES" | ${fuzzel} -d --no-sort --match-mode=exact --with-nth=3 --match-nth=3 -p "Browser: " -w 80 || true)"
  if [ -z "$SELECTED" ]; then
      exit 0
  fi

  IFS=$'\t' read -r ACTION TARGET _LABEL <<< "$SELECTED"

  case "$ACTION" in
      window)
          focus_window "$TARGET"
          ;;
      bookmark)
          open_url "$TARGET"
          ;;
      *)
          open_url "$SELECTED"
          ;;
  esac
''
