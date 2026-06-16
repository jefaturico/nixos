{ pkgs, ... }:

let
  mkScript = name: pkgs.writeScriptBin name (import (./scripts + "/${name}.nix") { inherit pkgs; });
  batteryCheck = mkScript "battery-check";
  wdocFind = mkScript "wdoc-find";
in
{
  home.packages = [
    (mkScript "browser-palette")
    (mkScript "wlsetbg")
    (mkScript "wlsettheme")
    (mkScript "wldaynight")
    wdocFind
    (mkScript "niri-window-switch")
    (mkScript "rebuild-push")
    (mkScript "systeminfo")
    (mkScript "usb-open")
    (mkScript "wlbrightness")
    (mkScript "wlvolume")
    (mkScript "wlscreenshot")
    batteryCheck
  ];

  systemd.user.services.battery-check = {
    Unit.Description = "Battery status monitor";
    Service = {
      Type = "simple";
      ExecStart = "${batteryCheck}/bin/battery-check";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.wdoc-find-index = {
    Unit.Description = "Document index cache for wdoc-find";
    Service = {
      Type = "simple";
      ExecStart = "${wdocFind}/bin/wdoc-find --watch";
      Restart = "always";
      RestartSec = 5;
      Nice = 10;
      IOSchedulingClass = "idle";
      CPUWeight = 10;
      IOWeight = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
