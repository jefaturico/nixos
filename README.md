# coriolis

NixOS on the Framework Laptop 13 (AMD Ryzen AI 300), disk `/dev/nvme0n1`.

The configuration evaluates, in all three stages below. It has never been
installed. The steps are in order; each section assumes the one before it
is done.

## 0. Before

The install erases the whole disk.

The SD card is mounted at `/tmp/sd`. It is FAT: no permissions, no
symlinks, and writing to it needs `sudo`.

- [ ] This repo is committed and on the card as an archive. An archive
      because the card cannot store permissions; committed because a repo
      without commits cannot be pushed later. Redo this after the last
      change to the repo.

      ```sh
      cd ~/nixos && git add -A && git commit -m "NixOS configuration for coriolis"
      tar -czf ~/nixos.tar.gz -C ~ nixos
      sudo cp ~/nixos.tar.gz /tmp/sd/ && sync
      ```

- [ ] Your data is on the card. Already there: `documents`, `images`,
      `projects`, `investments.md`. Not there yet, copy what you want to
      keep:

      | Path | What |
      |---|---|
      | `~/org` | agenda, journal, notes, todo |
      | `~/.task`, `~/.local/share/calcurse` | tasks, calendar |
      | `~/.local/share/sioyek` | reading positions, highlights |
      | `~/.local/share/Anki2` | Anki, unless synced to AnkiWeb |
      | `~/downloads` | certificates, transcript, travel documents |
      | `~/university-mail-backup-2026-09-29.tar.gz` | mail backup |
      | `~/Zomboid` | game saves |
      | `~/.thunderbird`, `~/.config/BraveSoftware` | or sign in again |

      `~/projects/ctd-data-processing` has no other copy anywhere.

- [ ] The Claude Code folder is on the card. Copy it again right before
      wiping, it changes with every session. It holds the login in
      plaintext, so keep the card with you.

      ```sh
      sudo rm -rf /tmp/sd/.claude
      sudo cp -r ~/.claude ~/.claude.json /tmp/sd/ && sync
      ```

- [ ] NixOS 26.05 minimal ISO on a USB stick.
- [ ] Firmware (F2 at power on): Secure Boot is disabled. It is now, check
      that it still is.
- [ ] Optional, same place: battery charge limit at 80%, the laptop lives on
      the dock.

You will choose one password, the machine password. It is used twice in the
install: as the disk passphrase and as the user password.

## 1. Install

Boot the USB stick (F12 at power on for the boot menu).

1. Network. On the dock the wired connection works by itself. Otherwise:

   ```sh
   nmtui
   ```

2. Get the repo to `/tmp/nixos` from the SD card. Find the card with
   `lsblk`, it is the 29G one.

   ```sh
   sudo mkdir -p /media && sudo mount /dev/sdX1 /media
   tar -xzf /media/nixos.tar.gz -C /tmp
   ls /tmp/nixos/flake.nix
   ```

3. Check the disk. It has to be `nvme0n1`, 1.8T.

   ```sh
   lsblk
   ```

4. Partition, encrypt, format, mount. **This erases the disk.** It asks for
   the disk passphrase twice: type the machine password.

   ```sh
   sudo nix --experimental-features "nix-command flakes" run \
     github:nix-community/disko/latest -- \
     --mode destroy,format,mount --flake /tmp/nixos#coriolis
   ```

   Check that it worked: `findmnt /mnt /mnt/boot /mnt/home /mnt/nix`

5. Detect the hardware, replacing the file written by hand.

   ```sh
   sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
     > /tmp/nixos/hosts/coriolis/hardware-configuration.nix
   ```

6. Install. Root is locked, `sudo` is the way in.

   ```sh
   sudo nixos-install --no-root-passwd --flake /tmp/nixos#coriolis
   ```

7. Set the user password (the machine password again) and put the repo in
   place. The repo has to be at `~/nixos` before the first login, niri's
   config is a link into it.

   ```sh
   sudo nixos-enter --root /mnt -c 'passwd jefaturico'
   sudo cp -r /tmp/nixos /mnt/home/jefaturico/nixos
   sudo nixos-enter --root /mnt -c 'chown -R jefaturico:users /home/jefaturico/nixos'
   ```

8. `reboot`, and pull the USB stick.

It asks for the disk passphrase, then goes straight into niri.

If it does not boot: hold space at power on and pick an older generation.
If there is none yet, or that fails too: boot the USB stick again, repeat
steps 1 and 2, run step 4 with `--mode mount` (that one erases nothing),
fix the config, repeat steps 6 and 7.

## 2. First boot

The card: `sudo mkdir -p /media && sudo mount /dev/sdX1 /media`.

1. Commit the detected hardware config.

   ```sh
   cd ~/nixos && git add -A && git commit -m "Hardware config from the install"
   ```

2. GPG key. Leave the passphrase empty.

   ```sh
   gpg --full-generate-key
   gpg -K --keyid-format long
   ```

   Put the key ID in `home/mail.nix` (`gpgKey`) and rebuild.

3. Mail passwords and the university login.

   ```sh
   pass init <key id>
   pass insert mail/personal
   pass insert mail/google
   oama authorize microsoft emiliohurtado@mail.ucv.es --device
   mbsync -a && mu index
   ```

4. SSH key for GitHub. Add the `.pub` file to GitHub.

   ```sh
   ssh-keygen -t ed25519 -f ~/.ssh/id_coriolis-github
   ```

5. Put the repo on GitHub, as a private repo. Create it empty on GitHub
   first, then:

   ```sh
   cd ~/nixos
   git remote add origin git@github.com:<you>/nixos.git
   git push -u origin main
   ```

6. Restore the Claude Code folder, before running `claude` for the first
   time. After this `claude` is logged in.

   ```sh
   cp -r /media/.claude /media/.claude.json ~/
   chmod -R go= ~/.claude ~/.claude.json
   ```

   The `chmod` is needed: the card has no permissions, so the files come
   back readable by everyone. Afterwards delete both from the card.

7. Wi-Fi networks (`nmtui`), the Keychron K6 (`bluetui`), Steam, Brave,
   Thunderbird.

8. Firmware updates.

   ```sh
   fwupdmgr refresh && fwupdmgr update
   ```

9. Restore your data from the card. Two things the card lost:

   - Permissions. `seasenselib` will show every file as modified until:
     `git -C ~/projects/seasenselib config core.fileMode false`
   - Symlinks. The Python environment in `ctd-data-processing` (`.venv`) is
     broken, make it again.

10. Try hibernation: `systemctl hibernate`. It did not work on Arch and has
   not been debugged yet.

## 3. Secure Boot

Once the system boots and works.

1. Create the keys.

   ```sh
   sudo sbctl create-keys
   ```

2. In `hosts/coriolis/default.nix` set `coriolis.secureBoot = true;`, then:

   ```sh
   sudo nixos-rebuild switch --flake ~/nixos#coriolis
   sudo sbctl verify
   ```

   Everything has to be signed except the files starting with `kernel-`.

3. Reboot into the firmware (F2). Under "Administer Secure Boot", open "PK
   Options", "KEK Options" and "DB Options" in turn, and in each one delete
   every entry by hand. **Do not use "Erase all Secure Boot Settings"**, it
   is broken on Framework firmware. F10 to save.

4. Boot NixOS and enroll the keys. `--firmware-builtin` keeps Framework's
   own keys, which firmware updates need.

   ```sh
   sudo sbctl enroll-keys --microsoft --firmware-builtin
   ```

5. Reboot into the firmware, "Administer Secure Boot", turn on "Enforce
   Secure Boot". F10.

6. Check: `bootctl status` says `Secure Boot: enabled (user)`.

## 4. Disk unlock from the TPM

Once Secure Boot is enforced.

1. Enroll the TPM. It asks for the disk passphrase. The passphrase stays
   valid, it is the way in when the TPM refuses.

   ```sh
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
     /dev/disk/by-partlabel/disk-main-luks
   ```

2. In `hosts/coriolis/default.nix` set `coriolis.tpmUnlock = true;`, rebuild,
   reboot.

The disk unlocks by itself and ly asks for the password.

When the passphrase prompt comes back by itself, the Secure Boot state
changed (a firmware update can do that). Type the passphrase, then enroll
again:

```sh
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 \
  /dev/disk/by-partlabel/disk-main-luks
```

## Day to day

```sh
sudo nixos-rebuild switch --flake ~/nixos#coriolis   # apply changes
nix flake update                                     # newer packages, then rebuild
sudo nixos-rebuild switch --rollback                 # undo the last rebuild
```

Hold space at power on for the boot menu with the older generations.

Files under `dotfiles/` apply without a rebuild. New files have to be
`git add`ed before a rebuild sees them.
