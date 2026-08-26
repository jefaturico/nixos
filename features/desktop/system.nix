{ pkgs, ... }:

# Everything a graphical session needs regardless of which compositor runs:
# peripherals, portals, fonts, and the groups that reach the hardware. The
# compositor itself is the `compositor` feature.
{
  users.users.jefaturico.extraGroups = [
    "video"
    "render"
    "input"
  ];

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Removable media: udisks2 exposes the devices and udiskie (Home Manager)
  # mounts them.
  services.udisks2.enable = true;

  programs.dconf.enable = true;

  # Chromium and Electron still default to X11, which puts Brave, Stremio and
  # anything else Electron-based on XWayland. There they read GTK settings
  # over XSETTINGS — for which nothing is running — instead of subscribing to
  # the appearance portal, so they never notice a light/dark switch. Native
  # Wayland also gets them correct scaling and input.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # nixpkgs' graphical-desktop module enables speech-dispatcher by default,
  # which drags in espeak-ng and ~650 MB of mbrola voice data. No screen
  # reader or text-to-speech is used on this machine.
  services.speechd.enable = false;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    corefonts
  ];
}
