{ config, pkgs, ... }: {
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
    ./gaming.nix
  ];

  networking.hostName = "galileo";

  boot = {
    initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
    extraModprobeConfig = ''
      options hid_apple swap_opt_cmd=1
    '';
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

  };

  security.polkit.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment = {
    etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = builtins.toJSON {
      rules = [{
        pattern = { feature = "procname"; matches = ["dwl"]; };
        profile = { feature = "OglFreeBufferPoolLimit"; value = 100; };
      }];
    };

    sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
      WLR_RENDERER = "gles2";
      WLR_DRM_DEVICES = "/dev/dri/card0:/dev/dri/card1";
    };
  };
}
