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
  TEST_ONCE="''${BATTERY_CHECK_TEST_ONCE:-0}"
  NOTIFIED_LEVEL=0
  SLEEP_ACTION_TAKEN=0

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
      else
          read -r STATUS < "$BAT_PATH/status"
          case "$STATUS" in
              Charging|Full|"Not charging") AC_ONLINE=1 ;;
              Discharging) AC_ONLINE=0 ;;
              *)
                  AC_ONLINE=0

                  # If the battery driver is unsure, consider any online
                  # non-battery power supply to be external power.
                  for online_file in /sys/class/power_supply/*/online; do
                      [ -r "$online_file" ] || continue
                      supply_path="''${online_file%/online}"
                      [ "$supply_path" = "$BAT_PATH" ] && continue
                      read -r ONLINE < "$online_file"
                      if [ "$ONLINE" = "1" ]; then
                          AC_ONLINE=1
                          break
                      fi
                  done
                  ;;
          esac
      fi
  }

  sleep_system() {
      if [ "$TEST_MODE" = "1" ]; then
          echo "battery-check test: would hibernate now"
      else
          if ! ${pkgs.systemd}/bin/systemctl hibernate; then
              ${pkgs.libnotify}/bin/notify-send \
                  --app-name=battery-check \
                  --hint=string:x-canonical-private-synchronous:battery-warning \
                  --urgency critical \
                  "Hibernation deferred" \
                  "A logind inhibitor may be active. Save work and connect power."
          fi
      fi
  }

  send_battery_notification() {
      urgency="$1"
      summary="$2"
      body="$3"

      if [ "$TEST_MODE" = "1" ]; then
          echo "battery-check test: $urgency: $summary: $body"
      else
          ${pkgs.libnotify}/bin/notify-send \
              --app-name=battery-check \
              --hint=string:x-canonical-private-synchronous:battery-warning \
              --urgency "$urgency" \
              "$summary" "$body"
      fi
  }

  check_battery() {
      read_capacity
      read_ac_state

      if [ "$AC_ONLINE" = "1" ]; then
          NOTIFIED_LEVEL=0
          SLEEP_ACTION_TAKEN=0
          return
      fi

      if [ "$CAPACITY" -le 5 ]; then
          if [ "$SLEEP_ACTION_TAKEN" -eq 0 ]; then
              SLEEP_ACTION_TAKEN=1
              NOTIFIED_LEVEL=4
              sleep_system
          fi
      elif [ "$CAPACITY" -le 10 ] && [ "$NOTIFIED_LEVEL" -lt 3 ]; then
          send_battery_notification critical "Battery critical" \
              "Battery is at ''${CAPACITY}%. Connect the charger; hibernation starts at 5%."
          NOTIFIED_LEVEL=3
      elif [ "$CAPACITY" -le 15 ] && [ "$NOTIFIED_LEVEL" -lt 2 ]; then
          send_battery_notification normal "Battery low" \
              "Battery is at ''${CAPACITY}%."
          NOTIFIED_LEVEL=2
      elif [ "$CAPACITY" -le 20 ] && [ "$NOTIFIED_LEVEL" -lt 1 ]; then
          send_battery_notification normal "Battery low" \
              "Battery is at ''${CAPACITY}%."
          NOTIFIED_LEVEL=1
      elif [ "$CAPACITY" -gt 20 ]; then
          NOTIFIED_LEVEL=0
          SLEEP_ACTION_TAKEN=0
      fi
  }

  while :; do
      check_battery
      [ "$TEST_ONCE" = "1" ] && exit 0

      # Tethys does not reliably emit a power-supply uevent when its reported
      # capacity changes. Poll sysfs so threshold crossings cannot be missed.
      ${pkgs.coreutils}/bin/sleep 30
  done
''
