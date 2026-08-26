{
  inputs,
  pkgs,
  ...
}:

# Playing video and viewing images, plus the handlers that route files to
# them.
let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  xdg.mimeApps.defaultApplications = {
    "image/png" = [ "imv.desktop" ];
    "image/jpeg" = [ "imv.desktop" ];
    "image/gif" = [ "imv.desktop" ];
    "image/webp" = [ "imv.desktop" ];
    "video/mp4" = [ "mpv.desktop" ];
    "video/x-matroska" = [ "mpv.desktop" ];
  };

  # mpv streams URLs through yt-dlp. YouTube breaks extraction faster than the
  # stable release refreshes, so track unstable to keep playback working.
  home.packages = [
    pkgs.imv
    pkgs.mpv
    unstable.yt-dlp
  ];
}
