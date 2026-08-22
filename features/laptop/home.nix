{ pkgs, ... }:

# Battery warnings. Lid and power-key behaviour belong to logind and are set
# in the host module.
let
  batteryWarning = pkgs.writeShellApplication {
    name = "battery-warning";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = ''
      set -euo pipefail
      threshold=15
      for battery in /sys/class/power_supply/BAT*; do
        [ -r "$battery/capacity" ] && [ -r "$battery/status" ] || continue
        [ "$(<"$battery/status")" = "Discharging" ] || continue
        capacity=$(<"$battery/capacity")
        [ "$capacity" -le "$threshold" ] || continue
        notify-send \
          --app-name=battery \
          --urgency=critical \
          --hint=string:x-canonical-private-synchronous:battery \
          "Battery at $capacity%" "Plug in the charger."
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
