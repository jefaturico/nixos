# Disk layout: GPT, 1G ESP, then one LUKS container holding LVM with
#   swap  32G   (hibernate target, encrypted along with everything else)
#   root  rest  btrfs with subvolumes
#
# One passphrase at boot unlocks both root and swap.
#
# DESTRUCTIVE: running disko with this file wipes `device` below.
{ ... }:
let
  btrfsOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      # Check with `lsblk` from the installer before running disko.
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # disko asks for the passphrase interactively, nothing is
              # written to disk or to this repo.
              settings.allowDiscards = true;
              content = {
                type = "lvm_pv";
                vg = "vg";
              };
            };
          };
        };
      };
    };

    lvm_vg.vg = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = "32G";
          content = {
            type = "swap";
            # Sets boot.resumeDevice, which is what makes hibernate work.
            resumeDevice = true;
          };
        };
        root = {
          size = "100%FREE";
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "nixos"
            ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = btrfsOpts;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = btrfsOpts;
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsOpts;
              };
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = btrfsOpts;
              };
              # Empty for now. With impermanence this is where the state
              # that has to survive a reboot lives.
              "@persist" = {
                mountpoint = "/persist";
                mountOptions = btrfsOpts;
              };
              # Empty for now, a place to put snapshots (snapper/btrbk) later.
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = btrfsOpts;
              };
            };
          };
        };
      };
    };
  };

  # /var/log must be there before journald starts, /persist before
  # anything that would read state from it.
  fileSystems."/var/log".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
}
