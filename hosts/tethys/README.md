# Tethys host specification

Tethys is the Framework Laptop 13 desktop host. It shares its entire session and application set with Titan; this file records only what is specific to this chassis. This file records its hardware
inventory and policy map and explains why `default.nix` and `hardware.nix`
differ from the shared desktop configuration.

The hardware inventory was observed on 2026-08-14. Treat quantities and model
names as a snapshot; treat the Nix settings under “Declared policy” as the
source of truth. Do not add serial numbers, filesystem UUIDs, MAC addresses,
public keys, or other unique identifiers to this document.

## Hardware inventory

| Component | Current hardware |
| --- | --- |
| Chassis | Framework Laptop 13, AMD Ryzen AI 300 Series, product revision A7 |
| Architecture | `x86_64-linux`, UEFI |
| CPU | AMD Ryzen AI 7 350, 8 cores / 16 threads, up to approximately 5.1 GHz |
| Virtualization | AMD-V; `kvm-amd` is loaded by the host configuration |
| Graphics | Integrated AMD Radeon 860M-class graphics, driven by `amdgpu` |
| Memory | 32 GB installed class; Linux exposes approximately 30.6 GiB |
| Internal storage | 2 TB-class Crucial P310 NVMe (`CT2000P310SSD8`, approximately 1.8 TiB usable) |
| Internal display | `eDP-1`, 2880×1920, scale 2, VRR capable |
| Wireless | MediaTek MT7925-family adapter, `mt7925e` driver |
| Power | Internal battery plus USB-C power inputs |

The disk has a 1 GiB FAT32 EFI system partition, a 32 GiB disk-backed swap
partition, and one large ext4 root filesystem using `noatime`. The root
filesystem also contains `/nix/store`, `/tmp`, and the repository; they are not
separate filesystems.

### Observed software baseline

| Item | Observed value on 2026-08-14 |
| --- | --- |
| NixOS generation | 26.05 (`26.05.20260722.b3fe958`, Yarara) |
| Kernel | Linux 6.18.39, x86_64 |
| Graphics kernel driver | `amdgpu` |
| Runtime swap | Approximately 30.6 GiB zram plus 32 GiB disk swap |
| Graphical session | Niri through its packaged systemd session under Ly |

These values describe the running generation, not upgrade constraints. The
flake inputs and lock file, rather than this table, select the next build.

## Declared policy

`hosts/tethys/default.nix` owns policy unique to this laptop:

- Imports the generated hardware module, shared desktop configuration, and the
  upstream `framework-amd-ai-300-series` NixOS hardware module.
- Enables Wi-Fi power saving, uses systemd-resolved as the link-aware DNS
  manager shared by NetworkManager and Tailscale, and lets the kernel choose a
  readable HiDPI virtual-console font.
- Imports the shared niri session. Output selection remains automatic and
  currently uses the preferred display mode rather than an AC-dependent
  refresh policy.
- Runs a minimal input-transparent layer-shell mask over the two lower corners
  of `eDP-1`, making the visible display area use the same 15-logical-pixel
  radius at all four corners. The mask is session-scoped, does not reserve
  layout space, and is not applied to external outputs.
- Maps power-button and lid actions through logind, and adds a keyd override
  for the Framework radio key that appears as a separate input device.
- Configures zram equal to 100% of RAM at higher priority than disk swap.
  `vm.page-cluster = 0` and `vm.swappiness = 100`, the settings that make
  compressed swapping responsive, are shared policy in `features/base`.
- Sets `boot.kernelParams = [ "secretmem.enable=0" "pm_async=off" ]` so
  `memfd_secret` users do not block Linux kernel hibernation and synchronous
  device powerdown prevents MediaTek Wi-Fi (`mt7925e`) IOMMU page faults and
  deadlocks during poweroff.
- Sets `systemd.sleep.settings.Sleep.HibernateMode = "shutdown"` because
  platform (ACPI S4) transitions fail with premature firmware wakeup events on
  this hardware, ensuring the kernel writes the snapshot to disk and powers off
  cleanly.

`hosts/tethys/hardware.nix` owns facts required to boot this installation:

- Initrd support for NVMe, xHCI, Thunderbolt, USB storage, and SCSI disks.
- The ext4 root filesystem, FAT32 EFI system partition, and disk swap device.
- Resume from disk-backed swap for hibernation. zram cannot preserve a resume
  image across power-off and must not replace the disk resume device.
- AMD microcode and the `x86_64-linux` platform declaration.

Do not move filesystem UUIDs or resume-device values into this README. They
belong only in `hardware.nix`.

## Runtime behavior inherited from shared modules

Tethys is constructed with `mkDesktopHost`, so it also receives:

- Niri, Home Manager configuration, Ly display manager, PipeWire, Bluetooth,
  portals, fingerprint PAM, keyd, Steam, Tailscale, SSH, and SOPS.
- Home Manager programs, the Foot server, Tinty-managed desktop colors,
  Gammastep, udiskie, and user session services.
- Targeted niri rules blur Fuzzel and Fnott over their 70% opaque themed
  backgrounds; Neovim uses transparent highlights inside the already blurred
  Foot terminal. Fnott uses the overlay layer so notifications remain visible
  above fullscreen windows; critical notifications persist until dismissed.
- Tethys is the only host that imports the `laptop` feature, which provides
  battery notifications and the lid monitor. The battery monitor
  reads capacity from sysfs every 30 seconds because this battery does not
  reliably emit a power-supply uevent for percentage changes. A
  `lid-monitor-only` unit is declared in the same module with no
  `Install.WantedBy`; it is not started automatically by the declarative
  session graph.

When started explicitly, the lid monitor is designed to turn off the internal
backlight while the lid is closed and keep a low-battery suspend guard running.
logind still owns the configured suspend action. Treat the missing enablement as
current system state, not as proven intent; do not silently enable it during an
unrelated task. If its lifecycle is changed, test open/close behavior on battery
and AC, including resume with the lid still closed.

Niri uses its packaged systemd session and owns `graphical-session.target`.
The compositor-independent `display-corner-mask` service overlays the two lower
15-pixel corner cutouts on `eDP-1`, attaches to that target, and does not reserve
layout space. Niri's idle, media-inhibit, notification, and PolicyKit units are
session-gated. `xwayland-satellite` is available in niri's session path and is
launched on demand for Steam and other X11 clients. Niri's upstream NixOS
module routes compositor-aware interfaces such as screencasting through the
GNOME portal. Visible file-selection, access, and notification interfaces are
explicitly routed through GTK for consistent dialogs without adding Nautilus.
GNOME Keyring and the Secret portal are disabled because credentials are
managed separately.

## Change map

| Desired change | Edit | Also inspect |
| --- | --- | --- |
| CPU, initrd, filesystem, swap, or resume facts | `hardware.nix` | Actual block devices and boot behavior |
| Laptop power, display, Steam, or special key policy | `default.nix` | `features/compositor/`, `features/laptop/` |
| Shared desktop service or package | The owning `features/` directory | Titan impact and full host evaluations |
| Desktop colors | `features/theme/` | Foot, Fuzzel, Fnott, and Neovim consumers |

## Validation checklist

For every Tethys change:

```sh
nix flake check --no-build
nix build .#nixosConfigurations.tethys.config.system.build.toplevel --no-link
sudo nixos-rebuild test --flake path:.#tethys
```

Then test the affected hardware manually. Relevant acceptance cases include:

- Start niri through Ly, then verify its essential bindings, touchpad gestures,
  Steam scaling, game resolutions and pointer capture, locking, suspend,
  notifications, PolicyKit prompts, screenshots, and clean logout back to Ly.
- Suspend, resume, hibernate, lid close/open, low-battery protection, the
  forced-off keyboard backlight, manual display-brightness keys, audio keys, and the
  Framework radio key. Keyboard-backlight key presses must leave both exposed
  LED interfaces at zero without affecting the display backlight.
- External display attach/detach and wallpaper redraw after a mode change.
- Both lower corner masks remain black, smooth, pointer-transparent, and
  correctly aligned after 60/120 Hz changes, fullscreen transitions, and
  suspend/resume. Session locking deliberately hides ordinary layer-shell
  surfaces, so verify the original physical lower corners remain acceptable on
  the lock screen.
- A previous systemd-boot generation remains bootable before changing disk,
  resume, GPU, or display policy.

Useful diagnostics:

```sh
wlr-randr
systemctl --user status display-corner-mask lid-monitor-only battery-check
journalctl --user -b -u display-corner-mask
journalctl --user -b -u lid-monitor-only
journalctl -b -u systemd-logind
cat /sys/class/power_supply/ACAD/online
```

Never run `nixos-rebuild switch` as the first validation step for a boot,
storage, resume, or display change. Build, use `test`, exercise the hardware,
then switch.
