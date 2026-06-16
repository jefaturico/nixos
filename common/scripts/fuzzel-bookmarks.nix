{ pkgs }:
let
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  awk = "${pkgs.gawk}/bin/awk";
in
''
  #!${pkgs.bash}/bin/bash

  BOOKMARK_FILE="$HOME/nixos/common/bookmarks.txt"
  if [ ! -f "$BOOKMARK_FILE" ]; then
      ${pkgs.libnotify}/bin/notify-send "Bookmarks" "Bookmark file not found: $BOOKMARK_FILE"
      exit 1
  fi

  SELECTED="$(${awk} '{ url=$NF; sub(/[[:space:]][^[:space:]]+$/, ""); print }' "$BOOKMARK_FILE" | ${fuzzel} -d --no-sort -p "Bookmarks: " -w 50 || true)"
  if [ -z "$SELECTED" ]; then
      exit 0
  fi

  URL="$(${awk} -v selected="$SELECTED" '
      {
          url=$NF
          label=$0
          sub(/[[:space:]][^[:space:]]+$/, "", label)
          if (label == selected) {
              print url
              exit
          }
      }
  ' "$BOOKMARK_FILE")"

  if [ -z "$URL" ]; then
      URL="https://duckduckgo.com/?q=''${SELECTED// /+}"
  fi

  setsid xdg-open "$URL" >/dev/null 2>&1 &
''
