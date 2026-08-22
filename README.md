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

Configuration is organised by feature, not by layer. Each directory under
`features/` is one thing the machine does and owns everything that thing
needs: NixOS options, Home Manager options, helper scripts, and data files.

- `default.nix` is always a NixOS module, and is what the host imports.
- `system.nix` holds the NixOS half when a feature has both halves.
- `home.nix` holds the Home Manager half, wired up by `default.nix`.

Importing a feature is what enables it. There are no `enable` options to
maintain; to turn something off, delete its line from the host's import list.

| Feature | Covers |
| --- | --- |
| `base` | Boot entries, locale, the Nix daemon, garbage collection, zram |
| `users` | The single `jefaturico` account |
| `network` | NetworkManager behind a closed firewall. Nothing listens |
| `input` | keyd (caps as ctrl/esc), xkb layout, libinput quirks |
| `login` | ly greeter, waylock screen locker, fingerprint auth |
| `desktop` | PipeWire, Bluetooth, portals, fonts, GTK/Qt theming, XDG dirs |
| `compositor` | Niri, fuzzel, mako, swayidle, and the keybinding helper scripts |
| `terminal` | Foot, running as a shared server |
| `shell` | Bash, fzf, zoxide |
| `editor` | Neovim, no plugins |
| `browsing` | LibreWolf with declarative extensions; Brave as a fallback |
| `media` | mpv and imv, plus their MIME associations |
| `development` | Git identity and the three coding agents |
| `packages` | Applications with nothing to configure |
| `laptop` | Low-battery warnings |
| `gaming` | Steam |

`hosts/tethys/default.nix` is the feature list plus host-only hardware
policy. `hosts/tethys/hardware.nix` holds boot-critical disk, swap, and
resume facts and should not be hand-edited.

## Things worth knowing

- `features/compositor/config.kdl` is symlinked out of the store into
  `~/.config/niri/`, so edits apply through niri's live reload without a
  rebuild.
- There is no status bar. `Mod+I` shows the time and battery as a
  notification; `Mod+Escape` opens the power menu.
- There is no secret management. The GitHub SSH key at `~/.ssh/` is placed
  by hand and is not tracked here.
