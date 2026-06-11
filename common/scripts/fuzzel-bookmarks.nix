{ pkgs }:
let
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
in
''
  #!${pkgs.bash}/bin/bash
  # Robust Wayland bookmarks script with logging
  
  LOG_FILE="/tmp/fuzzel-bookmarks.log"
  echo "--- $(date) ---" > "$LOG_FILE"
  
  # Ensure we have a Wayland display if possible
  if [ -z "$WAYLAND_DISPLAY" ]; then
      echo "WARNING: WAYLAND_DISPLAY is not set. Fuzzel might fail." >> "$LOG_FILE"
  else
      echo "INFO: WAYLAND_DISPLAY is set to $WAYLAND_DISPLAY" >> "$LOG_FILE"
  fi
  
  BOOKMARK_FILE="$HOME/nixos/common/bookmarks.txt"
  if [ ! -f "$BOOKMARK_FILE" ]; then
      echo "ERROR: Bookmark file $BOOKMARK_FILE not found." >> "$LOG_FILE"
      exit 1
  fi

  # Pick a bookmark or enter a query
  echo "INFO: Running fuzzel..." >> "$LOG_FILE"
  SELECTED=$(${pkgs.gawk}/bin/awk '{for(i=1;i<NF;i++) printf "%s%s", $i, (i==NF-1?"":" "); print ""}' "$BOOKMARK_FILE" | ${fuzzel} -d -p "Bookmarks: " -w 50 2>> "$LOG_FILE")
  
  if [ -z "$SELECTED" ]; then
      echo "INFO: No selection made. Exiting." >> "$LOG_FILE"
      exit 0
  fi

  echo "INFO: Selected '$SELECTED'" >> "$LOG_FILE"

  # Find the URL (last column) for the selected name
  URL=$(grep -F -m 1 "$SELECTED " "$BOOKMARK_FILE" | ${pkgs.gawk}/bin/awk '{print $NF}')
  
  # If no URL found, treat as search query
  if [ -z "$URL" ]; then
      echo "INFO: No URL found for '$SELECTED', treating as search query." >> "$LOG_FILE"
      URL="https://duckduckgo.com/?q=''${SELECTED// /+}"
  fi

  echo "INFO: Opening URL: $URL" >> "$LOG_FILE"
  setsid xdg-open "$URL" >/dev/null 2>&1 &
''
