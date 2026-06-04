{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  set -eu

  # Find AC and Battery paths once
  AC_PATH=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "AC*" -o -name "ADP*" -o -name "ACAD" | ${pkgs.coreutils}/bin/head -n1)
  BAT_PATH=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" | ${pkgs.coreutils}/bin/head -n1)

  # If no battery exists, just exit (desktops)
  [ -z "$BAT_PATH" ] && exit 0

  LAST_AC=""
  LOW_NOTIFIED=0
  CRIT_NOTIFIED=0

  # Notification tags
  STATUS_TAG="string:x-canonical-private-synchronous:status"
  BATTERY_TAG="string:x-canonical-private-synchronous:battery-low"

  while true; do
      # 1. Read capacity and status using shell builtins to avoid forks
      read -r CAPACITY < "$BAT_PATH/capacity"
      
      # Check AC status (if available)
      if [ -n "$AC_PATH" ]; then
          read -r AC_ONLINE < "$AC_PATH/online"
      else
          # Fallback to battery status if no AC path found
          read -r STATUS < "$BAT_PATH/status"
          [ "$STATUS" = "Charging" ] && AC_ONLINE=1 || AC_ONLINE=0
      fi

      # 2. Handle AC state changes (Plug/Unplug)
      if [ "$AC_ONLINE" != "$LAST_AC" ]; then
          if [ "$AC_ONLINE" = "1" ]; then
              # Plugged in: Notify Charging + ALWAYS dismiss battery alerts
              [ -n "$LAST_AC" ] && ${pkgs.libnotify}/bin/notify-send -h "$STATUS_TAG" -i battery-charging "Charging" "Battery is now charging"
              ${pkgs.libnotify}/bin/notify-send -h "$BATTERY_TAG" " " -t 1 # Quick dismiss
              LOW_NOTIFIED=0
              CRIT_NOTIFIED=0
          fi
          LAST_AC="$AC_ONLINE"
      fi

      # 3. Handle Low Battery Thresholds (only if discharging)
      if [ "$AC_ONLINE" = "0" ]; then
          if [ "$CAPACITY" -le 10 ]; then
              if [ "$CRIT_NOTIFIED" -eq 0 ]; then
                  ${pkgs.libnotify}/bin/notify-send -u critical -h "$BATTERY_TAG" -i battery-empty "Battery Critical" "Level: ''${CAPACITY}%"
                  CRIT_NOTIFIED=1
              fi
          elif [ "$CAPACITY" -le 15 ]; then
              if [ "$LOW_NOTIFIED" -lt 2 ]; then
                  ${pkgs.libnotify}/bin/notify-send -u normal -h "$BATTERY_TAG" -i battery-low "Battery Low" "Level: ''${CAPACITY}%"
                  LOW_NOTIFIED=2
              fi
          elif [ "$CAPACITY" -le 20 ]; then
              if [ "$LOW_NOTIFIED" -lt 1 ]; then
                  ${pkgs.libnotify}/bin/notify-send -u normal -h "$BATTERY_TAG" -i battery-low "Battery Low" "Level: ''${CAPACITY}%"
                  LOW_NOTIFIED=1
              fi
          else
              # Reset notifications if battery goes above 20%
              LOW_NOTIFIED=0
              CRIT_NOTIFIED=0
          fi
      fi

      ${pkgs.coreutils}/bin/sleep 60
  done
''
