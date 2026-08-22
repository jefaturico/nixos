# Titan host specification

Titan is the NVIDIA gaming desktop. It runs the same session, applications,
keybindings, and theme as Tethys; the two differ only in hardware. This file
records its hardware inventory, host-only policy, and acceptance tests so
changes can be evaluated against the actual machine rather than a generic
desktop.

The live inventory was observed on 2026-08-14. Model names and running software
are a snapshot; `default.nix` and `hardware.nix` remain the configuration source
of truth. Do not add serial numbers, filesystem UUIDs, MAC addresses, public
keys, or other unique identifiers here.

## Hardware inventory

| Component | Current hardware |
| --- | --- |
| Platform | MSI Z270I Gaming Pro Carbon AC (`MS-7A66`), UEFI, `x86_64-linux` |
| CPU | Intel Core i7-7700K, 4 cores / 8 threads, up to 4.5 GHz |
| Virtualization | Intel VT-x; `kvm-intel` is loaded by the host configuration |
| Discrete graphics | NVIDIA GeForce GTX 1080 Ti, 11 GiB VRAM |
| Integrated graphics | Intel graphics driven by `i915`; the NVIDIA GPU drives the active display |
| Memory | 32 GB installed class; Linux exposes approximately 31 GiB |
| System storage | 256 GB-class Transcend `TS256GMTS800`, approximately 238.5 GiB usable |
| Data storage | 2 TB-class Seagate `ST2000LM015-2E8174`, mounted at `/mnt/data` |
| Active display | NVIDIA `DP-1`; currently advertises modes up to 1920×1080 |
| Networking | Intel `e1000e` Ethernet and Intel `iwlwifi` wireless |

The system disk has a 1 GiB FAT32 EFI partition, 4 GiB disk swap, and an ext4
root filesystem using `noatime`. The data disk is a separate ext4 filesystem
with `nofail`, so its absence must not prevent boot.

### Observed software baseline

| Item | Observed value on 2026-08-14 |
| --- | --- |
| NixOS generation | 26.05 (`26.05.20260722.b3fe958`, Yarara) |
| Kernel | Linux 6.18.39, x86_64 |
| NVIDIA driver | Proprietary 580.173.02 through the configured legacy-580 package |
| Runtime swap | Approximately 15.6 GiB zram plus 4 GiB disk swap |
| Graphical session | Niri through its packaged systemd session under Ly, shared with Tethys |

These values describe the running generation, not version pins. `flake.lock`
and the evaluated host closure select the next build.

## Declared policy

`hosts/titan/default.nix` owns desktop-specific policy:

- Imports the generated hardware module and the full shared desktop stack.
- Loads NVIDIA DRM, modesetting, and UVM modules in the initrd so the graphical
  stack is available early.
- Uses the proprietary legacy-580 NVIDIA package with modesetting and power
  management enabled; the open kernel module is deliberately disabled.
- Sets the NVIDIA VA-API, GBM, GLX vendor, and video decode environment expected
  by the current Wayland/Xwayland stack.
- Disables retained coredumps and core processing. Large simultaneous Brave
  renderer crashes previously exhausted memory and saturated storage; journal
  metadata is retained without storing or inspecting multi-gigabyte cores.
- Swaps Option/Command behavior for Apple-compatible keyboards and enables
  faster Bluetooth connection establishment.

`hosts/titan/hardware.nix` owns the filesystems, swap device, initrd storage and
USB drivers, Intel virtualization module, platform declaration, and Intel
microcode policy. UUIDs stay in that file and must not be copied here.

## Runtime behavior inherited from shared modules

Titan is constructed with `mkDesktopHost` and imports the full desktop feature
list — `base`, `users`, `network`, `secrets`, `login`, `input`, `desktop`,
`compositor`, `theme`, `terminal`, `shell`, `editor`, `browsing`, `documents`,
`media`, `development`, `packages`, `ergonomics`, and `gaming` — the same list
Tethys uses.

The one feature Titan does not import is `laptop`, because it has no battery
or lid. Tethys's `display-corner-mask` is likewise a chassis-specific
service and stays in that host module.

Niri on the proprietary NVIDIA driver has **not been exercised on this
hardware yet**. The host already sets `modesetting.enable`, `GBM_BACKEND`,
`__GLX_VENDOR_LIBRARY_NAME`, and `NVD_BACKEND`, which is the configuration niri
expects, but the first switch is an acceptance test: confirm the session
starts, that Xwayland clients render through `xwayland-satellite`, and that
Steam and Proton titles pick up the discrete GPU.

## Change map

| Desired change | Edit | Also inspect |
| --- | --- | --- |
| Disk, filesystem, swap, initrd, or CPU facts | `hardware.nix` | Actual block devices and boot behavior |
| NVIDIA driver, module, VA-API, or coredump policy | `default.nix` | Current kernel/Nixpkgs and graphical-session behavior |
| Shared desktop service or application | The owning `features/` directory | Tethys impact and both desktop builds |

## Validation checklist

Unprivileged checks:

```sh
nix flake check path:. --no-build
nix build path:.#nixosConfigurations.titan.config.system.build.toplevel --no-link
```

After the new generation is activated by the operator, test the affected area:

- Start the niri session with the NVIDIA display attached
  through DisplayPort and test native Wayland and Xwayland clients.
- Confirm `nvidia-smi` reports the intended driver/GPU and that the session does
  not fall back to software rendering.
- Attach/detach any secondary output and verify mode selection, scale,
  wallpaper redraw, and client movement between monitors.
- Verify `/mnt/data` when present and confirm the machine still boots when the
  `nofail` data disk is unavailable.
- For coredump-policy changes, reproduce only with a controlled disposable
  process; do not intentionally crash memory-heavy desktop applications.

Useful diagnostics:

```sh
nvidia-smi
wlr-randr
journalctl -b --grep=nvidia
systemctl --user status graphical-session.target
findmnt / /boot /mnt/data
```
