{ config, ... }:
{
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "galileo";

  boot = {
    initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    extraModprobeConfig = ''
      options hid_apple swap_opt_cmd=1
    '';
  };

  hardware = {
    uinput.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  services.ratbagd.enable = true;
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  users.groups.uinput.members = [ "jefaturico" ];
  systemd.user.services.sunshine.environment = {
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  security.polkit.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  environment = {
    etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
      builtins.toJSON {
        rules = [
          {
            pattern = {
              feature = "procname";
              matches = [ "niri" ];
            };
            profile = {
              feature = "OglFreeBufferPoolLimit";
              value = 100;
            };
          }
        ];
      };

    sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __GL_GSYNC_ALLOWED = "1";
      __GL_VRR_ALLOWED = "1";
      __GL_MAX_FRAMES_ALLOWED = "1";
      NVD_BACKEND = "direct";
    };
  };
}
