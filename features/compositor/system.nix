{ lib, pkgs, ... }:

# Niri: the compositor session, the small helpers its keybindings spawn, and
# the two user services that belong to the graphical session but have no
# Home Manager module of their own.
let
  desktopTheme = pkgs.callPackage ../theme/desktop-theme.nix { };

  niriWindowMenu = pkgs.writeShellApplication {
    name = "niri-window-menu";
    runtimeInputs = with pkgs; [
      fuzzel
      jq
      niri
    ];
    text = builtins.readFile ../../scripts/niri-window-menu.sh;
  };

  desktopPowerMenu = pkgs.writeShellApplication {
    name = "desktop-power-menu";
    runtimeInputs = with pkgs; [
      desktopNetwork
      desktopTheme
      fuzzel
      niri
      systemd
      waylock
    ];
    text = builtins.readFile ../../scripts/desktop-power-menu.sh;
  };

  desktopNetwork = pkgs.writeShellApplication {
    name = "desktop-network";
    runtimeInputs = with pkgs; [
      coreutils
      kitty
      networkmanager
    ];
    # `--class` replaces foot's `--app-id`, namespaced the same way. kitty
    # takes the command to run as trailing positional arguments, so the two
    # settings have to precede it.
    #
    # newt's own palette is built for a blue-on-grey terminal and turns to
    # mud over Monokai, so nmtui gets an explicit one. It can only name the
    # sixteen ANSI slots, which the theme switch repaints from the same
    # palette the terminal uses -- so the scheme has to read in both filters.
    # Only three roles are used for that reason: `default` keeps the
    # terminal's own background behind ordinary text, `gray` (colour 8) is
    # the one slot that stays mid-tone in either filter and so carries every
    # selection, and `yellow` is the palette's accent, marking the focused
    # widget and the window furniture.
    text = builtins.readFile ../../scripts/desktop-network.sh;
  };

  # Each readout below carries its own `x-canonical-private-synchronous` tag,
  # named after what it reports. mako replaces a notification only when the
  # tag matches, so holding the volume key updates one popup instead of
  # stacking a dozen, while a brightness or system-info notification appears
  # alongside it rather than taking its place.
  desktopVolume = pkgs.writeShellApplication {
    name = "desktop-volume";
    runtimeInputs = with pkgs; [
      gawk
      gnugrep
      libnotify
      wireplumber
    ];
    text = builtins.readFile ../../scripts/desktop-volume.sh;
  };

  desktopBrightness = pkgs.writeShellApplication {
    name = "desktop-brightness";
    runtimeInputs = with pkgs; [
      brightnessctl
      gawk
      libnotify
    ];
    text = builtins.readFile ../../scripts/desktop-brightness.sh;
  };

  # playerctl acts on whichever player is currently active, so the notification
  # reports what actually happened rather than echoing the key that was hit.
  desktopMedia = pkgs.writeShellApplication {
    name = "desktop-media";
    runtimeInputs = with pkgs; [
      libnotify
      playerctl
    ];
    text = builtins.readFile ../../scripts/desktop-media.sh;
  };

  # There is no status bar, so this notification is the only clock and
  # battery readout available without opening a terminal.
  systemInfo = pkgs.writeShellApplication {
    name = "systeminfo";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = builtins.readFile ../../scripts/systeminfo.sh;
  };
in
{
  programs.niri = {
    enable = true;
    # Keep visible file selection consistent with the other GTK portal
    # dialogs without pulling Nautilus into the session closure.
    useNautilus = false;
  };

  # Passwords are managed elsewhere; do not start GNOME Keyring or advertise
  # its Secret portal. Other interfaces retain niri's upstream GNOME-first,
  # GTK-fallback portal routing.
  services.gnome.gnome-keyring.enable = false;
  xdg.portal.config.niri."org.freedesktop.impl.portal.Secret" = lib.mkForce "none";

  # Niri starts xwayland-satellite on demand when it is available in PATH.
  environment.systemPackages = [
    desktopBrightness
    desktopMedia
    desktopNetwork
    desktopPowerMenu
    desktopVolume
    niriWindowMenu
    pkgs.xwayland-satellite
    systemInfo
  ];

  systemd.user.services = {
    niri-media-idle-inhibit = {
      description = "Inhibit niri idling during sustained media playback";
      unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
      after = [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit --media-minimum-duration 10 --wayland";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    niri-polkit-agent = {
      description = "PolicyKit authentication agent for niri";
      unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
      after = [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
