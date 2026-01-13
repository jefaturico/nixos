{ config, ... }: {
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "galileo";

  boot.extraModprobeConfig = ''
    options hid_apple swap_opt_cmd=1
  '';

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
  
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment = {
    etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = builtins.toJSON {
      rules = [{
        pattern = { feature = "procname"; matches = ["niri"]; };
        profile = { feature = "OglFreeBufferPoolLimit"; value = 100; };
      }];
    };

    sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      NIXOS_OZONE_WL = "1";
    };
  };
}
