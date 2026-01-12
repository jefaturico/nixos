{ inputs, config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "galileo";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "es";
  };

  programs.niri = {
    enable = true;
  };

  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "matrix";
      restore = true;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = [ "gnome" "gtk" ];
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  boot.extraModprobeConfig = ''
    options hid_apple swap_opt_cmd=1
  '';
  boot.initrd.kernelModules = [ "hid_apple" ];

  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = builtins.toJSON {
    rules = [
      {
        pattern = { feature = "procname"; matches = ["niri"]; };
        profile = { feature = "OglFreeBufferPoolLimit"; value = 100; };
      }
    ];
  };
  
  users.users.jefaturico = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "render" ];
    packages = with pkgs; [
      tree
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
  };

  services.syncthing = {
    enable = true;
    user = "jefaturico";
    dataDir = "/home/jefaturico";
    overrideDevices = true;
    overrideFolders = true; 
    extraFlags = [ "--no-default-folder" ];
    settings = {
      devices = {
        "Galileo" = { id = "ID-FOR-GALILEO"; };
        "Ekman" = { id = "ID-FOR-EKMAN"; };
      };
      folders = {
        "nixos" = {
          path = "/home/jefaturico/nixos";
          devices = [ "Ekman" ]; 
        };
      };
    };
  };
  
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    curl
    htop
    alacritty
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false; # For security
    settings.KbdInteractiveAuthentication = false;
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";

}

