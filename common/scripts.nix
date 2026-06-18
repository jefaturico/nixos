{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  mkScript = name: pkgs.writeScriptBin name (import (./scripts + "/${name}.nix") { inherit pkgs; });
  batteryCheck = mkScript "battery-check";
in
{
  home.packages = [
    (mkScript "browser-palette")
    (mkScript "wlsetbg")
    (mkScript "wlsettheme")
    (mkScript "wldaynight")
    (mkScript "wdoc-find")
    (mkScript "niri-window-switch")
    (mkScript "rebuild-push")
    (mkScript "systeminfo")
    (mkScript "usb-open")
    (mkScript "wlbrightness")
    (mkScript "wlvolume")
  ]
  ++ lib.optionals (osConfig.networking.hostName == "ekman") [
    batteryCheck
  ];

  systemd.user.services.battery-check = lib.mkIf (osConfig.networking.hostName == "ekman") {
    Unit.Description = "Battery status monitor";
    Service = {
      Type = "simple";
      ExecStart = "${batteryCheck}/bin/battery-check";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
