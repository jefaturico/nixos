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

  # Secure Boot and TPM disk unlock. A fresh install uses the
  # `coriolis-install` variant in flake.nix, which forces both off; setup.sh
  # then brings the machine up to this.
  coriolis.secureBoot = true;
  coriolis.tpmUnlock = true;

  # Never change this after the install, it is not the "current version".
  system.stateVersion = "26.05";
}
