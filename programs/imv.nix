{ ... }:

# Image viewing, plus the handlers that route files to it.
{
  home-manager.users.jefaturico =
    { pkgs, ... }:
    {
      xdg.mimeApps.defaultApplications = {
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "image/webp" = [ "imv.desktop" ];
      };

      home.packages = [ pkgs.imv ];
    };
}
