set -euo pipefail
setsid --fork pdf-find-warm >/dev/null 2>&1 || true

exec kitty \
  --class=com.mitchellh.kitty.PdfFind \
  --title="Find PDF" \
  pdf-find-pick
