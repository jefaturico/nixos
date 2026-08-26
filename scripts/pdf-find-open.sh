set -euo pipefail
file="${1:-}"
page="${2:-0}"
[ -n "$file" ] || exit 0

args=(--new-window)
case "$page" in
  # Name mode has no page in particular, and passing none is the point:
  # sioyek then restores where this document was last left off.
  "" | 0 | *[!0-9]*) ;;
  *) args+=(--page "$page") ;;
esac

# `setsid --fork` returns as soon as it has forked and leaves the reader
# in a session of its own. Since fzf's `become` replaces the picker
# rather than forking it, that makes this process the terminal's last
# child -- so the window closes the instant a document is chosen,
# before sioyek has drawn its own, and takes nothing with it.
#
# Detaching the session is not enough on its own: an inherited stdout is
# still the terminal's pty, and kitty holds its window open until that
# is closed at both ends. Sioyek would keep it for as long as the
# document stayed open, printing its startup chatter into a window that
# was supposed to be gone.
exec setsid --fork sioyek "${args[@]}" "$file" \
  </dev/null >/dev/null 2>&1
