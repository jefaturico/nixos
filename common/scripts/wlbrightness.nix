{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        set -eu

        # 1. Hard floor: clamp any decrease to 10%
        case "$1" in
            *-) 
                PRE=$(${pkgs.brightnessctl}/bin/brightnessctl i -m)
                tmp=''${PRE%,*}; perc=''${tmp##*,}; v=''${perc%%%}
                [ "$v" -le 10 ] && set -- 10%
                ;;
        esac

        # 2. Apply change and notify
        NEW=$(${pkgs.brightnessctl}/bin/brightnessctl set "$1" -m | cut -d, -f4)
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "Brightness: $NEW"
''
