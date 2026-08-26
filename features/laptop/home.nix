{ pkgs, ... }:

# Battery warnings and the last-resort hibernation. Lid and power-key
# behaviour belong to logind and are set in the host module.
let
  batteryWarning = pkgs.writeShellApplication {
    name = "battery-warning";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      systemd
    ];
    text = ''
      set -euo pipefail

      # The four steps, most urgent first. Below the last one there is nothing
      # left to warn about: the machine saves the session instead.
      hibernate_at=7
      critical_at=10
      warn_at=15
      notice_at=20

      # The timer fires every two minutes, so warning on capacity alone would
      # repeat the same popup for as long as the charger stays out. This
      # records the step last warned about and only speaks up when a lower one
      # is reached; plugging in clears it, so a second discharge warns again.
      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/battery-warning"

      last_step=$(cat "$state_file" 2>/dev/null || echo 100)
      case "$last_step" in
        "" | *[!0-9]*) last_step=100 ;;
      esac

      remember() {
        mkdir -p "$(dirname "$state_file")"
        printf '%s\n' "$1" >"$state_file"
      }

      for battery in /sys/class/power_supply/BAT*; do
        [ -r "$battery/capacity" ] && [ -r "$battery/status" ] || continue

        if [ "$(<"$battery/status")" != "Discharging" ]; then
          remember 100
          continue
        fi

        capacity=$(<"$battery/capacity")

        # Hibernation is not a warning and is not rate-limited by the steps
        # above: at this level the session has to be written to disk whether
        # or not anything was said earlier.
        if [ "$capacity" -le "$hibernate_at" ]; then
          notify-send \
            --app-name=battery \
            --urgency=critical \
            --hint=string:x-canonical-private-synchronous:battery \
            "Battery at $capacity%" "Hibernating to save your work."
          # Give the notification a moment to reach the screen.
          sleep 5
          remember "$hibernate_at"
          systemctl hibernate
          continue
        fi

        if [ "$capacity" -le "$critical_at" ]; then
          step=$critical_at
          urgency=critical
          body="Plug in the charger now; the machine hibernates at $hibernate_at%."
        elif [ "$capacity" -le "$warn_at" ]; then
          step=$warn_at
          urgency=normal
          body="Plug in the charger."
        elif [ "$capacity" -le "$notice_at" ]; then
          step=$notice_at
          urgency=normal
          body="Running low."
        else
          continue
        fi

        [ "$step" -lt "$last_step" ] || continue

        notify-send \
          --app-name=battery \
          --urgency="$urgency" \
          --hint=string:x-canonical-private-synchronous:battery \
          "Battery at $capacity%" "$body"
        remember "$step"
      done
    '';
  };
in
{
  systemd.user.services.battery-warning = {
    Unit.Description = "Warn when the battery runs low";
    Service = {
      Type = "oneshot";
      ExecStart = "${batteryWarning}/bin/battery-warning";
    };
  };

  systemd.user.timers.battery-warning = {
    Unit.Description = "Warn when the battery runs low";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "2m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
