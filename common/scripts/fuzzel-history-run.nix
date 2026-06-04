{ pkgs }:
''
        #!${pkgs.bash}/bin/bash
        HISTFILE="$HOME/.bash_history"
        CMD=$(${pkgs.coreutils}/bin/tac "$HISTFILE" 2>/dev/null | ${pkgs.gawk}/bin/awk '!x[$0]++' | \
          ${pkgs.fuzzel}/bin/fuzzel -d -p "Run: " -w 80 \
            --no-sort \
            --placeholder="e.g. sudo nixos-rebuild switch")
        
        [ -z "$CMD" ] && exit 0
 
        # 1. Safeguard for destructive commands
        # Matches commands starting with rm, mv, cp, dd (optionally with sudo)
        DESTRUCTIVES="rm|mv|cp|dd|nix-collect-garbage"
        if [[ "$CMD" =~ ^(sudo\ )?($DESTRUCTIVES)(\ |$) ]]; then
            CONFIRM=$(printf "No\nYes" | ${pkgs.fuzzel}/bin/fuzzel -d -p "Destructive! Confirm? " -w 30)
            [ "$CONFIRM" != "Yes" ] && exit 0
        fi

        # 1. TUI/Interactive Detection (includes sudo for password prompt)
        TUIs="hx|top|htop|btop|iotop|nmtui|calcurse|pwvucontrol|nnn|less|man|vi|vim|nano|python|gh|ip|sudo"
        if [[ "$CMD" =~ ^($TUIs) ]] || [[ "$CMD" == *" -e "* ]] || [[ "$CMD" == *" --execute "* ]]; then
            exec setsid ${pkgs.foot}/bin/foot bash -i -c "$CMD; exec bash" >/dev/null 2>&1
        fi

        # 2. Smart Capture Path
        OUT_FILE=$(mktemp /tmp/fuzzel_run_XXXXXX)
        (eval "$CMD") > "$OUT_FILE" 2>&1 &
        PID=$!
        
        # Wait to check if it's a "quick" background task or a long/noisy one
        sleep 0.8
        
        if kill -0 $PID 2>/dev/null; then
            # Still running after 0.8s: Open terminal and follow output
            ${pkgs.libnotify}/bin/notify-send "Long Process Started" "$CMD"
            exec setsid ${pkgs.foot}/bin/foot bash -c "tail -f $OUT_FILE --pid=$PID; echo -e '\n--- Process Finished ---'; rm -f $OUT_FILE; exec bash" >/dev/null 2>&1
        else
            # Finished quickly: check output volume
            LINES=$(wc -l < "$OUT_FILE")
            if [ "$LINES" -gt 15 ]; then
                # Large output: show in terminal
                exec setsid ${pkgs.foot}/bin/foot bash -c "cat $OUT_FILE; echo -e '\n--- Output End ---'; rm -f $OUT_FILE; exec bash" >/dev/null 2>&1
            else
                # Small output: notify
                CONTENT=$(cat "$OUT_FILE" | head -c 1000)
                ${pkgs.libnotify}/bin/notify-send "Done: $CMD" "''
