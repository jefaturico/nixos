# Iapetus host specification

Iapetus is a Lenovo laptop repurposed as the lightweight always-available
server and Syncthing hub. It intentionally uses a smaller NixOS module stack
than the graphical hosts.

The live inventory was observed on 2026-08-14 through an existing trusted SSH
path. Model names and running software are a snapshot; `default.nix` and
`hardware.nix` remain authoritative. Do not add serial numbers, filesystem
UUIDs, MAC addresses, public keys, Syncthing IDs, or other unique identifiers
to this document.

## Hardware inventory

| Component | Current hardware |
| --- | --- |
| Chassis | Lenovo Ideapad 330-15ICH, model `81FK`, UEFI |
| Architecture | `x86_64-linux` |
| CPU | Intel Core i7-8750H, 6 cores / 12 threads |
| Virtualization | Intel VT-x; `kvm-intel` is loaded by the host configuration |
| Graphics | Intel integrated graphics on `i915` plus discrete NVIDIA graphics on `nouveau`; neither is part of the server role |
| Memory | 20 GB installed class; Linux exposes approximately 19 GiB |
| System storage | 1 TB Toshiba `MQ04ABF100` hard drive, approximately 931.5 GiB usable |
| Secondary storage | 1 TB Crucial P1 NVMe (`CT1000P1SSD8`) containing an unmanaged NTFS partition |
| Networking | Realtek `r8169` Ethernet; Tailscale provides the trusted remote path |
| Power | Internal battery and mains adapter |

The system disk has a 1 GiB FAT32 EFI partition, 4 GiB disk swap, and one large
ext4 root filesystem. The secondary NTFS volume is not declared or mounted by
this NixOS configuration; do not repurpose or format it as part of unrelated
server work.

### Observed software baseline

| Item | Observed value on 2026-08-14 |
| --- | --- |
| NixOS generation | 26.05 (`26.05.20260611.a037402`, Yarara) |
| Kernel | Linux 6.18.35, x86_64 |
| Runtime swap | Approximately 9.7 GiB zram plus 4 GiB disk swap |
| Primary role | Headless SSH/Tailscale/Syncthing server |

These values describe the running generation and may lag the repository until
the host is rebuilt. The flake lock and Iapetus closure select the next build.

## Declared policy

Iapetus uses `mkServerHost`, importing only its hardware module and
`common/syncthing.nix`. It deliberately does not inherit Home Manager,
Flatpak, SOPS integration, Bluetooth, the graphical application set, or the
desktop session services.

`hosts/iapetus/default.nix` provides:

- systemd-boot with five retained configurations and the shared Madrid/US
  locale conventions.
- NetworkManager, a firewall that trusts Tailscale, and Tailscale client mode.
- OpenSSH with password and keyboard-interactive authentication disabled, root
  login disabled, and no general public firewall opening.
- Syncthing as the hub for Titan and Tethys and as a participant in the folders
  declared by `common/syncthing.nix`.
- `thermald`, weekly store garbage collection, filesystem trim, and automatic
  Nix store optimization.
- TLP policy: boost disabled and energy preference `power` on battery; boost
  enabled and `balance_performance` on AC; PCIe ASPM uses powersave on battery.
- logind lid actions set to ignore so closing the repurposed laptop does not
  suspend the server.
- zram at 50% of RAM, higher priority than disk swap, with high swappiness and
  `vm.page-cluster = 0`.
- A minimal command-line package set and the `rebuild-push` helper. On Iapetus,
  that helper is the Git owner workflow and can offer commit/push after rebuild;
  its interactive publishing behavior is not an unattended service.

`hardware.nix` owns the root/EFI/swap devices, SATA/USB initrd support, Intel
virtualization, platform declaration, and Intel microcode. Keep identifiers
there rather than duplicating them in documentation.

## Change map

| Desired change | Edit | Also inspect |
| --- | --- | --- |
| Boot disk, filesystem, swap, initrd, or CPU facts | `hardware.nix` | Actual block devices and a retained boot generation |
| SSH, Tailscale, thermal, TLP, garbage collection, or server packages | `default.nix` | Remote reachability and battery/AC behavior |
| Syncthing topology, folders, or exclusions | `common/syncthing.nix` | Titan/Tethys peers and phone participation |
| Host constructor or desktop/server boundary | `flake.nix` | All three host evaluations and closure size |

## Validation checklist

Unprivileged checks:

```sh
nix flake check path:. --no-build
nix build path:.#nixosConfigurations.iapetus.config.system.build.toplevel --no-link
```

After activation by the operator, test without closing the only trusted remote
session until a second connection succeeds:

- Reconnect through Tailscale with public password/root login still rejected.
- Confirm SSH and Syncthing are active and the expected peers/folders converge
  without sync-conflict files.
- Confirm the firewall trusts only the intended tailnet path and the server is
  not unintentionally exposed on another interface.
- Check AC/battery TLP state, thermals, zram/disk-swap priority, and that closing
  the lid does not suspend the machine.
- Reboot once for boot/storage changes and verify the root and EFI filesystems;
  leave the unmanaged NTFS disk untouched unless explicitly in scope.

Useful diagnostics:

```sh
systemctl status sshd tailscaled syncthing thermald tlp
tailscale status
ss -lntup
swapon --show
findmnt / /boot
journalctl -b -p warning
```
