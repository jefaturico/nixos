{ pkgs, ... }:

# Packages installed with nothing to configure. Anything that grows a
# settings block, a wrapper, a service, or a MIME association gets a file of
# its own under programs/ instead.
{
  # The handful of commands needed to repair the machine from a console,
  # installed system-wide so they exist before any user session does.
  environment.systemPackages = with pkgs; [
    curl
    git
    neovim
    wget
  ];

  home-manager.users.jefaturico.home.packages = with pkgs; [
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
    thunderbird
    pdfarranger
    qbittorrent
    qgis
    stremio-linux-shell
  ];
}
