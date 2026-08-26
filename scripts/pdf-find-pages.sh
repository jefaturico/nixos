set -euo pipefail
cache="${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"
cat "$cache/pages" 2>/dev/null || true
