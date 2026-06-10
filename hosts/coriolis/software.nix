{ lib, ... }: {
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "coriolis";

  # Override common UEFI bootloader — X201i is legacy BIOS
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/ata-CT480BX500SSD1_2420E8AF0DF4";
  };

  # Laptop power management
  services.tlp.enable = true;
  services.thermald.enable = true;

  # Intel integrated graphics
  hardware.graphics.enable = true;
}
