{ pkgs, ... }:

# Applications that are installed but not configured from Nix. Anything that
# grows a settings block, a wrapper, a service, or a MIME association belongs
# in its own module in this directory instead.
{
  home.packages = with pkgs; [
    # Command line
    bat
    fd
    gcc
    python3
    unzip

    # Graphics and layout
    gimp
    pdfarranger

    # Media production
    obs-studio

    # Libraries and reading
    calibre

    # Networking and transfer
    qbittorrent
    uget
    waypipe

    # Desktop odds and ends
    ripdrag

    # Domain-specific
    hugo
    qgis
    subsurface
  ];
}
