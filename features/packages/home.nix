{ pkgs, ... }:

# Applications with nothing to configure. Anything that grows a settings
# block, a wrapper, a service, or a MIME association belongs in its own
# feature instead.
{
  home.packages = with pkgs; [
    # Command line
    bat
    fd
    gcc
    python3
    ripgrep
    unzip

    # Graphical
    calibre
    gimp
    obs-studio
    pdfarranger
    qbittorrent
    qgis
    stremio-linux-shell
  ];
}
