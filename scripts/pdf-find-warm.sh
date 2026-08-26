set -euo pipefail
cache="${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"
mkdir -p "$cache/meta" "$cache/text"

# One pass at a time. A second launch while the first is still running
# has nothing to add, so it leaves rather than queues.
exec 9>"$cache/warm.lock"
flock -n 9 || exit 0

# This is the only writer of the caches below, and each lands with a
# single mv. The picker never writes them, which is why a picker killed
# the instant something is chosen cannot leave one half-written.
pdf-find-scan >"$cache/paths.new"
mv -f "$cache/paths.new" "$cache/paths"

# Every worker below leaves its record newer than this file, whether it
# rewrote it or merely skipped it, so afterwards the records older than
# the stamp are exactly the PDFs that are gone. Comparing against a file
# rather than a clock is what makes that true: `date +%s` is accurate to
# the second, and a pass over an unchanged library finishes well inside
# one, which would leave the previous pass's records looking current.
: >"$cache/stamp"

# Extraction is the expensive half and nobody is waiting for it, so it
# yields both the processor and the disk to whatever is being read.
nice -n 19 ionice -c 3 \
  xargs -r -d '\n' -n 1 -P "$(nproc)" pdf-find-extract <"$cache/paths" || true

# Whatever this pass did not touch is a PDF that is no longer there.
# Keys are hexadecimal, so there is nothing in these names to quote.
find "$cache/meta" -type f ! -newer "$cache/stamp" -printf '%f\n' \
  | while IFS= read -r stale; do
      rm -f "$cache/meta/$stale" "$cache/text/$stale.txt"
    done

# Both lists the picker reads are assembled here, with their paths and
# labels already baked in, so that switching to full-text search is a
# bare `cat` of a file rather than a walk over the library. The cost is
# paid once per pass, in the background, instead of once per keystroke.
: >"$cache/names.new"
: >"$cache/pages.new"

records=("$cache"/meta/*)
if [ -e "${records[0]}" ]; then
  awk -F'\t' \
    -v cache="$cache" \
    -v home="$HOME" \
    -v namesfile="$cache/names.new" \
    -v pagesfile="$cache/pages.new" '
    FNR == 1 {
      status = $3
      blob = $4
      path = $5
      if (path == "") next

      key = FILENAME
      sub(/.*\//, "", key)

      display = path
      sub("^" home "/", "~/", display)
      cut = length(display)
      while (cut > 0 && substr(display, cut, 1) != "/") cut--
      dir = substr(display, 1, cut)
      base = substr(display, cut + 1)
      tail = length(blob) > 0 ? "  \033[2m" blob "\033[0m" : ""

      printf "%s\t0\t\033[2m%s\033[0m%s%s\n", path, dir, base, tail > namesfile

      if (status != "ok") next

      textfile = cache "/text/" key ".txt"
      while ((getline line < textfile) > 0) {
        tab = index(line, "\t")
        if (tab == 0) continue
        pageno = substr(line, 1, tab - 1)
        body = substr(line, tab + 1)
        if (length(body) == 0) continue
        printf "%s\t%s\t\033[2m%s\033[0m \033[33mp%s\033[0m  %s%s\n", \
          path, pageno, display, pageno, body, tail > pagesfile
      }
      close(textfile)
    }
  ' "${records[@]}"
fi

mv -f "$cache/names.new" "$cache/names"
mv -f "$cache/pages.new" "$cache/pages"
