{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        set -eu

        # 1. Update hardware
        case "$1" in
            mute) ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
            *)    ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1" -l 1.5 ;;
        esac

        # 2. Format and notify
        INFO=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@)
        case "$INFO" in
            *MUTED*) TEXT="Volume: MUTED" ;;
            *)
                v=''${INFO##* }
                v=''${v%.*}''${v#*.}
                v=''${v#0}; v=''${v#0}
                TEXT="Volume: ''${v:-0}%"
                ;;
        esac
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "$TEXT"
''
