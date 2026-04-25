{ ... }: {
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
    ./gaming.nix
  ];

  networking.hostName = "ekman";

  services.tlp.enable = true;
  services.thermald.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
