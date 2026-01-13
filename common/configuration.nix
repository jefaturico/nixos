{ inputs, pkgs, ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "es";
  };

  programs.niri.enable = true;

  services = {
    displayManager.ly = {
      enable = true;
      settings = {
        animation = "matrix";
        restore = true;
        save = false;
        load = false;
      };
    };

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
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = [ "gnome" "gtk" ];
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
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11";
}
