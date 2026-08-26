{ ... }:

# Bluetooth radio, on at boot.
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
