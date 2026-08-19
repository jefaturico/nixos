# Niri session

Tethys runs niri as its sole compositor through the packaged `niri-session`
systemd integration. It starts `xwayland-satellite` on demand for Steam,
Proton, and other X11 clients.

`../../dots/niri/config.kdl` is an ordinary checked-in configuration linked
out of the Nix store, so edits apply through niri's live reload without a
rebuild. It is based on the complete commented default shipped by the pinned
niri package and carries over the US
AltGr International keyboard layout, repeat timing, touchpad
tap/drag/natural-scroll behavior, and essential launcher, terminal, lock,
audio, brightness, fullscreen, floating, previous workspace, and power-menu
bindings.
The default shortcut-inhibitor escape hatch moves to `Mod+Ctrl+Escape` because
`Mod+Escape` retains the existing desktop power menu.
`Mod+BackSpace` opens a niri IPC-backed window focus menu; `Mod+T`,
`Mod+Shift+T`, `Mod+I`, and `Mod+D` switch the theme, choose a wallpaper, show
system information, and find a document respectively.
Column resizing uses direct, repeatable shortcuts rather than a preset cycle:
`Mod+Shift+R`, `Mod+R`, and `Mod+Ctrl+R` select one-third, one-half, and
two-thirds widths, while `Mod+Space` expands the focused column into the
available width. Window-height reset is on `Mod+Ctrl+BackSpace`.
Scripted Fuzzel menus set a task-appropriate maximum line count and shrink to
their actual number of entries.

Niri otherwise retains its upstream defaults and examples. Client-side
decorations are disabled where clients cooperate; the niri configuration owns
its decoration policy directly, with both the focus ring and border disabled.
Matugen does not generate or include niri configuration. Foot uses 70% opacity
and requests compositor blur in both light and dark modes. Niri's checked-in
configuration exposes the global blur pass count, offset, noise, and saturation
settings; these tune requested blur without forcing it onto every window. A
layer rule places wbg's `wallpaper` surface in niri's overview backdrop, and a
transparent workspace background keeps that same stationary wallpaper visible
during normal use. Overview workspace shadows are disabled, and all windows are
clipped to the same 15-logical-pixel corner radius as Tethys's display. The
example Waybar startup is commented because this desktop does not install
Waybar, and no niri-specific output policy is declared.

The NixOS niri module supplies GNOME's portal backend for compositor-aware
interfaces such as screencasting. File selection, access prompts, and portal
notifications use GTK for a consistent visible dialog style without adding
Nautilus. GNOME Keyring and the Secret portal are disabled. After activation,
verify the keyboard and touchpad, launcher and terminal, focus menu, theme and
wallpaper bindings, lock and suspend, notifications and policy prompts, Steam
scaling, game resolution and pointer capture, screenshots, external-output
hotplug, and logout back to Ly.
