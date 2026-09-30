{ pkgs, ... }:
{
  # niri itself, its session file for the display manager, the portals
  # (gnome + gtk) and polkit. The config file is dotfiles/niri/config.kdl.
  programs.niri.enable = true;

  # The niri module turns gnome-keyring on. Arch did not have it, and it
  # would take over SSH_AUTH_SOCK and hook into the login. Delete this line
  # if you want a keyring (some apps store passwords in it).
  services.gnome.gnome-keyring.enable = false;

  # GTK apps read their settings (dark theme) from dconf.
  programs.dconf.enable = true;

  # Audio: pipewire with the alsa and pulse shims (pipewire-alsa,
  # pipewire-pulse), wireplumber as session manager.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono # ttf-jetbrains-mono-nerd
      noto-fonts
    ];

    # Was ~/.config/fontconfig/fonts.conf. That file asked for
    # "JetBrains Mono Nerd Font", which is not the family name and only
    # matched by accident. This is the real one.
    fontconfig.defaultFonts = {
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono"
      ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
    };
  };
}
