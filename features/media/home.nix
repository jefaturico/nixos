{ pkgs, ... }:

# Playing video and viewing images, plus the handlers that route files to
# them.
{
  xdg.mimeApps.defaultApplications = {
    "image/png" = [ "imv.desktop" ];
    "image/jpeg" = [ "imv.desktop" ];
    "image/gif" = [ "imv.desktop" ];
    "image/webp" = [ "imv.desktop" ];
    "video/mp4" = [ "mpv.desktop" ];
    "video/x-matroska" = [ "mpv.desktop" ];
  };

  home.packages = with pkgs; [
    imv
    mpv
  ];
}
