{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  set -eu
  export LC_ALL=C

  WALL_DIR="$HOME/images/wallpapers"
  STARTUP_SCRIPT="$HOME/.wbg"
  PATH_STORAGE="$HOME/.wbg_path"
  FILELIST_CACHE="$HOME/.cache/wlsetbg_filelist"
  RANDOM_QUEUE="$HOME/.cache/wlsetbg_random_queue"
  RANDOM_LOCK="$HOME/.cache/wlsetbg_random_queue.lock"
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


  get_file_list() {
      WALL_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$WALL_DIR" 2>/dev/null || echo 0)
      CACHE_MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$FILELIST_CACHE" 2>/dev/null || echo 0)
      if [ "$WALL_MTIME" -gt "$CACHE_MTIME" ] || [ ! -s "$FILELIST_CACHE" ]; then
          ${pkgs.fd}/bin/fd --type f --absolute-path . "$WALL_DIR" > "$FILELIST_CACHE"
      fi
      cat "$FILELIST_CACHE"
  }

  refresh_random_queue() {
      TMP_QUEUE="$RANDOM_QUEUE.$$"
      get_file_list | ${pkgs.coreutils}/bin/shuf > "$TMP_QUEUE"

      FILE_COUNT=$(${pkgs.coreutils}/bin/wc -l < "$TMP_QUEUE" | ${pkgs.coreutils}/bin/tr -d ' ')
      [ "$FILE_COUNT" -gt 0 ] || exit 1

      CURRENT_PATH=""
      [ -f "$PATH_STORAGE" ] && CURRENT_PATH=$(${pkgs.coreutils}/bin/cat "$PATH_STORAGE")

      if [ "$FILE_COUNT" -gt 1 ] && [ -n "$CURRENT_PATH" ]; then
          FIRST_PATH=$(${pkgs.gnused}/bin/sed -n '1p' "$TMP_QUEUE")
          if [ "$FIRST_PATH" = "$CURRENT_PATH" ]; then
              TMP_REORDER="$RANDOM_QUEUE.reorder.$$"
              ${pkgs.coreutils}/bin/tail -n +2 "$TMP_QUEUE" > "$TMP_REORDER"
              printf '%s\n' "$FIRST_PATH" >> "$TMP_REORDER"
              ${pkgs.coreutils}/bin/mv "$TMP_REORDER" "$TMP_QUEUE"
          fi
      fi

      ${pkgs.coreutils}/bin/mv "$TMP_QUEUE" "$RANDOM_QUEUE"
  }

  select_random_wallpaper() {
      while :; do
          [ -s "$RANDOM_QUEUE" ] || refresh_random_queue

          SELECTED_PATH=$(${pkgs.gnused}/bin/sed -n '1p' "$RANDOM_QUEUE")
          TMP_QUEUE="$RANDOM_QUEUE.$$"
          ${pkgs.coreutils}/bin/tail -n +2 "$RANDOM_QUEUE" > "$TMP_QUEUE"
          ${pkgs.coreutils}/bin/mv "$TMP_QUEUE" "$RANDOM_QUEUE"

          CURRENT_PATH=""
          [ -f "$PATH_STORAGE" ] && CURRENT_PATH=$(${pkgs.coreutils}/bin/cat "$PATH_STORAGE")
          FILE_COUNT=$(get_file_list | ${pkgs.coreutils}/bin/wc -l | ${pkgs.coreutils}/bin/tr -d ' ')
          if [ "$FILE_COUNT" -gt 1 ] && [ "$SELECTED_PATH" = "$CURRENT_PATH" ]; then
              continue
          fi

          [ -f "$SELECTED_PATH" ] && {
              printf '%s\n' "$SELECTED_PATH"
              return 0
          }

          ${pkgs.coreutils}/bin/rm -f "$FILELIST_CACHE"
      done
  }

  select_random_wallpaper_locked() {
      while ! ${pkgs.coreutils}/bin/mkdir "$RANDOM_LOCK" 2>/dev/null; do
          ${pkgs.coreutils}/bin/sleep 0.1
      done
      trap '${pkgs.coreutils}/bin/rmdir "$RANDOM_LOCK"' EXIT INT TERM
      select_random_wallpaper
  }

  if [ "$RANDOM_MODE" -eq 1 ]; then
      FULL_PATH=$(select_random_wallpaper_locked)
  else
      CURRENT_WALLPAPER="None"
      if [ -f "$PATH_STORAGE" ]; then
          STORED_WALLPAPER=$(${pkgs.coreutils}/bin/cat "$PATH_STORAGE")
          case "$STORED_WALLPAPER" in
              "$WALL_DIR"/*) CURRENT_WALLPAPER=$(${pkgs.coreutils}/bin/realpath --relative-to="$WALL_DIR" "$STORED_WALLPAPER" 2>/dev/null || ${pkgs.coreutils}/bin/basename "$STORED_WALLPAPER") ;;
              *) CURRENT_WALLPAPER=$(${pkgs.coreutils}/bin/basename "$STORED_WALLPAPER") ;;
          esac
      fi
      CHOICE=$(
          {
              printf '%s\n' "Random Wallpaper"
              get_file_list | while IFS= read -r WALLPAPER_PATH; do ${pkgs.coreutils}/bin/basename "$WALLPAPER_PATH"; done
          } | ${pkgs.fuzzel}/bin/fuzzel -d -w 80 -p "Wallpaper (current: $CURRENT_WALLPAPER): "
      )
      [ -z "$CHOICE" ] && exit 0
      if [ "$CHOICE" = "Random Wallpaper" ]; then
          RANDOM_MODE=1
          FULL_PATH=$(select_random_wallpaper_locked)
      else
          FULL_PATH=$(get_file_list | while IFS= read -r WALLPAPER_PATH; do
              [ "$(${pkgs.coreutils}/bin/basename "$WALLPAPER_PATH")" = "$CHOICE" ] || continue
              printf '%s\n' "$WALLPAPER_PATH"
              break
          done)
      fi
  fi

  [ -f "$FULL_PATH" ] || exit 1

  # Apply Wallpaper
  ${pkgs.procps}/bin/pkill -x wbg || true
  ${pkgs.wbg}/bin/wbg "$FULL_PATH" > /dev/null 2>&1 &
  echo "$FULL_PATH" > "$PATH_STORAGE"
  if [ "$RANDOM_MODE" -eq 1 ]; then
      NEW_WALLPAPER=$(${pkgs.coreutils}/bin/realpath --relative-to="$WALL_DIR" "$FULL_PATH" 2>/dev/null || ${pkgs.coreutils}/bin/basename "$FULL_PATH")
      ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:wlsetbg-random "Wallpaper Applied" "$NEW_WALLPAPER"
  fi

  # Update Dynamic theme if active
  if [ -f "$STATE_FILE" ]; then
      . "$STATE_FILE"
      CUR_MODE=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme || echo "'prefer-dark'")
      [ "$CUR_MODE" = "'prefer-dark'" ] && THEME="$DARK_THEME" || THEME="$LIGHT_THEME"
      if [ "$THEME" = "Dynamic" ]; then
          ${pkgs.wallust}/bin/wallust run -q "$FULL_PATH" && \
          { ${pkgs.systemd}/bin/systemctl --user kill --kill-whom=main --signal=SIGUSR1 foot-server.service 2>/dev/null || true; } && \
          ${pkgs.mako}/bin/makoctl reload &
      fi
  fi

  # Save startup script
  printf '%s\n' "${pkgs.wbg}/bin/wbg \"$FULL_PATH\" &" > "$STARTUP_SCRIPT"
  ${pkgs.coreutils}/bin/chmod +x "$STARTUP_SCRIPT"
''
