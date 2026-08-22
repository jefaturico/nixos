{ pkgs, ... }:

# Playing, viewing, and producing audio/video, plus the handlers that route
# files and URLs to them.
let
  # The upstream package defaults to the X11 backend under XWayland and to a
  # DMA-BUF renderer that tears on this hardware.
  stremioWayland = pkgs.symlinkJoin {
    name = "stremio-wayland";
    paths = [ pkgs.stremio-linux-shell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      unlink "$out/bin/stremio"
      makeWrapper ${pkgs.stremio-linux-shell}/bin/stremio "$out/bin/stremio" \
        --set GDK_BACKEND wayland \
        --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
        --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
        --set __NV_DISABLE_EXPLICIT_SYNC 1

      # The desktop file uses D-Bus activation, which otherwise bypasses the
      # wrapped executable and launches the upstream package directly.
      unlink "$out/share/dbus-1/services/com.stremio.Stremio.service"
      substitute \
        ${pkgs.stremio-linux-shell}/share/dbus-1/services/com.stremio.Stremio.service \
        "$out/share/dbus-1/services/com.stremio.Stremio.service" \
        --replace-fail \
        ${pkgs.stremio-linux-shell}/bin/stremio \
        "$out/bin/stremio"
    '';
  };
in
{
  xdg.mimeApps = {
    associations.added."x-scheme-handler/stremio" = [ "com.stremio.Stremio.desktop" ];
    defaultApplications = {
      "image/png" = [ "imv.desktop" ];
      "image/jpeg" = [ "imv.desktop" ];
      "image/gif" = [ "imv.desktop" ];
      "x-scheme-handler/stremio" = [ "com.stremio.Stremio.desktop" ];
    };
  };

  home.packages = with pkgs; [
    ffmpeg
    imagemagick
    imv
    mpv
    # MPRIS control for the XF86Audio Play/Stop/Prev/Next keys bound in
    # dots/niri/config.kdl, and for movement-reminder's playback detection.
    playerctl
    pwvucontrol
    stremioWayland
  ];
}
