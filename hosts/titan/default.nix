{ config, ... }:
{
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "titan";

  hardware.bluetooth.settings.General.FastConnectable = true;

  # Brave can crash several renderer processes at once while saving or printing
  # pages.  Processing those multi-gigabyte address spaces in parallel made
  # systemd-coredump exhaust RAM and saturate storage, freezing the session.
  # Keep the crash journal entries, but do not retain or inspect their cores.
  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = "0";
  };

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
    graphics.enable = true;
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
    sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      NVD_BACKEND = "direct";
    };
  };
}
