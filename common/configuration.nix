{ inputs, pkgs, ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "es";
  };

  programs.niri.enable = true;

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

  nixpkgs.config.allowUnfree = true;

  users.users.jefaturico = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "render" ];
  };

  services.syncthing = {
    enable = true;
    user = "jefaturico";
    dataDir = "/home/jefaturico";
    settings = {
      devices = {
        "Galileo" = { id = "ID-FOR-GALILEO"; };
        "Ekman" = { id = "ID-FOR-EKMAN"; };
      };
      folders."nixos" = {
        path = "/home/jefaturico/nixos";
        devices = [ "Galileo" "Ekman" ]; 
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim wget git curl htop alacritty
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11";
}
