# coriolis

NixOS on the Framework Laptop 13 (AMD Ryzen AI 300). How to set it up from
nothing.

`install.sh` has never done a real install, it is checked for syntax only.
`setup.sh` has only run on the finished system, where it has nothing to do.
Both use the commands this machine was installed with by hand.

## 1. Back up

The install erases the whole disk. Back up everything you want to keep, and
push this repo.

One file has to be in that backup: `~/.config/sops/age/keys.txt`. It opens
the secrets stored in this repo (the GitHub key, the mail passwords, the
GPG key).

## 2. Install

You need:

- A NixOS minimal ISO on a USB stick, the release named in `flake.nix`.
- A keyboard on a cable, or the laptop's own. Bluetooth does not work at
  the disk passphrase prompt.
- One password, used as the disk passphrase and as the user password.

Steps:

1. Firmware (F2 at power on), "Administer Secure Boot": turn **"Enforce
   Secure Boot" off**. The installer will not boot otherwise.
2. Boot the USB stick (F12 at power on).
3. Network: the dock's cable works by itself, otherwise `nmtui`.
4. Get the repo and run the installer:

   ```sh
   nix-shell -p git --run 'git clone https://github.com/jefaturico/nixos /tmp/nixos'
   /tmp/nixos/install.sh
   ```

5. It shows the disk and asks you to type its name. Then it asks for the
   disk passphrase (twice) and the user password (twice), and reboots.
6. Pull the USB stick. It asks for the disk passphrase and goes straight
   into Hyprland.

## 3. Set up

Put the master key back first:

```sh
mkdir -p ~/.config/sops/age
cp /path/to/backup/keys.txt ~/.config/sops/age/keys.txt
```

Then open a terminal (Mod+Return) and run:

```sh
~/nixos/setup.sh
```

Run it again after every reboot until it says it is done.

| Run | It does | You do |
|---|---|---|
| 1 | creates Secure Boot keys, signs the boot files, reboots into the firmware | "Administer Secure Boot": in "PK Options", "KEK Options" and "DB Options", delete every entry by hand. F10. |
| 2 | enrolls the keys, reboots into the firmware | "Administer Secure Boot": turn on "Enforce Secure Boot". F10. |
| 3 | lets the TPM unlock the disk, reboots | type the disk passphrase once |
| 4 | unlocks the secrets, university login, downloads the mail | sign in to Microsoft in the browser, once |

From run 3 on, the disk unlocks by itself and ly asks for your password.


After it says done:

```sh
cd ~/nixos
git remote set-url origin git@github.com:jefaturico/nixos.git
git add -A && git commit      # the detected hardware config
git push
fwupdmgr refresh && fwupdmgr update
```

Then restore your backup, and sign in to whatever needs it.

## Do not get these wrong

- **Never use "Erase all Secure Boot Settings"** in the firmware. It is
  broken on Framework. Delete the entries one by one.
- **The repo has to be at `~/nixos`.** The emacs config and the scripts
  are symlinks into it. `install.sh` puts it there.
- **Keep the installer USB stick.** Root is locked, so there is no
  emergency shell. If the machine will not boot, the stick is the way in.
- **Keep the disk passphrase.** The TPM unlocks the disk, but after a
  firmware update it can refuse, and then the passphrase prompt comes back.
  Type it, then enroll the TPM again:

  ```sh
  sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 \
    /dev/disk/by-partlabel/disk-main-luks
  ```

- **A bad rebuild is not a reinstall.** Hold space at power on, pick an
  older generation, then `sudo nixos-rebuild switch --rollback`.
- **Keep `~/.config/sops/age/keys.txt`.** It is in no repo. Lose it and
  the secrets in `secrets/secrets.yaml` are gone: make a new GitHub key and
  type the mail passwords again. Leak it and everything in that file has to
  be changed, because the file is public.
- **This repo is public.** Secrets go in `secrets/secrets.yaml` only, with
  `sops secrets/secrets.yaml`. Nothing secret goes anywhere else.

Day to day: `sudo nixos-rebuild switch --flake ~/nixos#coriolis`

## License

GPL-3.0, see `LICENSE`. It does not cover `dotfiles/wallpapers/`: those
images are not mine.
