{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  DB_PATH="''${XDG_DATA_HOME:-$HOME/.local/share}/sioyek/shared.db"
  CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/wdoc-find"
  MAP_CACHE="$CACHE_DIR/map.tsv"
  VERSION_CACHE="$CACHE_DIR/version"
  CACHE_VERSION="3"

  refresh_cache() {
      mkdir -p "$CACHE_DIR"
      HIST_CACHE="$CACHE_DIR/hist.$$"
      TMP_CACHE="$CACHE_DIR/map.$$.tmp"
      trap 'rm -f "$HIST_CACHE" "$TMP_CACHE"' EXIT HUP INT TERM

      if [ -f "$DB_PATH" ]; then
          ${pkgs.sqlite}/bin/sqlite3 -separator '' "$DB_PATH" "SELECT path, COALESCE(strftime('%s', last_access_time), 0) FROM opened_books" > "$HIST_CACHE" 2>/dev/null
      else
          : > "$HIST_CACHE"
      fi

      {
          ${pkgs.gawk}/bin/awk -F'' '{print "H\t" $2 "\t" $1}' "$HIST_CACHE"
          ${pkgs.findutils}/bin/find -L "$HOME/documents" "$HOME/downloads" "$HOME/projects" -maxdepth 4 -type f -name "*.pdf" -printf "F\t%T@\t%p\n" 2>/dev/null
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
      printf '%s\n' "$CACHE_VERSION" > "$VERSION_CACHE"
      rm -f "$HIST_CACHE"
      trap - EXIT HUP INT TERM
  }

  cache_is_stale() {
      [ ! -s "$MAP_CACHE" ] && return 0
      [ "$(${pkgs.coreutils}/bin/cat "$VERSION_CACHE" 2>/dev/null)" = "$CACHE_VERSION" ] || return 0
      [ -f "$DB_PATH" ] && [ "$DB_PATH" -nt "$MAP_CACHE" ] && return 0

      [ -n "$(${pkgs.findutils}/bin/find -L "$HOME/documents" "$HOME/downloads" "$HOME/projects" -maxdepth 4 -type d -newer "$MAP_CACHE" -print -quit 2>/dev/null)" ]
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
      exec setsid ${pkgs.sioyek}/bin/sioyek "$FILE" >/dev/null 2>&1
  fi
''
