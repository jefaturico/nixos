{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    ../../modules/nix.nix
    ../../modules/boot.nix
    ../../modules/secure-boot.nix
    ../../modules/console.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/laptop.nix
    ../../modules/login.nix
    ../../modules/gaming.nix
    ../../modules/flatpak.nix
    ../../modules/backburner.nix
  ];

  networking.hostName = "coriolis";

  # Both off for the install. Turn them on in this order, following the
  # README: secureBoot first, tpmUnlock once Secure Boot is enforced.
  coriolis.secureBoot = false;
  coriolis.tpmUnlock = false;

  # Never change this after the install, it is not the "current version".
  system.stateVersion = "26.05";
}
