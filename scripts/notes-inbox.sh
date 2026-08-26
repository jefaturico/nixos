set -euo pipefail
file="$HOME/documents/notes/inbox.md"
mkdir -p "$(dirname "$file")"
touch "$file"

# What the previous run left behind is trimmed rather than counted on:
# its two blank lines if the entry was typed into, and the heading as
# well if it was not. Without this the spacing drifts a line per visit
# and every abandoned press leaves a dated heading over nothing.
body=$(awk '
  { line[NR] = $0 }
  END {
    n = NR
    while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--
    if (n > 0 && line[n] ~ /^#+ /) {
      n--
      while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--
    }
    for (i = 1; i <= n; i++) print line[i]
  }
' "$file")

{
  if [ -n "$body" ]; then
    printf '%s\n\n' "$body"
  fi
  printf '## %s\n\n\n' "$(date '+%Y-%m-%d %H:%M')"
} >"$file.new"
mv "$file.new" "$file"

exec kitty nvim -c 'normal! G' -c startinsert "$file"
