{ pkgs, ... }:

# Battery warnings and the last-resort hibernation. Lid and power-key
# behaviour belong to logind and are set in the host module.
let
  batteryWarning = pkgs.writeShellApplication {
    name = "battery-warning";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      systemd
    ];
    text = builtins.readFile ../../scripts/battery-warning.sh;
  };
in
{
  systemd.user.services.battery-warning = {
    Unit.Description = "Warn when the battery runs low";
    Service = {
      Type = "oneshot";
      ExecStart = "${batteryWarning}/bin/battery-warning";
    };
  };

  systemd.user.timers.battery-warning = {
    Unit.Description = "Warn when the battery runs low";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "2m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
