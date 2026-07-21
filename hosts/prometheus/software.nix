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

  # The ThinkPad X201i boots in legacy BIOS mode. The shared desktop module
  # defaults to systemd-boot on UEFI, so override it with BIOS GRUB here.
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      enable = true;
      device = "/dev/sda";
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "ondemand";
      PCIE_ASPM_ON_BAT = "powersave";
    };
  };

  zramSwap = {
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl."vm.page-cluster" = 0;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };
}
