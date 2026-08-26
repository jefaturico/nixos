set -euo pipefail
cache="${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"

# The cached list goes out first and unconditionally: fzf draws the
# moment the first line lands, so the window is usable before the scan
# behind it has looked at a single directory. Anything the scan turns
# up that the cache has not seen yet arrives without its metadata,
# which is why the deduplication keeps the first record for a path and
# not the last. It is awk's rather than `sort -u` because sort has to
# read the whole stream before it prints anything, which is the one
# thing this must not do.
#
# The scan runs every time, including when the picker is only switching
# back from full-text search. It costs a few milliseconds against a warm
# dentry cache, and it means the list is never the empty one a library
# that has not finished its first pass would otherwise hand back.
{
  cat "$cache/names" 2>/dev/null || true
  pdf-find-scan | awk -v home="$HOME" '
    {
      display = $0
      sub("^" home "/", "~/", display)
      cut = length(display)
      while (cut > 0 && substr(display, cut, 1) != "/") cut--
      printf "%s\t0\t\033[2m%s\033[0m%s\n", \
        $0, substr(display, 1, cut), substr(display, cut + 1)
    }
  '
} | awk -F'\t' '!seen[$1]++'
