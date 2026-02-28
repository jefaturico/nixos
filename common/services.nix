{ pkgs, config, ... }:
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
        format = "<b>%s</b>\\n%b";
        include = "~/.cache/wallust/colors-mako";
      };
      extraConfig = ''
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
  };
  systemd.user.services.mako = {
    Service = {
      Restart = "always";
      ExecStart = "${pkgs.mako}/bin/mako";
      ExecStartPre = "${pkgs.writeShellScript "mako-pre" ''
        mkdir -p "$HOME/.cache/wallust"
        touch "$HOME/.cache/wallust/colors-mako"
        touch "$HOME/.cache/wallust/colors-foot.ini"
        touch "$HOME/.cache/wallust/colors-fuzzel.ini"
        ${pkgs.procps}/bin/pkill -x mako || true
      ''}";
    };
  };
}
