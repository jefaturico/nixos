{ ... }:

# Idle handling: lock before sleep, suspend after ten minutes.
{
  home-manager.users.jefaturico =
    { pkgs, ... }:
    {
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
    };
}
