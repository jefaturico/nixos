set -euo pipefail
file="$HOME/documents/notes/tasks.md"
mkdir -p "$(dirname "$file")"
touch "$file"
exec kitty nvim "$file"
