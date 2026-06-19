{ pkgs }:
let
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  niri = "${pkgs.niri}/bin/niri";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
  systemctl = "${pkgs.systemd}/bin/systemctl";
in
''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  CHOICE="$(
      printf '%s\n' \
          "Turn off monitors" \
          "Suspend" \
          "Exit niri" \
          "Reboot" \
          "Power off" \
      | ${fuzzel} -d --no-sort -p "Power options: " -w 20 || true
  )"

  case "$CHOICE" in
      "")
          exit 0
          ;;
      "Turn off monitors")
          exec ${niri} msg action power-off-monitors
          ;;
      "Suspend")
          exec ${systemctl} suspend
          ;;
      "Exit niri")
          exec ${niri} msg action quit
          ;;
      "Reboot")
          exec ${systemctl} reboot
          ;;
      "Power off")
          exec ${systemctl} poweroff
          ;;
      *)
          ${notifySend} -h string:x-canonical-private-synchronous:power-menu \
              "Power menu" "Unknown selection: $CHOICE"
          exit 1
          ;;
  esac
''
