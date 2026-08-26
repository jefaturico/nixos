# nixos

NixOS configuration for **tethys**, a Framework laptop (AMD AI 300 series).
One host, one user, one flake.

## Rebuilding

```sh
rebuild                 # alias for the line below
sudo nixos-rebuild switch --flake path:$HOME/nixos#tethys
```

`path:` is used so untracked files still participate in evaluation. To check
a change without activating it:

```sh
nix flake check path:. --no-build
nix build path:.#nixosConfigurations.tethys.config.system.build.toplevel --no-link
```

## Layout

Every module is named after the exact program or facility it configures, so
the name answers "where does X's config live". Each is a single NixOS module
that carries both halves: system options at the top level, user options
under `home-manager.users.jefaturico`. A module gets a directory only when
it needs a second file (`system/theme/`).

- `programs/<name>.nix` — one program each: its options, config files,
  helper commands, services.
- `system/<name>.nix` — machine facilities that are not one program: boot,
  locale, audio, fonts, the account itself.
- `scripts/<name>.sh` — every helper script, as a real shell file. The
  module that owns a script builds it with `writeShellApplication` and
  `builtins.readFile`, so shellcheck runs at build time.
- `lib/palette.nix` — the shared Monokai Pro palette (kitty, fuzzel, mako).
- `hosts/tethys/` — the import list plus host-only hardware policy.
  `hardware.nix` holds boot-critical disk, swap, and resume facts and
  should not be hand-edited.

Importing a module is what enables it. There are no `enable` options to
maintain; to turn something off, delete its line from the host's import
list.

### programs/

| Module | Covers |
| --- | --- |
| `niri` | The compositor: its KDL config inline, the keybinding helper scripts, session services |
| `fuzzel` | The launcher, themed from the shared palette |
| `mako` | Notifications, themed from the shared palette |
| `swayidle` | Lock before sleep, suspend after idle |
| `wbg` | The wallpaper |
| `kitty` | The terminal, themed from the shared palette |
| `bash` | Prompt, history, aliases |
| `fzf`, `zoxide` | Fuzzy finding; frecency `cd` |
| `neovim` | The editor, no plugins, plus the `notes-*` commands |
| `emacs` | Emacs behind Mod+E. Font, padding, wrapping, GC tuning |
| `brave` | The browser, default handlers, the focus-after-open shim |
| `librewolf` | The fallback browser with declarative extensions |
| `sioyek` | The PDF reader |
| `pdf-find` | The PDF picker behind Mod+D |
| `typst` | Typst, tinymist, and the live preview in a browser window |
| `calcurse` | Calendar, its reminder daemon |
| `mpv`, `imv` | Video and images, plus their MIME associations |
| `git` | Identity and defaults |
| `claude-code`, `codex`, `antigravity` | The coding agents |
| `steam` | Steam |
| `keyd` | Caps as ctrl/esc, below every compositor and console |
| `ly` | The console greeter |
| `waylock` | The screen locker |
| `fprintd` | Fingerprint auth, everywhere it is accepted |

### system/

| Module | Covers |
| --- | --- |
| `boot` | Boot entry policy, console noise |
| `locale` | Timezone, language, console keymap |
| `nix` | Flakes, garbage collection, deduplication |
| `users` | The single `jefaturico` account and its groups |
| `network` | NetworkManager behind a closed firewall. Nothing listens |
| `keyboard` | The xkb layout, held once for everything that asks |
| `audio` | PipeWire |
| `bluetooth` | The radio, on at boot |
| `removable-media` | udisks2 plus udiskie |
| `fonts` | JetBrains Mono Nerd Font, corefonts |
| `xdg` | Portals, user directories, default handlers, the HM account |
| `theme` | The light/dark switch: `desktop-theme` and its session service |
| `battery` | Low-battery warnings, hibernate at 7% |
| `packages` | Applications with nothing to configure |

## Things worth knowing

- The niri config is inline in `programs/niri.nix` and applied on rebuild;
  niri reloads it when the store link changes.
- There is no status bar. `Mod+I` shows the time and battery as a
  notification; `Mod+Escape` opens the power menu.
- There is no secret management. The GitHub SSH key at `~/.ssh/` is placed
  by hand and is not tracked here.
