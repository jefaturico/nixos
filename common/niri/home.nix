{
  config,
  lib,
  osConfig,
  ...
}:

{
  config = lib.mkIf (osConfig.networking.hostName == "tethys") {
    xdg.configFile."niri/config.kdl".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/niri/config.kdl";
  };
}
