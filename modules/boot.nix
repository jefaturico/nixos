{ pkgs, ... }:
{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
        # Without this, anyone at the menu can edit the kernel command line
        # and get a root shell.
        editor = false;
        # Keep /boot (1G) from filling up with old generations.
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      # No menu, straight to the newest generation. Hold space while the
      # machine starts to get the menu and pick an older one.
      timeout = 0;
    };

    # Arch tracks the latest kernel, and this hardware (Ryzen AI 300,
    # MT7925 Wi-Fi 7) wants a recent one.
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      # Console at 1920x1280 on the laptop panel, so ly also fits the 1080p
      # external monitor. niri still uses the native modes.
      "video=eDP-1:1920x1280"
    ];

    # Was /etc/sysctl.d/20-quiet-printk.conf
    consoleLogLevel = 3;
    kernel.sysctl."kernel.printk" = "3 3 3 3";

    # systemd in the initrd, like the `systemd` mkinitcpio hook on Arch.
    # It unlocks LUKS and resumes from hibernation.
    initrd.systemd.enable = true;
  };

  # boot.resumeDevice comes from hosts/coriolis/disko.nix (resumeDevice = true).
}
