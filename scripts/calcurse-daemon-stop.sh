set -euo pipefail
pid="${XDG_DATA_HOME:-$HOME/.local/share}/calcurse/.daemon.pid"
[ -e "$pid" ] || exit 0
kill "$(cat "$pid")" 2>/dev/null || true
