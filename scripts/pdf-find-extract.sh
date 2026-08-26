set -euo pipefail
file="${1:-}"
[ -n "$file" ] || exit 0
cache="${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"

key=$(printf '%s' "$file" | sha256sum | cut -c1-32)
record="$cache/meta/$key"
text="$cache/text/$key.txt"

stamp=$(stat -c '%Y %s' "$file" 2>/dev/null) || exit 0
mtime=${stamp%% *}
size=${stamp##* }

# The record is touched even when there is nothing to do: the warm pass
# decides what to prune by looking at which records this pass left
# alone, so skipping still has to leave a mark.
if [ -f "$record" ] && [ "$(cut -f1,2 "$record" | tr '\t' ' ')" = "$stamp" ]; then
  touch "$record"
  exit 0
fi

# Half the papers worth searching are called 2301.04567v2.pdf, so the
# author's name exists nowhere but here. fzf will not match text it does
# not display, so this is appended to the end of a row rather than
# hidden in a field of its own: past the page text, where it is matched
# but effectively never seen.
blob=$( { pdfinfo "$file" 2>/dev/null || true; } | awk '
  /^(Title|Author|Subject|Keywords):/ {
    sub(/^[^:]*:[[:space:]]*/, "")
    if (length($0) > 0) fields[n++] = $0
  }
  END {
    out = ""
    for (i = 0; i < n; i++) out = out " " fields[i]
    gsub(/[[:space:]]+/, " ", out)
    sub(/^ /, "", out)
    print out
  }
')

pages=$( { pdfinfo "$file" 2>/dev/null || true; } | awk '
  /^Pages:/ { print $2; exit }
')
[ -n "$pages" ] || pages=0

# One line per page, so that line N of the cache is page N of the
# document -- which is what lets the preview find a page with a single
# `sed -n`, and what makes a result address something sioyek can
# actually open. Empty pages are still printed, because a gap would
# slide every page after it out of alignment.
status=ok
if ! timeout 60 pdftotext -q -eol unix "$file" - 2>/dev/null | awk -v pages="$pages" '
  function emit(  t) {
    if (pages > 0 && page > pages) { buf = ""; return }
    t = buf
    gsub(/[[:space:]]+/, " ", t)
    sub(/^ /, "", t)
    sub(/ $/, "", t)
    print page "\t" t
    buf = ""
  }
  BEGIN { page = 1; buf = "" }
  {
    n = split($0, part, /\f/)
    for (i = 1; i <= n; i++) {
      if (i > 1) { emit(); page++ }
      buf = buf " " part[i]
    }
  }
  END {
    emit()
    while (page < pages) { page++; print page "\t" }
  }
' >"$text.$$"; then
  status=fail
fi

# Nothing came out: a scan with no text layer, or a document pdftotext
# will not open. The answer will be the same next time, so the record
# remembers it and the file is not tried again until it changes on disk.
if [ "$status" = ok ] \
  && awk -F'\t' 'length($2) > 0 { found = 1 } END { exit found ? 0 : 1 }' "$text.$$"; then
  mv -f "$text.$$" "$text"
else
  if [ "$status" = ok ]; then status=empty; fi
  rm -f "$text.$$" "$text"
fi

printf '%s\t%s\t%s\t%s\t%s\n' "$mtime" "$size" "$status" "$blob" "$file" >"$record.$$"
mv -f "$record.$$" "$record"
