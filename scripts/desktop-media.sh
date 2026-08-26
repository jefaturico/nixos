set -euo pipefail
case "${1:-}" in
  play-pause | next | previous | stop) playerctl "$1" ;;
  *) echo 'usage: desktop-media {play-pause|next|previous|stop}' >&2; exit 2 ;;
esac

# Give the player a moment to settle before asking what it is doing.
sleep 0.2
status=$(playerctl status 2>/dev/null || echo Stopped)
case "$status" in
  Playing) summary=$(playerctl metadata --format 'Playing {{artist}} — {{title}}' 2>/dev/null || echo Playing) ;;
  Paused) summary="Paused" ;;
  *) summary="Stopped" ;;
esac
notify-send \
  --app-name=media \
  --hint=string:x-canonical-private-synchronous:media \
  --expire-time=2000 \
  "$summary"
