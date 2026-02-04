{ pkgs, config, ... }:
{
  services = {

    mako = {
      enable = true;
      settings = {
        font = "JetBrainsMono Nerd Font Mono 12";
        background-color = "#ffffffff";
        text-color = "#000000ff";
        border-color = "#000000ff";
        border-size = 1;
        padding = "10";
        margin = "10";
        default-timeout = 2000;
        format = "<span foreground=\"#005f5f\"><b>%s</b></span>\\n%b";
      };
      extraConfig = ''
        [urgency=high]
        default-timeout=0
        ignore-timeout=1
        text-color=#a60000
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

    emacs = {
      enable = true;
      package = config.programs.emacs.finalPackage;
      client.enable = true;
      defaultEditor = true;
    };
  };

  systemd.user.services.mako = {
    Service = {
      Restart = "always";
      ExecStart = "${pkgs.mako}/bin/mako";
      ExecStartPre = "-${pkgs.procps}/bin/pkill -x mako";
    };
  };
}
