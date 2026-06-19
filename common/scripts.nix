{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  mkScript = name: pkgs.writeScriptBin name (import (./scripts + "/${name}.nix") { inherit pkgs; });
  batteryCheck = mkScript "battery-check";
  streamGalileoDesktop = mkScript "stream-galileo-desktop";
in
{
  home.packages = [
    (mkScript "browser-palette")
    (mkScript "niri-launch-or-focus")
    (mkScript "power-menu")
    (mkScript "wlsetbg")
    (mkScript "wlsettheme")
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
    streamGalileoDesktop
  ];

  xdg.dataFile."applications/stream-galileo-desktop.desktop" =
    lib.mkIf (osConfig.networking.hostName == "ekman")
      {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Stream Galileo's Desktop
          GenericName=Remote Desktop Stream
          Comment=Connect to Galileo's desktop through Moonlight
          Exec=stream-galileo-desktop
          Icon=moonlight
          Terminal=false
          Categories=Network;RemoteAccess;
          Keywords=galileo;moonlight;stream;desktop;remote;
        '';
      };

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
