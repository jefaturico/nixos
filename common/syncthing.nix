{ config, lib, ... }:
let
  syncthingDevices = {
    titan.id = "OQUT2EC-CERWR4S-PJCPFUU-BUMZJZL-EVH66K6-I2YKDX3-6A7RS3I-Z3LLFAW";
    tethys.id = "2STWXA4-JBLZ5FM-ZDFPSR2-VE63IJP-SI4LVAW-ECSVLL4-PRFI27E-6VELQQG";
    prometheus.id = "4FRYUNK-DRTUVOV-OQ2RHP2-VY7GETS-XNCLXIS-M5AADSR-B6GNHWI-FBQXKAP";
    iapetus.id = "K5ROMZZ-E7WR4MM-EYYOLC5-UNOSCJ2-IIMYRGH-LOQOBZZ-DAV3EK6-CVDZ6AG";
    rhea.id = "HX2Y3DU-MX2MRNK-WLIJKQL-C4GQNVZ-LG5HRPA-YHRF2TH-23OQ4LA-PU3XBAM";
  };

  hub = "iapetus";
  spokeHosts = [
    "titan"
    "tethys"
    "prometheus"
  ];

  directPeers = {
    titan = [
      "tethys"
      "prometheus"
    ];
    tethys = [
      "titan"
      "prometheus"
    ];
    prometheus = [
      "titan"
      "tethys"
    ];
  };

  syncPeers =
    if config.networking.hostName == hub then
      spokeHosts
    else
      [ hub ] ++ (directPeers.${config.networking.hostName} or [ ]);

  phonePeers = [ "rhea" ];

  availableSyncPeers = builtins.filter (
    device: device != config.networking.hostName && builtins.hasAttr device syncthingDevices
  ) syncPeers;

  availablePhonePeers = builtins.filter (
    device: device != config.networking.hostName && builtins.hasAttr device syncthingDevices
  ) phonePeers;

  enabledSyncthingDevices = lib.genAttrs (availableSyncPeers ++ availablePhonePeers) (
    device: syncthingDevices.${device}
  );

  mkFolderWithDevices = devices: id: path: {
    inherit id path;
    inherit devices;
  };

  mkFolder = mkFolderWithDevices availableSyncPeers;

  mkFolderWithPhone = mkFolderWithDevices (availableSyncPeers ++ availablePhonePeers);

  mkDocumentsFolder =
    id: path:
    (mkFolder id path)
    // {
      ignorePatterns = [
        "notes/.stfolder"
        "notes/.stfolder/**"
        "org/.stfolder"
        "org/.stfolder/**"
      ];
    };

  mkNixosFolder =
    id: path:
    (mkFolder id path)
    // {
      ignorePatterns = [
        ".agents"
        ".agents/**"
        ".codex"
        ".codex/**"
        "*.sync-conflict-*"
        "result"
        "result-*"
      ];
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
        org = mkFolderWithPhone "org" "/home/jefaturico/documents/org";
        projects = mkFolder "4pmxv-syxrh" "/home/jefaturico/projects";
        wallpapers = mkFolder "bppru-7tfft" "/home/jefaturico/images/wallpapers";
        tasks = mkFolder "pngaf-ufcfi" "/home/jefaturico/.local/share/task";
        "zathura metadata" = mkFolder "rqfbg-5r2be" "/home/jefaturico/.local/share/zathura";
        documents = mkDocumentsFolder "twsxa-tfzj6" "/home/jefaturico/documents";
        nixos = mkNixosFolder "y2dqc-sjty3" "/home/jefaturico/nixos";
      };
      options = {
        urAccepted = -1;
      };
    };
  };
}
