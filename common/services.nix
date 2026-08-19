{
  pkgs,
  ...
}:
let
  footServer = pkgs.writeShellApplication {
    name = "foot-server";
    runtimeInputs = [ pkgs.dconf ];
    text = ''
      color_scheme=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
      if [ "$color_scheme" = "'prefer-light'" ]; then
        initial_theme=light
      else
        initial_theme=dark
      fi
      exec ${pkgs.foot}/bin/foot --server --override="initial-color-theme=$initial_theme"
    '';
  };
in
{
  services = {

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
      ExecStart = "${footServer}/bin/foot-server";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

}
