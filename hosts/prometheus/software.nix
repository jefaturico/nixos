{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "prometheus";

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  # The ThinkPad X201i boots in legacy BIOS mode. The shared desktop module
  # defaults to systemd-boot on UEFI, so override it with BIOS GRUB here.
  boot = {
    loader = {
      # Boot immediately in the normal case. Holding Shift or pressing Esc/F4
      # during the firmware handoff still exposes the GRUB menu.
      timeout = 0;
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
      grub = {
        enable = true;
        device = "/dev/sda";
        timeoutStyle = "hidden";
      };
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      # acpi-cpufreq on this Westmere CPU has no "powersave" governor.
      # schedutil remains responsive while selecting low clocks when idle.
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
      CPU_SCALING_GOVERNOR_ON_AC = "ondemand";

      # Favour throughput on mains and power saving for idle peripherals on
      # battery.  These are deliberately handled by TLP so they switch with
      # the power source instead of being fixed kernel-wide.
      SCHED_POWERSAVE_ON_BAT = 1;
      NMI_WATCHDOG = 0;
      PCIE_ASPM_ON_BAT = "powersave";
      PCIE_ASPM_ON_AC = "default";
      WIFI_PWR_ON_BAT = "on";
      WIFI_PWR_ON_AC = "off";
      WOL_DISABLE = "Y";
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
      SATA_LINKPWR_ON_AC = "max_performance";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      AHCI_RUNTIME_PM_ON_AC = "on";
      AHCI_RUNTIME_PM_TIMEOUT = 15;
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_AC = "on";
      USB_AUTOSUSPEND = 1;
    };
  };

  zramSwap = {
    # LZ4 has very low CPU overhead on this older dual-core processor.
    algorithm = "lz4";
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl = {
    # Avoid read-ahead that is useful for disks but wasteful for compressed RAM.
    "vm.page-cluster" = 0;
    # Laptop workloads benefit from batching background writeback, reducing
    # SSD wakeups without risking large amounts of dirty memory.
    "vm.dirty_writeback_centisecs" = 1500;
  };

  # Avoid metadata writes on every file read; the SSD does not need atime.
  fileSystems."/".options = [ "noatime" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };

  # Authorize power actions requested by the unprivileged Eureka session.
  security.polkit.enable = true;
}
