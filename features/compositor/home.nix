{ config, ... }:

# The compositor configuration is checked in beside this module and linked
# out of the Nix store, so edits apply through niri's live reload without a
# rebuild.
{
  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/features/compositor/config.kdl";
}
