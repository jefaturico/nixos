#!/usr/bin/env bash
# Installs coriolis. Run it from the NixOS installer, from inside this repo:
#
#   ./install.sh
#
# It ERASES the disk named in hosts/coriolis/disko.nix. It asks before it
# does, and it stops at the first thing that fails.
#
# It asks you for: the disk passphrase (twice), the user password (twice).
# Use the same string for both.
set -euo pipefail

HOST=coriolis
USERNAME=jefaturico
REPO=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
NIX=(nix --extra-experimental-features "nix-command flakes")

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() {
  printf '\n\033[31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

# ---- Checks ------------------------------------------------------------------

# First of all: refuse to run anywhere but the installer. This script erases
# a disk, and on an installed system that disk is the one you are running
# from. Three independent signs, any one stops it.
#   - The installer's root is a RAM disk. An installed system's is not.
#   - An installed system has this host's name.
#   - An installed system has the encrypted volume mounted outside /mnt.
#     (Mounted under /mnt is fine: that is a second attempt in the installer.)
root_fs=$(findmnt -n -o FSTYPE /)
if [ "$root_fs" != tmpfs ]; then
  die "this is an installed system (root is $root_fs, the installer's is tmpfs). Boot the installer USB stick to reinstall."
fi
if [ "$(hostname)" = "$HOST" ]; then
  die "this machine is already $HOST. Boot the installer USB stick to reinstall."
fi
if findmnt -rn -o TARGET,SOURCE | awk '$2 ~ /^\/dev\/mapper\/vg-/ && $1 !~ /^\/mnt(\/|$)/ { found = 1 } END { exit !found }'; then
  die "the encrypted volume is mounted outside /mnt, so this system is running from it. Boot the installer USB stick to reinstall."
fi

[ "$(id -u)" -ne 0 ] || die "run this as the installer's normal user, it calls sudo itself"
[ -d /sys/firmware/efi ] || die "not booted in UEFI mode"
[ -f "$REPO/flake.nix" ] || die "flake.nix not found next to this script"

# Flakes in a git repo need git, and the minimal installer may not have it.
if ! command -v git >/dev/null; then
  say "Fetching git"
  exec "${NIX[@]}" shell nixpkgs#git --command "$0" "$@"
fi

say "Checking the network"
until curl -sfI --max-time 10 https://cache.nixos.org >/dev/null; do
  echo "No connection. Opening nmtui, connect and quit it to continue."
  read -r -p "Press Enter. "
  nmtui
done

DISK=$("${NIX[@]}" eval --raw "$REPO#nixosConfigurations.$HOST-install.config.disko.devices.disk.main.device")
[ -b "$DISK" ] || die "$DISK (from hosts/$HOST/disko.nix) does not exist on this machine"

# Refuse to run from the installed system: there the disk is in use.
if lsblk -nro MOUNTPOINTS "$DISK" | grep -qvE '^(/mnt(/.*)?)?$'; then
  die "$DISK has mounted filesystems. This has to run from the installer USB stick."
fi

# ---- Confirm -----------------------------------------------------------------

say "This erases $DISK"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL "$DISK"
echo
read -r -p "Type the disk name ($(basename "$DISK")) to erase it and install: " answer
[ "$answer" = "$(basename "$DISK")" ] || die "not confirmed, nothing was changed"

# ---- Disk --------------------------------------------------------------------

say "Partitioning, encrypting, formatting. Type the disk passphrase when asked."
sudo "${NIX[@]}" run github:nix-community/disko/latest -- \
  --mode destroy,format,mount --flake "$REPO#$HOST-install"

findmnt /mnt >/dev/null || die "/mnt is not mounted, disko did not finish"
findmnt /mnt/boot >/dev/null || die "/mnt/boot is not mounted, disko did not finish"

# ---- Hardware ----------------------------------------------------------------

say "Detecting the hardware"
# The redirect runs as you on purpose: the repo is yours, not root's.
# shellcheck disable=SC2024
sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  >"$REPO/hosts/$HOST/hardware-configuration.nix"
git -C "$REPO" --no-pager diff --stat -- "hosts/$HOST/hardware-configuration.nix" || true

# ---- Install -----------------------------------------------------------------

say "Installing. This downloads the whole system."
sudo nixos-install --no-root-passwd --flake "$REPO#$HOST-install"

say "Password for $USERNAME. Use the disk passphrase."
until sudo nixos-enter --root /mnt -c "passwd $USERNAME"; do
  echo "That did not work, again."
done

# The dotfiles are symlinks into ~/nixos, so the repo has to be there before
# the first login.
say "Copying this repo to /home/$USERNAME/nixos"
sudo rm -rf "/mnt/home/$USERNAME/nixos"
sudo cp -a "$REPO" "/mnt/home/$USERNAME/nixos"
sudo nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME/nixos"

# ---- Done --------------------------------------------------------------------

say "Installed"
cat <<EOF
Next:
  1. Reboot and pull the USB stick.
  2. Type the disk passphrase. It goes straight into Hyprland.
  3. Open a terminal (Mod+Return) and run:  ~/nixos/setup.sh

EOF
read -r -p "Press Enter to reboot, Ctrl-C to stay in the installer. "
sudo reboot
