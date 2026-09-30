# Everything that was installed explicitly on Arch and has no module of its
# own somewhere else in this repo. The comment after a package is its Arch
# name when that differs.
#
# To cut something, delete its line.
{ pkgs, ... }:
{
  home.packages =
    (with pkgs; [
      # ---- Desktop session (called from the niri config and ~/.scripts) ----
      swaybg
      swayidle
      swaylock
      xwayland-satellite
      wl-clipboard
      libnotify # notify-send
      brightnessctl
      playerctl
      pavucontrol
      alsa-utils
      bluetui
      dash # the scripts in ~/.scripts run under it

      # ---- Apps ------------------------------------------------------------
      thunderbird
      libreoffice-fresh
      gimp
      anki
      calibre
      kdePackages.okular # okular
      tor-browser # torbrowser-launcher
      uget
      stremio-linux-shell # was the flatpak com.stremio.Stremio

      # ---- Terminal --------------------------------------------------------
      bat
      fd
      fzf
      ripgrep
      htop
      nnn
      tealdeer
      calcurse
      taskwarrior3 # came in as a dependency of taskwarrior-tui
      taskwarrior-tui

      # ---- Development (base-devel) ------------------------------------------
      gcc # also compiles nvim-treesitter's parsers
      gnumake
      tree-sitter # tree-sitter-cli
      marksman
      libtexprintf # AUR, packaged in pkgs/libtexprintf.nix
    ])
    # ---- From unstable ---------------------------------------------------------
    ++ (with pkgs.unstable; [
      brave-origin # brave-origin-beta-bin. Not in stable, and no beta in nixpkgs.
      claude-code # moves fast, stable lags months behind
      sioyek # sioyek-dev. Development snapshot, unstable's is newer.
      typst # 0.15 like on Arch. Stable has 0.14, which can fail on
      tinymist # documents written for 0.15.
    ]);
}
