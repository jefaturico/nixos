{ inputs, ... }:
{
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  networking.hostName = "tethys";

  eureka.outputScales."eDP-1" = 2;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  zramSwap = {
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl."vm.page-cluster" = 0;
}
