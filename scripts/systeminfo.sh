set -euo pipefail
message="It's $(date '+%I:%M %P')."
for power_supply in /sys/class/power_supply/*; do
  [ -r "$power_supply/type" ] || continue
  [ "$(<"$power_supply/type")" = "Battery" ] || continue
  [ -r "$power_supply/capacity" ] || continue
  capacity=$(<"$power_supply/capacity")
  message="$message Battery is at $capacity%."
  break
done
notify-send \
  --app-name=systeminfo \
  --hint=string:x-canonical-private-synchronous:systeminfo \
  --expire-time=5000 \
  "$message"
