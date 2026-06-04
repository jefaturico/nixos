{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        set -eu
        SCREENSHOT_DIR="$HOME/images/screenshots"
        mkdir -p "$SCREENSHOT_DIR"
        FILE="$SCREENSHOT_DIR/$(date +'%Y%m%d_%H%M%S').png"

        if [ "$#" -gt 0 ] && [ "$1" = "-s" ]; then
            GEOM=$(${pkgs.slurp}/bin/slurp)
            [ -z "$GEOM" ] && exit 0
            ${pkgs.grim}/bin/grim -g "$GEOM" "$FILE"
        else
            ${pkgs.grim}/bin/grim "$FILE"
        fi

        ${pkgs.wl-clipboard}/bin/wl-copy < "$FILE"
        ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:screenshot "Screenshot Taken" "Saved to $(basename "$FILE") and copied to clipboard" -i camera-photo
''
