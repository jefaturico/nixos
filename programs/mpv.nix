{ ... }:

# Video playback, plus the handlers that route files to it.
{
  home-manager.users.jefaturico =
    { inputs, pkgs, ... }:
    let
      unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      xdg.mimeApps.defaultApplications = {
        "video/mp4" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
      };

      # mpv streams URLs through yt-dlp. YouTube breaks extraction faster than
      # the stable release refreshes, so track unstable to keep playback
      # working.
      home.packages = [
        pkgs.mpv
        unstable.yt-dlp
      ];
    };
}
