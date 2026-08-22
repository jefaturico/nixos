# Niri session

Titan and Tethys both run niri as their sole compositor through the packaged
`niri-session` systemd integration. It starts `xwayland-satellite` on demand
for Steam, Proton, and other X11 clients. The two hosts share this module
unchanged; only their GPU and chassis configuration differs.

`./config.kdl` is an ordinary checked-in configuration linked
out of the Nix store, so edits apply through niri's live reload without a
rebuild. It began as the commented default shipped by the pinned niri package
and has been reduced to the settings this desktop actually declares: the US
AltGr International keyboard layout, repeat timing, touchpad
tap/drag/natural-scroll behavior, cursor auto-hide on typing and after 5
seconds of inactivity, and the launcher, terminal, lock, audio, brightness,
fullscreen, floating, previous workspace, and power-menu bindings. Upstream
reference comments were removed on purpose; the niri wiki is the reference.
The only comments that remain explain local rules whose reason is not evident
from the value.
The default shortcut-inhibitor escape hatch moves to `Mod+Ctrl+Escape` because
`Mod+Escape` retains the existing desktop power menu.
`Mod+BackSpace` opens a niri IPC-backed window focus menu. `Mod+B` opens
LibreWolf, while `Mod+C` opens Codex in a new Foot client; the previous
center-column action moves to `Mod+Shift+C`.
`Mod+T` chooses a
wallpaper and reapplies its theme association, or applies its first-ranked theme
when no association exists. `Mod+Shift+T` selects a Tinted theme in a temporary
Foot/fzf picker, previews highlighted schemes live against the current
wallpaper, and associates the accepted theme with it. The initial list contains
every genuinely dark catalog theme ordered by perceptual affinity between the
wallpaper and the theme's accents, dark background, and off-white foreground;
Escape restores the previous theme. `Mod+I` and `Mod+D` show system information
and find a document respectively. `Mod+N` opens NetworkManager connections in a
dedicated themed Foot client.
Column resizing uses direct, repeatable shortcuts rather than a preset cycle:
`Mod+Shift+R`, `Mod+R`, and `Mod+Ctrl+R` select one-third, one-half, and
two-thirds widths, while `Mod+Space` expands the focused column into the
available width. Window-height reset is on `Mod+Ctrl+BackSpace`.
Scripted Fuzzel menus set a task-appropriate maximum line count and shrink to
their actual number of entries.

Niri otherwise retains its upstream defaults. Client-side
decorations are disabled where clients cooperate; the niri configuration owns
its decoration policy directly, with both the focus ring and border disabled on tiled
windows, and drop shadows enabled exclusively for floating windows.
Tinty applies one pinned upstream Base16 theme to Foot, Fuzzel, Fnott, and
Neovim. The local state stores only wallpaper filenames, scheme identifiers,
and the current generated files; palette definitions remain in the pinned
Tinted Theming catalog. Foot, Fuzzel, and Fnott use 70% opaque backgrounds,
while Neovim keeps its editor background transparent so Foot provides the
translucent tinted surface. Running Neovim instances reload theme previews and
committed changes immediately.
Changing themes does not restart Foot's shared server: existing terminals
receive the palette through OSC sequences, and newly opened clients receive it
from their launcher.
Foot requests compositor blur directly, while a targeted niri layer rule
enables regular (non-xray) blur for Fuzzel, sampling the actual content behind
the launcher and clipping the effect to its configured corner radius. Fnott
creates one tightly sized layer surface per notification, allowing a second
targeted rule to apply the same regular blur without extending across invisible
margins or the gaps between notifications. Neovim inherits Foot's compositor
blur while keeping its text fully opaque. LibreWolf uses the same regular blur
for its Tinty-colored translucent browser chrome while webpage canvases remain
opaque.
Niri's checked-in configuration exposes the global blur pass
count, offset, noise, and saturation settings;
these tune requested blur without forcing it onto every window. A
layer rule places wbg's `wallpaper` surface in niri's overview backdrop, and a
transparent workspace background keeps that same stationary wallpaper visible
during normal use. The overview backdrop color is set to pure black (`#000000`)
as the fallback background. Overview workspace shadows are disabled, and all
windows are clipped to the same 15-logical-pixel corner radius as Tethys's
display.
No status bar is installed and no niri-specific output policy is declared
beyond a scale for the external Samsung panel.

Fnott is overridden with three patches under `../theme/patches/`, leaving its
pinned upstream source unchanged: `fnott-placement` adds top/bottom-center
anchors and `center-app-names` routing, `fnott-vertical-text-bounds` makes
vertical text placement visually even, and `fnott-centered-min-width` gives
centered notifications a minimum width. The generated configuration uses top-center for
ordinary notifications (such as the 25-minute `movement-posture` reminder) and
routes the `volume`, `brightness`, and 50-minute `movement-break` application
names to screen center; microphone feedback also uses the `volume`
application name. The `movement-reminder` systemd user service tracks active
computer use via native Wayland idle detection (`swayidle`) and suppresses
notifications during immersive sessions (gaming, fullscreen media, active MPRIS
playback, and screen lock). All notifications use the layer-shell overlay layer so this
small script-owned notification set remains visible above fullscreen windows.
Critical notifications do not expire by default; the dark and fallback themes
also distinguish them with a deep translucent red background. When updating
Fnott, confirm that all three patches still apply, build both desktop closures, and
exercise ordinary stacking, notifications over fullscreen windows, critical
dismissal, repeated volume, microphone, and brightness replacement updates, and
the movement reminder cycle.
Volume, microphone, and brightness feedback is centered at the configured
720-logical-pixel `center-min-width` and remains visible for 400 milliseconds;
replacement IDs ensure repeated adjustments update one notification.

The NixOS niri module supplies GNOME's portal backend for compositor-aware
interfaces such as screencasting. File selection, access prompts, and portal
notifications use GTK for a consistent visible dialog style without adding
Nautilus. GNOME Keyring and the Secret portal are disabled. After activation,
verify the keyboard and touchpad, launcher and terminal, focus menu, theme and
wallpaper bindings, lock and suspend, notifications and policy prompts, Steam
scaling, game resolution and pointer capture, screenshots, external-output
hotplug, and logout back to Ly.
