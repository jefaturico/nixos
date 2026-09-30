{ pkgs, ... }:
{
  # Hyprland, its session entry for ly, its portal and polkit. The config is
  # home/hyprland.nix.
  programs.hyprland.enable = true;

  # File pickers. Hyprland's own portal only does screen sharing.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # The lock screen needs a PAM service to check the password.
  programs.hyprlock.enable = true;

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
  };
}
