{ pkgs, ... }: {
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "ekman";

  boot.kernelParams = [
    "i915.enable_guc=3"
    "i915.enable_fbc=1"
  ];

  services.tlp = {
    enable = true;
    settings = {
      # Intel P-State EPP
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";

      # Disable Turbo Boost on battery
      CPU_BOOST_ON_BAT = 0;
      CPU_BOOST_ON_AC = 1;

      # PCIe ASPM
      PCIE_ASPM_ON_BAT = "powersave";
    };
  };

  services.thermald.enable = true;

  zramSwap = {
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl."vm.page-cluster" = 0;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # Modern driver (iHD)
      intel-vaapi-driver # Broadwell/KabyLake media driver backend
      libvdpau-va-gl
    ];
  };
  environment.systemPackages = with pkgs; [
    moonlight-qt
  ];
}
