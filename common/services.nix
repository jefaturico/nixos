{
  pkgs,
  ...
}:
{
  services = {

    mako = {
      enable = true;
      settings = {
        font = "JetBrainsMono Nerd Font Mono 12";
        background-color = "#000000ff";
        text-color = "#ffffffff";
        border-color = "#ffffffff";
        border-size = 1;
        padding = "10";
        margin = "10";
        default-timeout = 2000;
        progress-color = "over #ffffffff";
        format = "<b>%s</b>\\n%b";
      };
      extraConfig = ''
        include=~/.cache/wallust/colors-mako

        [urgency=high]
        default-timeout=0
        ignore-timeout=1
        text-color=#ff0000
      '';
    };

    gammastep = {
      enable = true;
      provider = "manual";
      latitude = 40.4;
      longitude = -3.7;
      temperature = {
        day = 6500;
        night = 3500;
      };
      settings = {
        general = {
          adjustment-method = "wayland";
          fade = 1;
        };
      };
    };

    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };
  };
  systemd.user.services.foot-server = {
    Unit = {
      Description = "Foot terminal server";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.foot}/bin/foot --server";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.mako = {
    Service = {
      Restart = "always";
      ExecStartPre = "${pkgs.writeShellScript "mako-pre" ''
        mkdir -p "$HOME/.cache/wallust"
        touch "$HOME/.cache/wallust/colors-mako"
        touch "$HOME/.cache/wallust/colors-foot.ini"
        touch "$HOME/.cache/wallust/colors-fuzzel.ini"
      ''}";
    };
  };
}
