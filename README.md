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
and minimalism. Host policy makes tradeoffs explicit: Tethys, for example,
uses different display refresh rates on AC and battery instead of imposing one
global compromise.

Where a maintained Nixpkgs option, upstream feature, community package, or
community patch fits the pinned system, it is preferred over bespoke code.
Local scripts and patches remain appropriate when they are small, isolated,
better matched to the hardware or workflow, and easier to reason about than an
additional framework or service.

## Hosts

| Host | Role | Configuration highlights |
| --- | --- | --- |
| [`titan`](hosts/titan/README.md) | NVIDIA desktop | Shared desktop applications and services, proprietary legacy NVIDIA driver, and coredump limits for large browser renderer crashes |
| [`tethys`](hosts/tethys/README.md) | Framework AMD laptop | Niri desktop, Framework hardware module, manual brightness controls, lid/battery handling, Steam, and Lutris |
| [`iapetus`](hosts/iapetus/README.md) | Lightweight server | SSH/Tailscale/Syncthing, storage and memory maintenance, and command-line tools without Home Manager, Flatpak, or the graphical desktop stack |

All hosts are currently `x86_64-linux` and expose flake outputs named after
their hostnames:

```sh
nix flake show
nix eval --raw .#nixosConfigurations.titan.config.networking.hostName
```

## Architecture

`flake.nix` has two constructors. `mkDesktopHost` adds the shared desktop host
module, Home Manager, Flatpak, and SOPS integration; `mkServerHost` evaluates a
smaller host module directly. Titan and Tethys use the desktop constructor,
while Iapetus owns its smaller service set explicitly.

### Architectural decisions

| Decision | Rationale and boundary |
| --- | --- |
| Stable NixOS and matching Home Manager | Keeps system and user module APIs aligned; the lock file pins each generation |
| Unstable input only for Codex | Updates one fast-moving tool without moving the operating system off stable |
| Separate desktop and server constructors | Keeps Home Manager, Flatpak, SOPS integration, and graphical assumptions out of Iapetus |
| Home Manager embedded in desktop builds | User services and most configuration activate and roll back with the system generation |
| systemd user session target | Gives helpers explicit ownership, restart policy, logging, and logout cleanup |
| X11 compatibility for selected Electron/Xwayland applications | Preserves current application stability; change only after testing affected applications under native Wayland |

The Helix directory under `dots/` is deliberately linked out of the Nix store,
so edits are visible immediately without a rebuild.

### Repository map

| Path | Responsibility |
| --- | --- |
| `flake.nix` / `flake.lock` | Inputs, host constructors, and pinned dependency graph |
| `hosts/<host>/default.nix` | Host role and machine-specific policy |
| `hosts/<host>/hardware.nix` | Generated or hardware-specific boot, filesystem, and platform settings |
| `common/configuration.nix` | Shared desktop NixOS services, users, boot policy, packages, and imports |
| `common/home.nix` | Home Manager entry point, user identity, SSH policy, and user module imports |
| `common/programs.nix` | Interactive applications, program settings, and desktop utilities |
| `common/services.nix` | Home Manager services such as Foot, Gammastep, and udiskie |
| `common/session.nix` | GTK/Qt session integration, MIME defaults, portals, and desktop environment variables |
| `common/theme.nix` / `common/matugen/` | Static light theme, wallpaper-derived dark theme, wallpaper state, and live propagation |
| `common/niri/` | Tethys niri session, desktop helpers, portal policy, and session services |
| `common/scripts.nix` / `common/scripts/` | Rebuild, battery, and laptop lid helpers |
| `common/secrets.nix` / `secrets/` | SOPS declarations and encrypted secret data |
| `common/syncthing.nix` | Devices, topology, folders, and synchronization exclusions |
| `dots/helix/` | Active out-of-store Helix configuration |
| `dots/niri/` | Active out-of-store niri configuration; edits apply through live reload without a rebuild |
| `.github/workflows/nix.yml` | Flake evaluation and builds for all three hosts |

## System design notes

### Desktop and session lifecycle

Tethys runs niri through its packaged systemd session. Niri owns
`graphical-session.target`; shared
helpers such as the Foot server, wallpaper, theme initialization,
the display-corner mask, and other session services attach directly to that
standard target.

One declared exception matters operationally: Tethys's `lid-monitor-only` unit has
`PartOf=graphical-session.target` but no `WantedBy`, so current configuration
does not start it automatically. Do not mistake declaration for enablement or
silently repair that lifecycle while working on an unrelated feature.

Using user units gives each helper an independent restart policy and journal.
It also keeps optional session processes out of a single opaque startup shell
script.

Tethys enables the ordinary NixOS Steam client without adding a separate Steam
login session, replacement desktop entry, or nested compositor.

### Theme and mutable state

Matugen derives cohesive light and dark terminal, launcher, and notification
colors directly from the selected wallpaper. `system-theme`
persists which generated variant is active through dconf and reapplies it at
session startup. `wallpaper-switcher` stores the selected wallpaper under the
user's state directory and maintains the mutable `~/.wbg` launcher.

### Web browsing

Qutebrowser is the default browser and owns the desktop HTTP, HTTPS, and HTML
handlers. Its declarative baseline restores the previous session lazily,
blocks ads with the packaged ABP engine, disables autoplay, uses DuckDuckGo by
default, and opens external text editing in Helix through Foot. Interactive
per-site permissions and exceptions remain writable. Brave stays installed as
the compatibility fallback for DRM, browser extensions, conferencing, and
sites that do not work correctly through QtWebEngine; LibreWolf is not part of
the installed desktop set.

### Secrets and remote access

This repository is public solely so a new machine can clone it before GitHub
credentials have been provisioned:

```sh
git clone https://github.com/jefaturico/nixos.git ~/nixos
```

Public availability is a deployment convenience, not a privacy boundary.
Committed hostnames, user names, public SSH keys, Syncthing device IDs, age
recipients, hardware models, and filesystem UUIDs must be assumed permanently
public. Private keys and plaintext secrets must never be committed. Review new
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

### Synchronization

Syncthing treats Iapetus as the hub for Titan and Tethys, while the two desktop
hosts can also synchronize directly. A phone peer participates only in the
selected folders that opt into it. The NixOS folder excludes agent state,
local Codex state, build results, and sync-conflict files.

The topology provides an always-available convergence point without forcing
nearby desktop peers to relay through it. Device IDs and other operational
identifiers remain in the Nix module rather than being duplicated here.

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
services and NixOS modules are activated by the rebuild. Changes in the
out-of-store Helix tree do not require a rebuild.

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
garbage collection keeps the latest ten generations. Do not change
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
filesystem, power, GPU, and Syncthing setting before the first switch.

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
