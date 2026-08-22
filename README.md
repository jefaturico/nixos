# NixOS configuration

This repository is the source of truth for three personal NixOS machines. It
combines host-specific NixOS modules, shared desktop policy, Home Manager user
configuration, encrypted secrets, and shared graphical-session services in one
flake.

It is a runbook for the existing hosts, not a turnkey NixOS distribution. The
hardware modules, user name, SSH identities, display names, and encrypted
secrets are specific to this installation. The structure is still useful as a
reference when adapting the configuration elsewhere.

## Design goals

The configuration prioritizes performance, battery efficiency, simplicity,
and minimalism. Host policy makes tradeoffs explicit: Tethys sizes zram to the
whole of RAM and disables swap readahead because its workload is interactive,
while Iapetus halves zram and lets TLP clamp CPU boost because nothing on it
waits for a human.

Where a maintained Nixpkgs option, upstream feature, community package, or
community patch fits the pinned system, it is preferred over bespoke code.
Local scripts and patches remain appropriate when they are small, isolated,
better matched to the hardware or workflow, and easier to reason about than an
additional framework or service.

## Hosts

| Host | Role | Configuration highlights |
| --- | --- | --- |
| [`titan`](hosts/titan/README.md) | NVIDIA gaming desktop | The same niri session and application set as Tethys; differs only in hardware — proprietary legacy NVIDIA driver and coredump limits for large browser renderer crashes |
| [`tethys`](hosts/tethys/README.md) | Framework AMD laptop | The shared niri desktop plus the Framework hardware module, manual brightness controls, lid/battery handling, and the display-corner mask |
| [`iapetus`](hosts/iapetus/README.md) | Headless host | SSH and Tailscale reachability, storage and memory maintenance, and command-line tools without Home Manager or the graphical desktop stack. Currently carries no service role |

All hosts are currently `x86_64-linux` and expose flake outputs named after
their hostnames:

```sh
nix flake show
nix eval --raw .#nixosConfigurations.titan.config.networking.hostName
```

## Architecture

`flake.nix` has two constructors. `mkDesktopHost` adds Home Manager and the
SOPS module; `mkServerHost` evaluates the host module alone. Titan and Tethys
use the desktop constructor, Iapetus the server one.

Titan and Tethys are deliberately identical above the hardware line: they
import the same feature list, so the session, applications, keybindings, and
theme are the same on either machine. Their host modules contain only GPU,
firmware, power, and chassis facts. Tethys adds one feature Titan cannot use,
`laptop`, because Titan has no battery or lid.

Configuration is organized by *feature*, not by layer. Each directory under
`features/` is one thing the machine does, and holds everything that thing
needs — system configuration, user configuration, helper scripts, patches, and
dotfiles alike. `features/compositor/` contains the niri NixOS module, the
Home Manager link, the checked-in `config.kdl`, and its README. Removing a
feature is removing a directory.

Every feature exposes the same interface: `default.nix` is a NixOS module.
Where a feature also has a user half, that file is one line wiring `./home.nix`
into Home Manager. So a host reads as a list of capabilities:

```nix
imports = [
  ./hardware.nix
  ../../features/base
  ../../features/desktop
  ../../features/compositor
  ../../features/gaming
];
```

There is no enable flag to maintain: importing the feature *is* enabling it,
and a feature a host does not import costs it nothing.

### Architectural decisions

| Decision | Rationale and boundary |
| --- | --- |
| Stable NixOS and matching Home Manager | Keeps system and user module APIs aligned; the lock file pins each generation |
| Unstable input only for Codex | Updates one fast-moving tool without moving the operating system off stable |
| Separate desktop and server constructors | Keeps Home Manager, SOPS integration, and graphical assumptions out of Iapetus |
| Home Manager embedded in desktop builds | User services and most configuration activate and roll back with the system generation |
| systemd user session target | Gives helpers explicit ownership, restart policy, logging, and logout cleanup |
| X11 compatibility for selected Electron/Xwayland applications | Preserves current application stability; change only after testing affected applications under native Wayland |

Neovim is configured declaratively through Home Manager and follows the active
desktop theme.

### Repository map

| Path | Responsibility |
| --- | --- |
| `flake.nix` / `flake.lock` | Inputs, host constructors, and pinned dependency graph |
| `hosts/<host>/default.nix` | The feature list for that machine, plus host-only hardware policy |
| `hosts/<host>/hardware.nix` | Generated or hardware-specific boot, filesystem, and platform settings |
| `secrets/` | Encrypted secret data |
| `.github/workflows/nix.yml` | Flake evaluation and builds for all three hosts |

Every feature below is a directory under `features/`.

| Feature | Layers | Responsibility |
| --- | --- | --- |
| `base` | system | Boot entries, locale, the Nix daemon, garbage collection, memory/swap policy |
| `users` | system | The single account; other features append groups and keys |
| `network` | system + home | NetworkManager, firewall, SSH server, Tailscale, and the SSH client identities |
| `secrets` | system | SOPS declarations and the tooling to edit them |
| `login` | system + home | Ly, fingerprint PAM, and the hyprlock screen |
| `input` | system | Keyboard layout, keyd remapping, libinput quirks |
| `desktop` | system + home | Portals, peripherals, fonts, session environment, GTK/Qt policy, XDG directories |
| `compositor` | system + home | Niri, its session services and helpers, and the live `config.kdl` |
| `theme` | home | Tinty palette propagation, wallpaper association, Fuzzel/Fnott wrappers, LibreWolf chrome, fnott patches |
| `terminal` | home | Foot and its shared server |
| `shell` | home | Bash, prompt, history, navigation |
| `editor` | home | Neovim |
| `browsing` | home | LibreWolf and Brave |
| `documents` | home | Zathura, Okular, LibreOffice, `find-document`, notes, ledger |
| `media` | home | Playback, viewing, capture, and the MPRIS key handler |
| `development` | home | Git, language servers, formatters, coding agents, `rebuild-push` |
| `ergonomics` | system | The movement and posture reminder daemon |
| `gaming` | system | Steam |
| `laptop` | home | Battery notifications and the lid monitor. Tethys only |
| `packages` | home | Applications installed with nothing to configure |

Adding a configured application means adding one feature directory and one
line to each host that wants it. Adding an application with nothing to
configure means adding one line to `features/packages/home.nix`.

## System design notes

### Desktop and session lifecycle

Both desktops run niri through its packaged systemd session. Niri owns
`graphical-session.target`; shared
helpers such as the Foot server, wallpaper, theme initialization,
the display-corner mask, and other session services attach directly to that
standard target.

One declared exception matters operationally: Tethys's `lid-monitor-only` unit
has `PartOf=graphical-session.target` but no `WantedBy`, so nothing starts it
automatically. That is deliberate — logind owns the lid action — and the unit
is a manually started alternative. Do not mistake declaration for enablement or
silently repair that lifecycle while working on an unrelated feature.

Using user units gives each helper an independent restart policy and journal.
It also keeps optional session processes out of a single opaque startup shell
script.

Both desktops enable the ordinary NixOS Steam client without adding a separate
Steam login session, replacement desktop entry, or nested compositor.

### Theme and mutable state

Tinty reads the pinned upstream Tinted Theming catalog and applies one Base16
scheme to Foot, Fuzzel, Fnott, and Neovim. `theme-switcher` associates the
chosen scheme identifier with the current wallpaper. Its temporary Foot/fzf
picker previews each highlighted scheme live against the wallpaper; accepting
applies it everywhere, while cancelling restores the original. The wallpaper
picker orders every genuinely dark catalog theme by a perceptual comparison of
its accents, background, and foreground with the sampled wallpaper. The
wallpaper switcher reapplies saved associations; a wallpaper without one uses
the first theme in that same suitability ranking. Mutable state contains only
those associations, the current generated files, and the `~/.wbg` launcher—no
palette definitions.
Neovim uses the same palette with transparent editor backgrounds, leaving
terminal text opaque while Foot supplies the tinted translucent surface.
Theme changes update existing Foot windows through OSC palette sequences, and
each new Foot client receives the current generated palette from its launcher.

### Web browsing

LibreWolf is the default browser and owns the desktop HTTP, HTTPS, and HTML
handlers. Its browser chrome uses the active Tinty palette with the same 70%
translucent base surface and regular Niri blur as the rest of the desktop;
tabs, URL-bar states, menus, panels, buttons, and focus accents are derived from
that palette while webpage canvases remain opaque. Its Firefox Nova semantic
color-token coverage is adapted from the MIT-licensed
[FoxOne theme](https://github.com/Firnschnee/FoxOne), without importing FoxOne's
layout changes. LibreWolf supplies uBlock Origin; Bitwarden and
Vimium C are installed from pinned declarative add-on packages and enforced by
browser policy for newly created profiles, while their settings, logins, and
runtime state remain writable. Fresh profiles skip onboarding, recommendations,
default-browser checks, and post-update pages and use DuckDuckGo by default.
Every Home Manager activation reasserts the managed profile links and regenerates
the active Tinty chrome, so rebuilding also recovers a deleted browser profile.
Brave remains the secondary compatibility browser for DRM, conferencing, and
Chromium-only sites.

### Secrets and remote access

This repository is public solely so a new machine can clone it before GitHub
credentials have been provisioned:

```sh
git clone https://github.com/jefaturico/nixos.git ~/nixos
```

Public availability is a deployment convenience, not a privacy boundary.
Committed hostnames, user names, public SSH keys, age recipients, hardware
models, and filesystem UUIDs must be assumed permanently public. Private keys and plaintext secrets must never be committed. Review new
identifiers with that threat model before adding them.

SOPS encrypts `secrets/secrets.yaml` for the configured age recipients.
`sops-nix` materializes host-appropriate SSH identities with restrictive
permissions during activation. Decrypted secrets and private keys must never be
committed or pasted into documentation.

To edit the encrypted file from a machine that has a configured recipient key:

```sh
sops secrets/secrets.yaml
```

The desktop hosts use an SSH identity named for the current host when accessing
GitHub and a separate tailnet identity for peer hosts. SSH password login and
root login are disabled. The firewall trusts the Tailscale interface; SSH does
not otherwise open a public firewall port.

## Working on an existing host

The expected checkout is `~/nixos`, and the active hostname must match one of
the flake output names. Before building, inspect the worktree so unrelated or
uncommitted changes are not accidentally published:

```sh
cd ~/nixos
hostname
git status --short
nix flake check --no-build
```

Build the current host without changing the running system:

```sh
nix build ".#nixosConfigurations.$(hostname).config.system.build.toplevel" --no-link
```

Test a generation without making it the boot default:

```sh
sudo nixos-rebuild test --flake "path:$PWD#$(hostname)"
```

Use the system for long enough to exercise the affected services. Home Manager
services and NixOS modules are activated by the rebuild. The checked-in niri
configuration remains an out-of-store link and reloads without a rebuild.

Persist a tested generation:

```sh
sudo nixos-rebuild switch --flake "path:$PWD#$(hostname)"
```

`rebuild-push` wraps the switch workflow. On Titan and Tethys it only rebuilds
the local host. On Iapetus, the configured Git owner, it then offers to stage
each changed path individually, requests a commit message, and pushes the
current branch. Run it as the normal user; it invokes `sudo` only for
`nixos-rebuild`.

### Updating inputs

Review input changes before switching all machines:

```sh
nix flake update
nix flake check --no-build
nix build .#nixosConfigurations.titan.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.tethys.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.iapetus.config.system.build.toplevel --no-link
```

### Rollback and recovery

For a bad runtime generation, select an older generation in the systemd-boot
menu or switch back immediately:

```sh
sudo nixos-rebuild switch --rollback
```

List and remove generations carefully with the normal NixOS tools; automatic
garbage collection keeps the latest ten generations, and the boot menu shows
the same ten. Store deduplication runs as a weekly `nix-optimise` job rather
than inline on every build. Do not change
`system.stateVersion` or `home.stateVersion` during an ordinary channel update.
Those values describe compatibility state, not the desired package version.

If evaluation fails, start with the narrowest useful checks:

```sh
nix flake check --no-build
nix eval .#nixosConfigurations."$(hostname)".config.system.build.toplevel.drvPath
journalctl -b -p warning
systemctl --failed
systemctl --user --failed
```

## Adding or replacing a host

This repository does not promise a generic installer. To adapt it for another
machine, generate and review a new `hardware.nix`, add a host module, choose the
desktop or server constructor in `flake.nix`, replace user and SSH identity
assumptions, provision a valid SOPS age key, and review every display,
filesystem, power, and GPU setting before the first switch.

Never copy another host's hardware module or private identity files blindly.
Use `nixos-rebuild test` from an existing bootable generation before making a
new host configuration persistent.

## Continuous integration

GitHub Actions runs `nix flake check --no-build` and builds the complete Titan,
Tethys, and Iapetus system closures on every push and pull request. A green CI
run proves evaluation and buildability from the committed flake; it does not
exercise GPU drivers, displays, fingerprint readers, suspend/hibernate, SOPS
key availability, or a live graphical session. Those remain host acceptance
tests.

## License

Original configuration, scripts, and documentation in this repository are
licensed under [GPL-3.0-only](LICENSE). Files derived from or copied from
upstream projects retain their upstream copyright and license terms.
