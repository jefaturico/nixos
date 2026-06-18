{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  DB_PATH="''${XDG_DATA_HOME:-$HOME/.local/share}/sioyek/shared.db"
  CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/wdoc-find"
  MAP_CACHE="$CACHE_DIR/map.tsv"
  refresh_cache() {
      mkdir -p "$CACHE_DIR"
      HIST_CACHE="$CACHE_DIR/hist.$$"
      TMP_CACHE="$CACHE_DIR/map.$$.tmp"

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
              n = split(path, parts, "/")
              bname = parts[n]
              print s_time "\t" t "\t" bname "\t" path
          }
      ' | ${pkgs.coreutils}/bin/sort -t'	' -rn | ${pkgs.coreutils}/bin/cut -f3- > "$TMP_CACHE"

      mv "$TMP_CACHE" "$MAP_CACHE"
      rm -f "$HIST_CACHE"
  }

  case "''${1:-}" in
      --refresh)
          refresh_cache
          exit 0
          ;;
  esac

  if [ ! -s "$MAP_CACHE" ]; then
      refresh_cache
  fi

  FILE=$(${pkgs.fuzzel}/bin/fuzzel -d --no-sort --with-nth=1 --match-nth=1 --accept-nth=2 -p "Select Document: " -w 70 < "$MAP_CACHE")

  if [ -n "$FILE" ] && [ -f "$FILE" ]; then
      exec setsid ${pkgs.sioyek}/bin/sioyek "$FILE" >/dev/null 2>&1
  fi
''
