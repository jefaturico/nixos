set -euo pipefail
exec fd \
  --type f \
  --extension pdf \
  --no-ignore-vcs \
  --exclude node_modules \
  --exclude .venv \
  --exclude venv \
  --exclude result \
  --exclude 'result-*' \
  . "$HOME"
