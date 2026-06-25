{ config, lib, ... }:
let
  syncthingDevices = {
    galileo.id = "OQUT2EC-CERWR4S-PJCPFUU-BUMZJZL-EVH66K6-I2YKDX3-6A7RS3I-Z3LLFAW";
    coriolis.id = "YAYGCCW-R4IWEUH-7L7QRYG-TSHGH6K-XOCADP3-3OPOXU3-JAFFTC5-76TF6AO";
    ekman.id = "2STWXA4-JBLZ5FM-ZDFPSR2-VE63IJP-SI4LVAW-ECSVLL4-PRFI27E-6VELQQG";
    odin.id = "K5ROMZZ-E7WR4MM-EYYOLC5-UNOSCJ2-IIMYRGH-LOQOBZZ-DAV3EK6-CVDZ6AG";
  };

  hub = "odin";
  spokeHosts = [
    "galileo"
    "ekman"
    "coriolis"
  ];

  syncPeers = if config.networking.hostName == hub then spokeHosts else [ hub ];

  availableSyncPeers = builtins.filter (
    device: device != config.networking.hostName && builtins.hasAttr device syncthingDevices
  ) syncPeers;

  enabledSyncthingDevices = lib.genAttrs availableSyncPeers (device: syncthingDevices.${device});

  mkFolder = id: path: {
    inherit id path;
    devices = availableSyncPeers;
  };
in
{
  services.syncthing = {
    enable = true;
    user = "jefaturico";
    dataDir = "/home/jefaturico";
    openDefaultPorts = true;
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = enabledSyncthingDevices;
      folders = {
        projects = mkFolder "4pmxv-syxrh" "/home/jefaturico/projects";
        calcurse = mkFolder "5rdcv-wpnjr" "/home/jefaturico/.local/share/calcurse";
        wallpapers = mkFolder "bppru-7tfft" "/home/jefaturico/images/wallpapers";
        tasks = mkFolder "pngaf-ufcfi" "/home/jefaturico/.local/share/task";
        "zathura metadata" = mkFolder "rqfbg-5r2be" "/home/jefaturico/.local/share/zathura";
        documents = mkFolder "twsxa-tfzj6" "/home/jefaturico/documents";
        nixos = mkFolder "y2dqc-sjty3" "/home/jefaturico/nixos";
      };
      options = {
        urAccepted = -1;
      };
    };
  };
}
