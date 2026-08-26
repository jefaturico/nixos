set -euo pipefail
path="${1:-}"
page="${2:-0}"
query="${3:-}"
[ -n "$path" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"
key=$(printf '%s' "$path" | sha256sum | cut -c1-32)
record="$cache/meta/$key"
text="$cache/text/$key.txt"
width="${FZF_PREVIEW_COLUMNS:-80}"

if [ -f "$record" ]; then
  cut -f4 "$record"
  printf '\n'
fi

# Never extract from here. Holding an arrow key down over a cold list
# would fork pdftotext once per repeat; the warm pass will get to it.
if [ ! -f "$text" ]; then
  printf '(not indexed yet)\n'
  exit 0
fi

# A line is a page, so page N is line N -- except in name mode, where
# there is no page in particular and the opening pages are what say
# what the document is.
if [ "$page" = 0 ]; then
  body=$(sed -n '1,3p' "$text")
else
  body=$(sed -n "${page}p" "$text")
fi

# fzf's operators are part of the query, not of the words being looked
# for, so they come off before the terms are turned into an alternation.
read -r -a terms <<<"$query"
pattern=""
for term in ${terms[@]+"${terms[@]}"}; do
  # A negated term is the reason a page is *not* excluded, so there is
  # nothing in it to point at.
  case "$term" in !*) continue ;; esac
  term=${term#\'}
  term=${term#^}
  term=${term%\$}
  [ -n "$term" ] || continue
  term=$(printf '%s' "$term" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
  if [ -n "$pattern" ]; then pattern="$pattern|$term"; else pattern="$term"; fi
done

if [ -n "$pattern" ]; then
  printf '%s\n' "$body" | cut -f2- | fold -s -w "$width" \
    | rg --passthru --color=always --smart-case -e "$pattern" || true
else
  printf '%s\n' "$body" | cut -f2- | fold -s -w "$width"
fi
