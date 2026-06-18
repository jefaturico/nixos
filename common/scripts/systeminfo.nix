{ pkgs }:
''
  #!${pkgs.dash}/bin/dash
  TIME=$(${pkgs.coreutils}/bin/date +%H:%M)

  # Smart battery detection.
  BATS=$(${pkgs.findutils}/bin/find /sys/class/power_supply -name "BAT*" -print)
  CHOSEN_BAT=""
  for bat in $BATS; do
      [ -e "$bat/capacity" ] && CHOSEN_BAT="$bat" && break
  done

  if [ -n "$CHOSEN_BAT" ]; then
    CAPACITY=$(${pkgs.coreutils}/bin/cat "$CHOSEN_BAT/capacity")
    ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "It's $TIME" "Battery at $CAPACITY% capacity"
  else
    ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "It's $TIME"
  fi
''
