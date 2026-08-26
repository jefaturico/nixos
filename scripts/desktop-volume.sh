set -euo pipefail
action="${1:-}"
target="@DEFAULT_AUDIO_SINK@"
notification_id="volume"
label="Volume"
case "$action" in
  up) wpctl set-mute "$target" 0; wpctl set-volume --limit 1.0 "$target" 10%+ ;;
  down) wpctl set-mute "$target" 0; wpctl set-volume "$target" 10%- ;;
  mute) wpctl set-mute "$target" toggle ;;
  mic-mute)
    target="@DEFAULT_AUDIO_SOURCE@"
    notification_id="microphone"
    label="Microphone"
    wpctl set-mute "$target" toggle
    ;;
  *) echo 'usage: desktop-volume {up|down|mute|mic-mute}' >&2; exit 2 ;;
esac
state=$(wpctl get-volume "$target")
percent=$(awk '{ printf "%d", $2 * 100 }' <<<"$state")
notification_args=(
  --app-name=volume
  --hint="string:x-canonical-private-synchronous:$notification_id"
  --expire-time=400
)
if grep -q '\[MUTED\]' <<<"$state"; then
  summary="$label muted"
else
  summary="$label $percent%"
  notification_args+=(--hint="int:value:$percent")
fi
notify-send "${notification_args[@]}" "$summary"
