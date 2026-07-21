{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  set -eu

  BAT_PATH=""
  for path in /sys/class/power_supply/BAT*; do
      [ -r "$path/capacity" ] || continue
      BAT_PATH="$path"
      break
  done

  # Desktops and VMs often have no battery.
  [ -n "$BAT_PATH" ] || exit 0

  AC_PATH=""
  for path in /sys/class/power_supply/AC* /sys/class/power_supply/ADP* /sys/class/power_supply/ACAD; do
      [ -r "$path/online" ] || continue
      AC_PATH="$path"
      break
  done

  LAST_AC=""
  LOW_NOTIFIED=0
  CRIT_NOTIFIED=0
  BATTERY_NOTIFICATION_ID=""

  STATUS_TAG="string:x-canonical-private-synchronous:status"

  send_battery_notification() {
      urgency="$1"
      icon="$2"
      summary="$3"
      body="$4"

      if [ -n "$BATTERY_NOTIFICATION_ID" ]; then
          BATTERY_NOTIFICATION_ID="$(${pkgs.libnotify}/bin/notify-send \
              --print-id --replace-id "$BATTERY_NOTIFICATION_ID" \
              --urgency "$urgency" --icon "$icon" "$summary" "$body")"
      else
          BATTERY_NOTIFICATION_ID="$(${pkgs.libnotify}/bin/notify-send \
              --print-id --urgency "$urgency" --icon "$icon" \
              "$summary" "$body")"
      fi
  }

  clear_battery_notification() {
      if [ -n "$BATTERY_NOTIFICATION_ID" ]; then
          ${pkgs.libnotify}/bin/notify-send \
              --replace-id "$BATTERY_NOTIFICATION_ID" --expire-time 1 " " \
              >/dev/null
          BATTERY_NOTIFICATION_ID=""
      fi
  }

  while :; do
      read -r CAPACITY < "$BAT_PATH/capacity"

      if [ -n "$AC_PATH" ]; then
          read -r AC_ONLINE < "$AC_PATH/online"
      else
          read -r STATUS < "$BAT_PATH/status"
          [ "$STATUS" = "Charging" ] && AC_ONLINE=1 || AC_ONLINE=0
      fi

      if [ "$AC_ONLINE" != "$LAST_AC" ]; then
          if [ "$AC_ONLINE" = "1" ]; then
              [ -n "$LAST_AC" ] && ${pkgs.libnotify}/bin/notify-send -h "$STATUS_TAG" -i battery-charging "Charging" "Battery is now charging"
              clear_battery_notification
              LOW_NOTIFIED=0
              CRIT_NOTIFIED=0
          fi
          LAST_AC="$AC_ONLINE"
      fi

      if [ "$AC_ONLINE" = "0" ]; then
          if [ "$CAPACITY" -le 10 ] && [ "$CRIT_NOTIFIED" -eq 0 ]; then
              send_battery_notification critical battery-empty \
                  "Battery Critical" "Level: ''${CAPACITY}%"
              CRIT_NOTIFIED=1
          elif [ "$CAPACITY" -le 15 ] && [ "$LOW_NOTIFIED" -lt 2 ]; then
              send_battery_notification normal battery-low \
                  "Battery Low" "Level: ''${CAPACITY}%"
              LOW_NOTIFIED=2
          elif [ "$CAPACITY" -le 20 ] && [ "$LOW_NOTIFIED" -lt 1 ]; then
              send_battery_notification normal battery-low \
                  "Battery Low" "Level: ''${CAPACITY}%"
              LOW_NOTIFIED=1
          elif [ "$CAPACITY" -gt 20 ]; then
              LOW_NOTIFIED=0
              CRIT_NOTIFIED=0
          fi
      fi

      ${pkgs.coreutils}/bin/sleep 30
  done
''
