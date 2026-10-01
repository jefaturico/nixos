# Everything that was installed explicitly on Arch and has no module of its
# own somewhere else in this repo. The comment after a package is its Arch
# name when that differs.
#
# To cut something, delete its line.
{ pkgs, ... }:
{
  home.packages =
    (with pkgs; [
      # ---- Desktop session (called from home/hyprland.nix and ~/.scripts) ----
      swaybg
      wl-clipboard
      libnotify # notify-send
      brightnessctl
      playerctl
      pavucontrol
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
      mpv # plays a flashcard's source clip (dotfiles/emacs/init.el)

      # ---- Terminal --------------------------------------------------------
      fd
      ripgrep
      htop
      tealdeer
    ])
    # ---- From unstable ---------------------------------------------------------
    ++ (with pkgs.unstable; [
      brave-origin # brave-origin-beta-bin. Not in stable, and no beta in nixpkgs.
      claude-code # moves fast, stable lags months behind
      sioyek # sioyek-dev. Development snapshot, unstable's is newer.
      typst # 0.15 like on Arch. Stable has 0.14, which can fail on
      tinymist # documents written for 0.15.
      yt-dlp # mpv's way into YouTube. Old versions stop working.
    ]);
}
