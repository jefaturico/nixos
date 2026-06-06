{ pkgs }:
''
  #!${pkgs.bash}/bin/bash
  # River init script - configured via riverctl commands.
  # Called by river on startup via: river -c river-init

  # ── Startup & Appearance ─────────────────────────────────────────────────
  # Set black background instantly to avoid River's default blue-green flash
  riverctl background-color 0x000000
  river-state-init
  river-startup &

  # ── Layouts ──────────────────────────────────────────────────────────────
  # Use rivercarro as the default layout generator.
  rivercarro -inner-gaps 0 -outer-gaps 0 -main-ratio 0.60 -per-tag &

  # Set the layout for all tags on all outputs.
  riverctl default-layout rivercarro

  # ── Appearance ───────────────────────────────────────────────────────────
  riverctl border-width 1
  riverctl border-color-focused   0x000000
  riverctl border-color-unfocused 0x000000
  riverctl border-color-urgent    0xFF0000

  # Focus does NOT follow pointer (matches sloppyfocus=0).
  riverctl focus-follows-cursor disabled
  riverctl set-cursor-warp on-focus-change

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
  riverctl input '*' accel-profile adaptive
  riverctl input '*' pointer-accel 0.0
  riverctl input '*' click-method button-areas

  # ── Window Rules ─────────────────────────────────────────────────────────
  # brave-browser always goes to tag 10 (bit 9, value 512).
  riverctl rule-add -app-id "brave-browser" tags $((1 << 9))
  # foot-float always floats.
  riverctl rule-add -app-id "foot-float" float
  # Global rule for floating window dimensions
  riverctl rule-add -app-id "*" dimensions 960 720

  # ── App commands ─────────────────────────────────────────────────────────
  riverctl map normal Super Return    spawn foot
  riverctl map normal Super+Shift Return spawn fuzzel-history-run
  riverctl map normal Super P        spawn 'fuzzel -p "λ "'
  riverctl map normal Super D        spawn wdoc-find
  riverctl map normal Super I        spawn systeminfo
  riverctl map normal Super N        spawn "foot -D /home/jefaturico/zettelkasten -e nvim -c ObsidianSearch"
  riverctl map normal Super+Shift N  spawn obsidian
  riverctl map normal Super C        spawn "foot -e taskwarrior-tui"
  riverctl map normal Super+Shift C  spawn "foot -e khal interactive"
  riverctl map normal Super B        spawn fuzzel-bookmarks
  riverctl map normal Super W        spawn "wlsetbg -r"
  riverctl map normal Super+Shift W  spawn wlsetbg
  riverctl map normal Super T        spawn wlsettheme
  riverctl map normal Super+Shift T  spawn wldaynight
  riverctl map normal Super S        spawn "wlscreenshot -s"
  riverctl map normal Super+Shift S  spawn wlscreenshot
  riverctl map normal None XF86MonBrightnessUp   spawn "wlbrightness 10%+"
  riverctl map normal None XF86MonBrightnessDown spawn "wlbrightness 10%-"
  riverctl map normal None XF86AudioRaiseVolume  spawn "wlvolume 5%+"
  riverctl map normal None XF86AudioLowerVolume  spawn "wlvolume 5%-"
  riverctl map normal None XF86AudioMute         spawn "wlvolume mute"

  # ── Window management ────────────────────────────────────────────────────
  riverctl map normal Super J focus-view next
  riverctl map normal Super K focus-view previous
  riverctl map normal Super R        send-layout-cmd rivercarro "main-ratio -0.1"
  riverctl map normal Super+Shift R  send-layout-cmd rivercarro "main-ratio +0.1"
  riverctl map normal Super Equal    send-layout-cmd rivercarro "main-count +1"
  riverctl map normal Super Minus    send-layout-cmd rivercarro "main-count -1"
  riverctl map normal Super+Shift Space spawn river-toggle-float
  riverctl map normal Super Space       zoom
  riverctl map normal Super E           toggle-fullscreen
  riverctl map normal Super Q close
  riverctl map normal Super Tab spawn river-focus-previous-tags

  # ── Layout switching ─────────────────────────────────────────────────────
  riverctl map normal Super L        send-layout-cmd rivercarro "main-location left"
  riverctl map normal Super+Shift L  send-layout-cmd rivercarro "main-location monocle"
  riverctl map normal Super+Control+Shift L toggle-float

  # ── Monitor focus ────────────────────────────────────────────────────────
  riverctl map normal Super Comma  focus-output next
  riverctl map normal Super Period focus-output previous
  riverctl map normal Super+Shift Less    send-to-output next
  riverctl map normal Super+Shift Greater send-to-output previous

  # ── Tags (workspaces) ────────────────────────────────────────────────────
  for i in $(seq 1 9); do
      tags=$(( 1 << (i - 1) ))
      riverctl map normal "Super" "$i" spawn "river-set-focused-tags $tags"
      riverctl map normal "Super+Shift"         "$i" set-view-tags     "$tags"
      riverctl map normal "Super+Control"       "$i" spawn "river-toggle-focused-tags $tags"
      riverctl map normal "Super+Shift+Control" "$i" toggle-view-tags  "$tags"
  done

  # Super+0 → switch to tag 10 AND launch Brave if not running (spawn_and_view).
  riverctl map normal Super 0 spawn "river-set-focused-tags 512; single-instance brave\ .brave-wrapped brave"
  riverctl map normal Super+Shift 0 set-view-tags 512
  riverctl map normal Super+Control 0 spawn "river-toggle-focused-tags 512"
  riverctl map normal Super+Shift+Control 0 toggle-view-tags 512

  # ── Pointer bindings (mod + mouse drag) ──────────────────────────────────
  riverctl map-pointer normal Super BTN_LEFT  move-view
  riverctl map-pointer normal Super BTN_RIGHT resize-view
  riverctl map-pointer normal Super BTN_MIDDLE toggle-float

  # ── Quit ─────────────────────────────────────────────────────────────────
  riverctl map normal Super End exit
  riverctl map normal Super+Control+Alt Delete exit
''
