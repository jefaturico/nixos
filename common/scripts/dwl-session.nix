{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        export XDG_CURRENT_DESKTOP=wlroots
        export XDG_SESSION_TYPE=wayland

        # Exec dwl with our startup script using the -s flag.
        exec dwl -s dwl-startup > /tmp/dwl.log 2>&1
''
