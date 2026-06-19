{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  DB_PATH="''${XDG_DATA_HOME:-$HOME/.local/share}/zathura/bookmarks.sqlite"
  CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/wdoc-find"
  MAP_CACHE="$CACHE_DIR/map.tsv"
  INDEX_CACHE="$CACHE_DIR/index.tsv"
  VERSION_CACHE="$CACHE_DIR/version"
  CACHE_VERSION="7"

  find_documents() {
      ${pkgs.findutils}/bin/find -L "$HOME/documents" "$HOME/downloads" "$HOME/projects" \
          -type f \
          -iname "*.pdf" \
          -printf "%p\n" 2>/dev/null \
          | ${pkgs.coreutils}/bin/sort
  }

  refresh_cache() {
      mkdir -p "$CACHE_DIR"
      HIST_CACHE="$CACHE_DIR/hist.$$"
      TMP_CACHE="$CACHE_DIR/map.$$.tmp"
      TMP_INDEX="$CACHE_DIR/index.$$.tmp"
      trap 'rm -f "$HIST_CACHE" "$TMP_CACHE" "$TMP_INDEX"' EXIT HUP INT TERM

      if [ -f "$DB_PATH" ]; then
          ${pkgs.sqlite}/bin/sqlite3 -separator '' "$DB_PATH" "SELECT file, COALESCE(time, 0) FROM fileinfo" > "$HIST_CACHE" 2>/dev/null
      else
          : > "$HIST_CACHE"
      fi

      find_documents > "$TMP_INDEX"

      {
          ${pkgs.gawk}/bin/awk -F'' '{print "H\t" $2 "\t" $1}' "$HIST_CACHE"
          ${pkgs.findutils}/bin/find -L "$HOME/documents" "$HOME/downloads" "$HOME/projects" -type f -iname "*.pdf" -printf "F\t%T@\t%p\n" 2>/dev/null
      } | ${pkgs.gawk}/bin/awk -F'\t' '
          /^H/ {
              hist[$3] = $2
              next
          }
          /^F/ {
              t = $2
              path = $3
              s_time = hist[path] ? hist[path] : 0

              display = path
              home = ENVIRON["HOME"]
              if (home != "") {
                  prefix = home "/"
                  if (path == home) {
                      display = "~"
                  } else if (index(path, prefix) == 1) {
                      display = "~/" substr(path, length(prefix) + 1)
                  }
              }

              print s_time "\t" t "\t" display "\t" display "\t" path
          }
      ' | ${pkgs.coreutils}/bin/sort -t'	' -rn | ${pkgs.coreutils}/bin/cut -f3- > "$TMP_CACHE"

      mv "$TMP_CACHE" "$MAP_CACHE"
      mv "$TMP_INDEX" "$INDEX_CACHE"
      printf '%s\n' "$CACHE_VERSION" > "$VERSION_CACHE"
      rm -f "$HIST_CACHE"
      trap - EXIT HUP INT TERM
  }

  cache_is_stale() {
      [ ! -s "$MAP_CACHE" ] && return 0
      [ ! -s "$INDEX_CACHE" ] && return 0
      [ "$(${pkgs.coreutils}/bin/cat "$VERSION_CACHE" 2>/dev/null)" = "$CACHE_VERSION" ] || return 0
      [ -f "$DB_PATH" ] && [ "$DB_PATH" -nt "$MAP_CACHE" ] && return 0

      TMP_INDEX="$CACHE_DIR/index-check.$$"
      trap 'rm -f "$TMP_INDEX"' EXIT HUP INT TERM
      find_documents > "$TMP_INDEX"
      ${pkgs.diffutils}/bin/cmp -s "$INDEX_CACHE" "$TMP_INDEX"
      status="$?"
      rm -f "$TMP_INDEX"
      trap - EXIT HUP INT TERM
      [ "$status" -ne 0 ]
  }

  case "''${1:-}" in
      -r|--refresh)
          refresh_cache
          exit 0
          ;;
  esac

  if cache_is_stale; then
      refresh_cache
  fi

  FILE="$(${pkgs.fuzzel}/bin/fuzzel -d --no-sort --with-nth=1 --match-nth=2 --accept-nth=3 -p "Select Document: " -w 100 < "$MAP_CACHE")"

  if [ -n "$FILE" ] && [ -f "$FILE" ]; then
      exec setsid ${pkgs.zathura}/bin/zathura "$FILE" >/dev/null 2>&1
  fi
''
