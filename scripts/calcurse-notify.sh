set -euo pipefail
next=$(calcurse --next | tail -n +2 | sed 's/^[[:space:]]*//')
[ -n "$next" ] || exit 0
notify-send \
  --app-name=calcurse \
  --expire-time=20000 \
  "Upcoming" "$next"
