{ inputs, pkgs, ... }: {

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  services.xserver.xkb = {
    layout = "es";
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "es";
  };

  programs.river-classic = {
    enable = true;
  };

  services = {
    displayManager.ly = {
      enable = true;
      settings = {
        animation = "matrix";
        restore = true;
        session_log = "null";
      };
    };

    dbus.enable = true;

    pipewire = {
      enable = true;
      pulse.enable = true;
    };

    syncthing = {
      enable = true;
      user = "jefaturico";
      dataDir = "/home/jefaturico";
      openDefaultPorts = true;
    };

    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };
  };

xdg.portal = {
  enable = true;
  extraPortals = [ 
    pkgs.xdg-desktop-portal-gtk 
    pkgs.xdg-desktop-portal-wlr
  ];
  config = {
    common.default = [ "gtk" ];
    river = {
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };
};

  users.users.jefaturico = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "render" ];
  };

  environment.systemPackages = with pkgs; [
    vim wget git curl htop
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  zramSwap.enable = true;
  services.fstrim.enable = true;
  boot.kernel.sysctl = { "vm.swappiness" = 10;};

  system.stateVersion = "25.11";
}
