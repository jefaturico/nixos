set -euo pipefail
case "${1:-}" in
  up) brightnessctl --class=backlight set 10%+ >/dev/null ;;
  down) brightnessctl --class=backlight set 10%- >/dev/null ;;
  *) echo 'usage: desktop-brightness {up|down}' >&2; exit 2 ;;
esac
percent=$(brightnessctl --machine-readable --class=backlight info \
  | awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }')
notify-send \
  --app-name=brightness \
  --hint=string:x-canonical-private-synchronous:brightness \
  --hint="int:value:$percent" \
  --expire-time=400 \
  "Brightness $percent%"
