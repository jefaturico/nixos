# Written by hand from the running Arch install (lsmod, lspci), because
# nixos-generate-config cannot run there. During the install, regenerate it
# and replace this file, after disko has mounted everything on /mnt:
#
#   nixos-generate-config --no-filesystems --root /mnt --show-hardware-config
#
# --no-filesystems matters: disko.nix owns the partitions and mounts.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
