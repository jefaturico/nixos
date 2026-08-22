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
