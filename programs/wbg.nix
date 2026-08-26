{ ... }:

# The wallpaper.
{
  home-manager.users.jefaturico =
    { pkgs, ... }:
    let
      desktopWallpaper = pkgs.writeShellApplication {
        name = "desktop-wallpaper";
        runtimeInputs = [ pkgs.wbg ];
        text = builtins.readFile ../scripts/desktop-wallpaper.sh;
      };
    in
    {
      # wbg takes a single image path, so the "only file in the directory"
      # rule is resolved at start time rather than baked into the service. The
      # service is part of the graphical session: it starts with it and dies
      # with it.
      systemd.user.services.wbg = {
        Unit = {
          Description = "Wallpaper";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${desktopWallpaper}/bin/desktop-wallpaper";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
