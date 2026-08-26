{
  inputs,
  pkgs,
  ...
}:

# Tethys: a Framework laptop (AMD AI 300 series). This file carries the
# feature list plus the firmware, power, and chassis facts that are true of
# this machine and nowhere else.
let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./hardware.nix
    ../../programs/antigravity.nix
    ../../programs/bash.nix
    ../../programs/brave.nix
    ../../programs/calcurse.nix
    ../../programs/claude-code.nix
    ../../programs/codex.nix
    ../../programs/emacs.nix
    ../../programs/fprintd.nix
    ../../programs/fuzzel.nix
    ../../programs/fzf.nix
    ../../programs/git.nix
    ../../programs/imv.nix
    ../../programs/keyd.nix
    ../../programs/kitty.nix
    ../../programs/librewolf.nix
    ../../programs/ly.nix
    ../../programs/mako.nix
    ../../programs/mpv.nix
    ../../programs/neovim.nix
    ../../programs/niri.nix
    ../../programs/pdf-find.nix
    ../../programs/sioyek.nix
    ../../programs/steam.nix
    ../../programs/swayidle.nix
    ../../programs/typst.nix
    ../../programs/waylock.nix
    ../../programs/wbg.nix
    ../../programs/zoxide.nix
    ../../system/audio.nix
    ../../system/battery.nix
    ../../system/bluetooth.nix
    ../../system/boot.nix
    ../../system/fonts.nix
    ../../system/keyboard.nix
    ../../system/locale.nix
    ../../system/network.nix
    ../../system/nix.nix
    ../../system/packages.nix
    ../../system/removable-media.nix
    ../../system/users.nix
    ../../system/xdg.nix
    ../../system/theme
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  # Mesa 26.1.5 decodes AV1 incorrectly on this APU (radeonsi/krackan1),
  # producing blocky colour artifacts wherever VA-API AV1 is used -- which is
  # most YouTube playback. Verified against the stable release: hardware VP9
  # decode is bit-exact while hardware AV1 drifts from the software decoder,
  # and 26.2.1 restores a bit-exact match. Drop this once stable catches up.
  hardware.graphics = {
    package = unstable.mesa;
    package32 = unstable.pkgsi686Linux.mesa;
  };

  networking.hostName = "tethys";
  networking.networkmanager.wifi.powersave = true;

  # Keep both kernel interfaces for the same physical keyboard backlight off.
  # Matching change events also neutralizes accidental brightness-key presses.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="chromeos::kbd_backlight", ATTR{brightness}="0"
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="framework_laptop::kbd_backlight", ATTR{brightness}="0"
  '';

  # Fn+F10 is exposed as a separate Framework wireless-radio input device.
  # Claim it explicitly because keyd's wildcard only matches full keyboards.
  services.keyd.keyboards.framework-radio = {
    ids = [ "32ac:0006" ];
    settings.main.rfkill = "noop";
  };

  services.logind.settings.Login = {
    HandlePowerKey = "hibernate";
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  # zram absorbs the working set in compressed RAM; a high swappiness is the
  # documented pairing because reclaim to zram is far cheaper than to disk.
  zramSwap = {
    enable = true;
    memoryPercent = 100;
    priority = 100;
  };
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  services.fstrim.enable = true;

  # memfd_secret disables kernel hibernation (secretmem_active). Disable it at
  # boot so hibernation to the disk-backed swap remains functional.
  # pm_async=off forces synchronous device power transitions, preventing
  # MediaTek Wi-Fi (mt7925e) IOMMU page faults and hangs during poweroff.
  boot.kernelParams = [
    "secretmem.enable=0"
    "pm_async=off"
  ];

  systemd.tmpfiles.rules = [
    "w /sys/power/pm_async - - - - 0"
  ];

  # Platform (ACPI S4) hibernation aborts on this hardware due to a firmware
  # wakeup event during sleep state transition. Use shutdown mode so the kernel
  # writes the snapshot to disk and powers off cleanly.
  systemd.sleep.settings.Sleep.HibernateMode = "shutdown";

  system.stateVersion = "26.05";
}
