{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  mkScript = name: pkgs.writeScriptBin name (import (./scripts + "/${name}.nix") { inherit pkgs; });
  batteryCheck = mkScript "battery-check";
  streamTitanDesktop = mkScript "stream-titan-desktop";
  lidOutputManager = pkgs.writeShellApplication {
    name = "lid-output-manager";
    runtimeInputs = with pkgs; [ brightnessctl coreutils gawk glib systemd ];
    text = ''
      set -euo pipefail

      last_state=""
      battery_guard_pid=""

      battery_percent() {
        local capacity_file
        for capacity_file in /sys/class/power_supply/BAT*/capacity; do
          [ -r "$capacity_file" ] || continue
          read -r percentage <"$capacity_file"
          printf '%s\n' "$percentage"
          return 0
        done
        return 1
      }

      start_battery_guard() {
        (
          while :; do
            lid_closed=$(busctl --system get-property \
              org.freedesktop.login1 \
              /org/freedesktop/login1 \
              org.freedesktop.login1.Manager \
              LidClosed | awk '{ print $2 }')
            [ "$lid_closed" = "true" ] || exit 0

            if percentage=$(battery_percent) && [ "$percentage" -lt 10 ]; then
              echo "lid-output-manager: battery at $percentage%; suspending while lid is closed"
              systemctl suspend
              exit 0
            fi

            sleep 60
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

      trap stop_battery_guard EXIT

      apply_lid_state() {
        local state brightness state_file
        state=$(busctl --system get-property \
          org.freedesktop.login1 \
          /org/freedesktop/login1 \
          org.freedesktop.login1.Manager \
          LidClosed | awk '{ print $2 }')

        [ "$state" = "$last_state" ] && return

        state_file="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lid-backlight-brightness"

        if [ "$state" = "true" ]; then
          brightness=$(brightnessctl get)
          if [ "$brightness" -gt 0 ]; then
            printf '%s\n' "$brightness" >"$state_file"
          fi
          brightnessctl set 0
          start_battery_guard
        else
          stop_battery_guard
          if [ -r "$state_file" ]; then
            brightnessctl set "$(<"$state_file")"
            rm -f "$state_file"
          fi
        fi
        last_state="$state"
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
  ++ lib.optionals (osConfig.networking.hostName == "tethys") [
    batteryCheck
    streamTitanDesktop
  ];

  xdg.dataFile."applications/stream-titan-desktop.desktop" =
    lib.mkIf (osConfig.networking.hostName == "tethys")
      {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Stream Titan's Desktop
          GenericName=Remote Desktop Stream
          Comment=Connect to Titan's desktop through Moonlight
          Exec=stream-titan-desktop
          Icon=moonlight
          Terminal=false
          Categories=Network;RemoteAccess;
          Keywords=titan;moonlight;stream;desktop;remote;
        '';
      };

  systemd.user.services.battery-check = lib.mkIf (osConfig.networking.hostName == "tethys") {
    Unit.Description = "Battery status monitor";
    Service = {
      Type = "simple";
      ExecStart = "${batteryCheck}/bin/battery-check";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.lid-output-manager =
    lib.mkIf (osConfig.networking.hostName == "tethys") {
      Unit = {
        Description = "Turn the internal display backlight off while the lid is closed";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lidOutputManager}/bin/lid-output-manager";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
}
