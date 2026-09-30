#!/usr/bin/env bash
# Finishes a fresh install of coriolis: Secure Boot, unlocking the disk from
# the TPM, then the accounts. Run it on the installed system:
#
#   ~/nixos/setup.sh
#
# It works out by itself how far things are, does the next step, and tells
# you when to reboot. Run it again after every reboot until it says it is
# done. Running it on a finished system changes nothing.
set -euo pipefail

HOST=coriolis
REPO=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
LUKS=/dev/disk/by-partlabel/disk-main-luks
ENROLLED=/var/lib/sbctl/keys-enrolled
EFI=8be4df61-93ca-11d2-aa0d-00e098032b8c

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() {
  printf '\n\033[31merror:\033[0m %s\n' "$*" >&2
  exit 1
}
# Last byte of an EFI variable: 1 or 0.
efi() { od -An -tu1 -j4 -N1 "/sys/firmware/efi/efivars/$1-$EFI" 2>/dev/null | tr -d ' '; }
rebuild() { sudo nixos-rebuild switch --flake "$REPO#$HOST"; }
to_firmware() {
  echo
  read -r -p "Press Enter to reboot into the firmware, Ctrl-C to do it later. "
  sudo systemctl reboot --firmware-setup
}

[ "$(id -u)" -ne 0 ] || die "run this as yourself, it calls sudo itself"
[ "$(hostname)" = "$HOST" ] || die "this is not $HOST"

# ---- 1. Secure Boot ------------------------------------------------------------

if [ ! -d /var/lib/sbctl/keys ]; then
  say "Secure Boot 1/3: creating the keys and signing the boot files"
  sudo sbctl create-keys
  rebuild
  echo
  # The files named kernel-* are not signed and are not meant to be.
  if sudo sbctl verify | grep -v '/kernel-' | grep -q 'is not signed'; then
    sudo sbctl verify
    die "a boot file other than kernel-* is not signed. Do not enable Secure Boot. Fix this first."
  fi
  cat <<'EOF'
All boot files are signed. Now the firmware has to forget its own keys:

  1. "Administer Secure Boot"
  2. Open "PK Options", "KEK Options" and "DB Options" in turn, and in each
     one delete every entry by hand.
     Do NOT use "Erase all Secure Boot Settings", it is broken on Framework.
  3. F10 to save.

Then boot back into NixOS and run this script again.
EOF
  to_firmware
fi

if [ "$(efi SetupMode)" = 1 ]; then
  say "Secure Boot 2/3: enrolling the keys"
  # --firmware-builtin keeps Framework's own keys, firmware updates need them.
  sudo sbctl enroll-keys --microsoft --firmware-builtin
  sudo touch "$ENROLLED"
  cat <<'EOF'
Enrolled. Now switch it on:

  1. "Administer Secure Boot"
  2. Turn on "Enforce Secure Boot"
  3. F10 to save.

Then boot back into NixOS and run this script again.
EOF
  to_firmware
fi

if [ "$(efi SecureBoot)" != 1 ]; then
  say "Secure Boot is still off"
  if [ -e "$ENROLLED" ]; then
    echo 'The keys are enrolled. In the firmware: "Administer Secure Boot", turn on'
    echo '"Enforce Secure Boot", F10. Then run this script again.'
  else
    echo 'The firmware still has its own keys. In "Administer Secure Boot", open'
    echo '"PK Options", "KEK Options" and "DB Options" and delete every entry by hand'
    echo '(not "Erase all Secure Boot Settings"). F10, then run this script again.'
  fi
  to_firmware
fi

say "Secure Boot is on"

# ---- 2. TPM --------------------------------------------------------------------

if ! sudo cryptsetup luksDump "$LUKS" | grep -q systemd-tpm2; then
  say "TPM: letting it unlock the disk. Type the disk passphrase when asked."
  # PCR 7 is the Secure Boot state. The passphrase stays valid as the way in
  # when the TPM refuses.
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$LUKS"
  cat <<'EOF'

Done. After the reboot the disk unlocks by itself and ly asks for your
password. Then run this script once more, for the accounts.
EOF
  read -r -p "Press Enter to reboot, Ctrl-C to do it later. "
  sudo systemctl reboot
fi

say "The TPM unlocks the disk"

# ---- 3. Accounts ---------------------------------------------------------------
# Nothing here is needed to boot. Each part is skipped once it is done.

AGE_KEY=$HOME/.config/sops/age/keys.txt
MAIL_SECRET=$HOME/.config/sops-nix/secrets/mail_personal

# The SSH key and the mail passwords are in secrets/secrets.yaml. They
# unlock with the master key, which is the one file that has to be restored.
if [ ! -f "$AGE_KEY" ]; then
  say "The master key is missing"
  cat <<EOF
Restore it from your backup to:

  $AGE_KEY

Then run this script again. Without it there is no SSH key for GitHub and
no mail password.
EOF
  exit 1
fi
chmod 600 "$AGE_KEY"

if [ ! -e "$MAIL_SECRET" ]; then
  say "Unlocking the secrets"
  systemctl --user restart sops-nix.service ||
    die "the master key does not open secrets/secrets.yaml. See: journalctl --user -u sops-nix"
fi

# The university account is the one login that cannot be stored. Microsoft
# hands out its token after a sign-in in the browser and replaces it as it
# is used, so it is asked for once per install.
systemctl --user start gpg-key-import.service
if ! oama access emiliohurtado@mail.ucv.es >/dev/null 2>&1; then
  say "University mail: sign in to Microsoft"
  oama authorize microsoft emiliohurtado@mail.ucv.es --device
fi

if [ ! -d "$HOME/email/personal/INBOX" ]; then
  say "Downloading the mail"
  mbsync -a || echo "mbsync reported errors, see above."
  mu index
fi

say "Done"
cat <<'EOF'
Left, by hand:
  - Commit what changed in ~/nixos (the hardware config) and push.
  - Firmware updates: fwupdmgr refresh && fwupdmgr update
  - Restore your backup, sign in to whatever needs it.
EOF
