{ pkgs }:
''
        #!${pkgs.bash}/bin/bash
        # River init script - configured via riverctl commands.
        # Called by river on startup via: river -c river-init

        # ── Startup ──────────────────────────────────────────────────────────────
        river-startup &

        # ── Layouts ──────────────────────────────────────────────────────────────
        # Use rivertile as the default layout generator.
        rivertile -view-padding 0 -outer-padding 0 -main-ratio 0.60 &

        # Set the layout for all tags on all outputs.
        riverctl default-layout rivertile

        # ── Appearance ───────────────────────────────────────────────────────────
        riverctl border-width 1
        riverctl border-color-focused   0x000000
        riverctl border-color-unfocused 0x000000
        riverctl border-color-urgent    0xFF0000

        # Focus does NOT follow pointer (matches sloppyfocus=0).
        riverctl focus-follows-cursor disabled

        # Hide cursor after 5 seconds of inactivity (matches cursor_timeout=5).
        riverctl hide-cursor timeout 5000
        riverctl hide-cursor when-typing enabled

        # ── Keyboard ─────────────────────────────────────────────────────────────
        riverctl keyboard-layout \
            -variant altgr-intl \
            -options "caps:ctrl_modifier,altwin:menu_win" \
            us

        riverctl set-repeat 50 200

        # ── Input (applies to ALL input devices) ─────────────────────────────────
        riverctl input '*' tap enabled
        riverctl input '*' tap-button-map left-right-middle
        riverctl input '*' drag enabled
        riverctl input '*' drag-lock enabled
        riverctl input '*' natural-scroll enabled
        riverctl input '*' disable-while-typing enabled
        riverctl input '*' scroll-method two-finger
        riverctl input '*' accel-profile flat
        riverctl input '*' pointer-accel 0.0
        riverctl input '*' click-method button-areas

        # ── Window Rules ─────────────────────────────────────────────────────────
        # brave-browser always goes to tag 10 (bit 9, value 512).
        riverctl rule-add -app-id "brave-browser" tags $((1 << 9))
        # foot-float always floats.
        riverctl rule-add -app-id "foot-float" float

        # ── App commands ─────────────────────────────────────────────────────────
        # All bound with Mod = Super (Logo key).

        # Terminal / launcher
        riverctl map normal Super Return    spawn foot
        riverctl map normal Super+Shift Return spawn fuzzel-history-run
        riverctl map normal Super P        spawn 'fuzzel -p "λ "'

        # Applications
        riverctl map normal Super D        spawn wdoc-find
        riverctl map normal Super I        spawn systeminfo
        riverctl map normal Super N        spawn "foot -D /home/jefaturico/zettelkasten -e hx ."
        riverctl map normal Super+Shift N  spawn obsidian
        riverctl map normal Super C        spawn "foot -e taskwarrior-tui"
        riverctl map normal Super+Shift C  spawn "foot -e khal interactive"
        riverctl map normal Super B        spawn fuzzel-bookmarks

        # Wallpaper / theme
        riverctl map normal Super W        spawn "wlsetbg -r"
        riverctl map normal Super+Shift W  spawn wlsetbg
        riverctl map normal Super T        spawn wlsettheme
        riverctl map normal Super+Shift T  spawn wldaynight

        # Screenshots
        riverctl map normal Super S        spawn "wlscreenshot -s"
        riverctl map normal Super+Shift S  spawn wlscreenshot

        # Media / brightness keys (no modifier)
        riverctl map normal None XF86MonBrightnessUp   spawn "wlbrightness 10%+"
        riverctl map normal None XF86MonBrightnessDown spawn "wlbrightness 10%-"
        riverctl map normal None XF86AudioRaiseVolume  spawn "wlvolume 5%+"
        riverctl map normal None XF86AudioLowerVolume  spawn "wlvolume 5%-"
        riverctl map normal None XF86AudioMute         spawn "wlvolume mute"

        # ── Window management ────────────────────────────────────────────────────
        riverctl map normal Super J focus-view next
        riverctl map normal Super K focus-view previous

        # Resize master ratio (+/-0.1 per press, mirrors setmfact).
        riverctl map normal Super R        send-layout-cmd rivertile "main-ratio -0.1"
        riverctl map normal Super+Shift R  send-layout-cmd rivertile "main-ratio +0.1"

        # Increase/decrease number of master windows (mirrors incnmaster).
        riverctl map normal Super Equal    send-layout-cmd rivertile "main-count +1"
        riverctl map normal Super Minus    send-layout-cmd rivertile "main-count -1"

        # Float / zoom / fullscreen
        riverctl map normal Super+Shift Space toggle-float
        riverctl map normal Super Space       zoom
        riverctl map normal Super E           toggle-fullscreen

        # Close window
        riverctl map normal Super Q close

        # Tab = focus previously focused tags (mirrors DWL view {0}).
        riverctl map normal Super Tab focus-previous-tags

        # ── Layout switching ─────────────────────────────────────────────────────
        # Super+L  → tiling (rivertile, default main-count 1)
        riverctl map normal Super L        send-layout-cmd rivertile "main-count 1"
        # Super+Shift+L → monocle (rivertile: all windows in master, ratio 1.0)
        riverctl map normal Super+Shift L  spawn 'riverctl send-layout-cmd rivertile "main-count 999" && riverctl send-layout-cmd rivertile "main-ratio 0.999"'
        # Super+Ctrl+Shift+L → toggle float on focused window (closest to "float layout")
        riverctl map normal Super+Control+Shift L toggle-float

        # ── Monitor focus ────────────────────────────────────────────────────────
        riverctl map normal Super Comma  focus-output next
        riverctl map normal Super Period focus-output previous
        riverctl map normal Super+Shift Less    send-to-output next
        riverctl map normal Super+Shift Greater send-to-output previous

        # ── Tags (workspaces) ────────────────────────────────────────────────────
        # Tags 1..9  (same 4-binding set as DWL TAGKEYS macro)
        for i in $(seq 1 9); do
            tags=$(( 1 << (i - 1) ))
            riverctl map normal "Super"               "$i" set-focused-tags  "$tags"
            riverctl map normal "Super+Shift"         "$i" set-view-tags     "$tags"
            riverctl map normal "Super+Control"       "$i" toggle-focused-tags "$tags"
            riverctl map normal "Super+Shift+Control" "$i" toggle-view-tags  "$tags"
        done

        # Tag 10 = Brave (bit 9 = 512, i.e. 1 << 9).

        # Super+0 → switch to tag 10 AND launch Brave if not running (spawn_and_view).
        riverctl map normal Super 0 spawn \
            'riverctl set-focused-tags 512; single-instance brave\ .brave-wrapped brave'

        # Super+Shift+0 → move focused window to tag 10.
        riverctl map normal Super+Shift 0 set-view-tags 512
        # Super+Ctrl+0  → toggle tag 10 in view.
        riverctl map normal Super+Control 0 toggle-focused-tags 512
        # Super+Ctrl+Shift+0 → toggle tag 10 on focused window.
        riverctl map normal Super+Shift+Control 0 toggle-view-tags 512

        # ── Pointer bindings (mod + mouse drag) ──────────────────────────────────
        riverctl map-pointer normal Super BTN_LEFT  move-view
        riverctl map-pointer normal Super BTN_RIGHT resize-view
        riverctl map-pointer normal Super BTN_MIDDLE toggle-float

        # ── Quit ─────────────────────────────────────────────────────────────────
        riverctl map normal Super End exit
        riverctl map normal Super+Control+Alt Delete exit
''
