{ config, pkgs, ... }:

# The session's own user-level pieces: the live-reloaded niri configuration,
# the launcher, the notification daemon, and idle handling.
{
  # Checked in beside this module and linked out of the Nix store, so edits
  # apply through niri's live reload without a rebuild.
  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/features/compositor/config.kdl";

  programs.fuzzel = {
    enable = true;
    settings.main.font = "JetBrainsMono Nerd Font:size=12";
  };

  # Started on demand through D-Bus when the first notification arrives.
  services.mako = {
    enable = true;
    settings = {
      font = "JetBrainsMono Nerd Font 12";
      # Not cosmetic: mako's own default is 0, which means notifications never
      # expire and the volume popups would stack up forever.
      default-timeout = 5000;
      "urgency=critical".default-timeout = 0;
    };
  };

  services.swayidle = {
    enable = true;
    # Hold the sleep inhibitor until the locker has actually mapped its
    # surface, so the screen is never briefly visible on resume.
    extraArgs = [ "-w" ];
    timeouts = [
      {
        timeout = 600;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
    events = {
      before-sleep = "${pkgs.waylock}/bin/waylock -fork-on-lock";
      lock = "${pkgs.waylock}/bin/waylock -fork-on-lock";
    };
  };
}
