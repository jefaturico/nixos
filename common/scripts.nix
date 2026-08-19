{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  mkScript = name: pkgs.writeScriptBin name (import (./scripts + "/${name}.nix") { inherit pkgs; });
  batteryCheck = mkScript "battery-check";
  isLaptop = osConfig.networking.hostName == "tethys";
  lidMonitorOnly = pkgs.writeShellApplication {
    name = "lid-monitor-only";
    runtimeInputs = with pkgs; [
      brightnessctl
      coreutils
      gawk
      glib
      systemd
    ];
    text = ''
      set -euo pipefail

      last_lid_state=""
      battery_guard_pid=""
      state_file="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lid-backlight-brightness"

      restore_backlight() {
        if [ -r "$state_file" ]; then
          brightnessctl set "$(<"$state_file")"
          rm -f "$state_file"
        fi
      }

      if [ "''${1:-}" = "restore" ]; then
        restore_backlight
        exit 0
      fi

      lid_is_closed() {
        local state
        state=$(busctl --system get-property \
          org.freedesktop.login1 \
          /org/freedesktop/login1 \
          org.freedesktop.login1.Manager \
          LidClosed | awk '{ print $2 }')
        [ "$state" = "true" ]
      }

      battery_percent() {
        local capacity_file percentage
        for capacity_file in /sys/class/power_supply/BAT*/capacity; do
          [ -r "$capacity_file" ] || continue
          read -r percentage <"$capacity_file"
          printf '%s\n' "$percentage"
          return 0
        done
        return 1
      }

      suspend_if_battery_low() {
        local percentage
        if percentage=$(battery_percent) && [ "$percentage" -le 10 ]; then
          echo "lid-monitor-only: battery at $percentage%; suspending"
          if systemctl suspend; then
            return 0
          fi
          echo "lid-monitor-only: suspend deferred by a logind inhibitor" >&2
        fi
        return 1
      }

      start_battery_guard() {
        (
          while lid_is_closed; do
            if suspend_if_battery_low; then
              # systemctl returns after resume.  Re-check quickly so an
              # unexpected wake with the lid still closed suspends again.
              sleep 5
            else
              sleep 60
            fi
          done
        ) &
        battery_guard_pid=$!
      }

      stop_battery_guard() {
        if [ -n "$battery_guard_pid" ]; then
          kill "$battery_guard_pid" 2>/dev/null || true
          wait "$battery_guard_pid" 2>/dev/null || true
          battery_guard_pid=""
        fi
      }

      cleanup() {
        stop_battery_guard
        restore_backlight
      }
      trap cleanup EXIT

      apply_lid_state() {
        local brightness state
        if lid_is_closed; then
          state="closed"
        else
          state="open"
        fi

        [ "$state" = "$last_lid_state" ] && return

        if [ "$state" = "closed" ]; then
          brightness=$(brightnessctl get)
          if [ "$brightness" -gt 0 ]; then
            printf '%s\n' "$brightness" >"$state_file"
          fi
          brightnessctl set 0
          suspend_if_battery_low || true
          if lid_is_closed; then
            start_battery_guard
          fi
        else
          stop_battery_guard
          restore_backlight
        fi
        last_lid_state="$state"
      }

      apply_lid_state
      while IFS= read -r event; do
        case "$event" in
          *PropertiesChanged*) apply_lid_state ;;
        esac
      done < <(
        gdbus monitor --system \
          --dest org.freedesktop.login1 \
          --object-path /org/freedesktop/login1
      )
    '';
  };
in
{
  home.packages = [
    (mkScript "rebuild-push")
  ]
  ++ lib.optionals isLaptop [
    batteryCheck
  ];

  systemd.user.services.battery-check = lib.mkIf isLaptop {
    Unit.Description = "Battery status monitor";
    Service = {
      Type = "simple";
      ExecStart = "${batteryCheck}/bin/battery-check";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.lid-monitor-only = lib.mkIf isLaptop {
    Unit = {
      Description = "Keep running and turn off the backlight while the lid is closed";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=handle-lid-switch --mode=block --who=graphical-session --why=Runtime-lid-action-is-monitor-off ${lidMonitorOnly}/bin/lid-monitor-only";
      ExecStop = "${lidMonitorOnly}/bin/lid-monitor-only restore";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

}
