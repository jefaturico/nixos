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
    settings = {
      main = {
        icons-enabled = "no";
        prompt = ''"λ "'';
        vertical-pad = 12;
        inner-pad = 8;
      };
      colors = {
        background = "181616ff";
        text = "c5c9c5ff";
        prompt = "8ba4b0ff";
        placeholder = "625e5aff";
        input = "c5c9c5ff";
        match = "8ea4a2ff";
        selection = "393836ff";
        selection-text = "c8c093ff";
        selection-match = "c4b28aff";
        counter = "a292a3ff";
        border = "181616ff";
      };
      border = {
        width = 0;
        radius = 15;
      };
    };
  };

  # Started on demand through D-Bus when the first notification arrives.
  services.mako = {
    enable = true;
    settings = {
      anchor = "top-center";
      layer = "overlay";
      width = 420;
      margin = 20;
      padding = 20;
      border-size = 0;
      border-radius = 15;
      background-color = "#181616f2";
      text-color = "#c5c9c5";
      progress-color = "over #8ba4b055";
      font = "JetBrainsMono Nerd Font 12";
      default-timeout = 5000;
      max-icon-size = 32;

      "urgency=low".text-color = "#625e5a";
      "urgency=critical" = {
        background-color = "#282727f2";
        text-color = "#c4746e";
        default-timeout = 0;
      };
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
