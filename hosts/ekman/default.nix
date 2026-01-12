{ ... }: {
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "ekman";

  # Laptop specific battery management
  services.tlp.enable = true; 
  
  # Ensure integrated Intel graphics are used
  hardware.graphics.enable = true;
}
