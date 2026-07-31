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

  TEST_MODE="''${BATTERY_CHECK_TEST_MODE:-0}"
  SUSPEND_DELAY="''${BATTERY_CHECK_SUSPEND_DELAY:-60}"

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
  BATTERY_CRITICAL_ACK="$XDG_RUNTIME_DIR/battery-critical-ack"
  BATTERY_CRITICAL_PENDING="$XDG_RUNTIME_DIR/battery-critical-pending"

  STATUS_TAG="string:x-canonical-private-synchronous:status"
  BATTERY_CRITICAL_TAG="string:x-jf-battery-critical:guard"

  read_capacity() {
      if [ -n "''${BATTERY_CHECK_TEST_CAPACITY:-}" ]; then
          CAPACITY="$BATTERY_CHECK_TEST_CAPACITY"
      else
          read -r CAPACITY < "$BAT_PATH/capacity"
      fi
  }

  read_ac_state() {
      if [ -n "''${BATTERY_CHECK_TEST_AC_ONLINE:-}" ]; then
          AC_ONLINE="$BATTERY_CHECK_TEST_AC_ONLINE"
      elif [ -n "$AC_PATH" ]; then
          read -r AC_ONLINE < "$AC_PATH/online"
      else
          read -r STATUS < "$BAT_PATH/status"
          [ "$STATUS" = "Charging" ] && AC_ONLINE=1 || AC_ONLINE=0
      fi
  }

  suspend_system() {
      if [ "$TEST_MODE" = "1" ]; then
          echo "battery-check test: would suspend now"
      else
          ${pkgs.systemd}/bin/systemctl --check-inhibitors=no suspend
      fi
  }

  send_battery_notification() {
      urgency="$1"
      summary="$2"
      body="$3"

      if [ -n "$BATTERY_NOTIFICATION_ID" ]; then
          BATTERY_NOTIFICATION_ID="$(${pkgs.libnotify}/bin/notify-send \
              --print-id --replace-id "$BATTERY_NOTIFICATION_ID" \
              --urgency "$urgency" "$summary" "$body")"
      else
          BATTERY_NOTIFICATION_ID="$(${pkgs.libnotify}/bin/notify-send \
              --print-id --urgency "$urgency" \
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

  guard_critical_battery() {
      rm -f "$BATTERY_CRITICAL_ACK"
      : > "$BATTERY_CRITICAL_PENDING"

      if [ -n "$BATTERY_NOTIFICATION_ID" ]; then
          BATTERY_NOTIFICATION_ID="$(${pkgs.libnotify}/bin/notify-send \
              --print-id --replace-id "$BATTERY_NOTIFICATION_ID" \
              --urgency critical \
              --hint "$BATTERY_CRITICAL_TAG" \
              "Battery Critical" \
              "Level: ''${CAPACITY}%. Confirm in Emacs within ''${SUSPEND_DELAY} seconds to keep running.")"
      else
          BATTERY_NOTIFICATION_ID="$(${pkgs.libnotify}/bin/notify-send \
              --print-id --urgency critical \
              --hint "$BATTERY_CRITICAL_TAG" \
              "Battery Critical" \
              "Level: ''${CAPACITY}%. Confirm in Emacs within ''${SUSPEND_DELAY} seconds to keep running.")"
      fi

      ${pkgs.coreutils}/bin/sleep "$SUSPEND_DELAY"
      rm -f "$BATTERY_CRITICAL_PENDING"

      read_capacity
      read_ac_state

      if [ "$AC_ONLINE" = "0" ] \
          && [ "$CAPACITY" -le 10 ] \
          && [ ! -e "$BATTERY_CRITICAL_ACK" ]; then
          suspend_system
      elif [ "$TEST_MODE" = "1" ] && [ -e "$BATTERY_CRITICAL_ACK" ]; then
          echo "battery-check test: warning acknowledged; staying awake"
      fi
  }

  while :; do
      read_capacity
      read_ac_state

      if [ "$AC_ONLINE" != "$LAST_AC" ]; then
          if [ "$AC_ONLINE" = "1" ]; then
              [ -n "$LAST_AC" ] && ${pkgs.libnotify}/bin/notify-send -h "$STATUS_TAG" "Charging" "Battery is now charging"
              clear_battery_notification
              LOW_NOTIFIED=0
              CRIT_NOTIFIED=0
          fi
          LAST_AC="$AC_ONLINE"
      fi

      if [ "$AC_ONLINE" = "0" ]; then
          if [ "$CAPACITY" -le 10 ] && [ "$CRIT_NOTIFIED" -eq 0 ]; then
              CRIT_NOTIFIED=1
              guard_critical_battery
          elif [ "$CAPACITY" -le 15 ] && [ "$LOW_NOTIFIED" -lt 2 ]; then
              send_battery_notification normal "Battery Low" \
                  "Level: ''${CAPACITY}%"
              LOW_NOTIFIED=2
          elif [ "$CAPACITY" -le 20 ] && [ "$LOW_NOTIFIED" -lt 1 ]; then
              send_battery_notification normal "Battery Low" \
                  "Level: ''${CAPACITY}%"
              LOW_NOTIFIED=1
          elif [ "$CAPACITY" -gt 20 ]; then
              LOW_NOTIFIED=0
              CRIT_NOTIFIED=0
          fi
      fi

      ${pkgs.coreutils}/bin/sleep 30
  done
''
