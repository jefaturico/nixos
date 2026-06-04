{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        export XDG_CURRENT_DESKTOP=river
        export XDG_SESSION_TYPE=wayland

        # Exec river with our init script. Log level set to 'error' to suppress
        # wlroots info/warning spam (XKB noise, terminal hangups, icon protocol, etc).
        exec river -log-level error -c river-init > /tmp/river.log 2>&1
''
