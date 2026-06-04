{ pkgs }:
''
        #!${pkgs.dash}/bin/dash
        PROCS=$1; shift
        for p in $PROCS; do
            ${pkgs.procps}/bin/pgrep -x "$p" >/dev/null && exit 0
        done
        exec "$@" >/dev/null 2>&1
      ''
