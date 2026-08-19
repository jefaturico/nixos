{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  displayCornerMask = pkgs.stdenv.mkDerivation {
    pname = "display-corner-mask";
    version = "1";
    src = ./display-corner-mask.c;
    dontUnpack = true;
    strictDeps = true;
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.wayland-scanner
    ];
    buildInputs = [ pkgs.wayland ];
    buildPhase = ''
      runHook preBuild
      wayland-scanner client-header \
        ${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-layer-shell-unstable-v1.xml \
        wlr-layer-shell-unstable-v1-client-protocol.h
      wayland-scanner private-code \
        ${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-layer-shell-unstable-v1.xml \
        wlr-layer-shell-unstable-v1-protocol.c
      wayland-scanner private-code \
        ${pkgs.wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
        xdg-shell-protocol.c
      $CC $NIX_CFLAGS_COMPILE -I. -std=c11 -Wall -Wextra -Werror \
        $(pkg-config --cflags wayland-client) \
        "$src" wlr-layer-shell-unstable-v1-protocol.c xdg-shell-protocol.c \
        $(pkg-config --libs wayland-client) \
        -o display-corner-mask
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 display-corner-mask "$out/bin/display-corner-mask"
      runHook postInstall
    '';
  };
in
{
  imports = [
    ./hardware.nix
    ../../common/configuration.nix
    ../../common/niri
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  networking.hostName = "tethys";
  networking.networkmanager.wifi.powersave = true;

  # Give NetworkManager and Tailscale one link-aware DNS manager.  With
  # openresolv, Tailscale can retain its local resolver after resume without
  # learning the Wi-Fi connection's new upstream servers.
  services.resolved.enable = true;

  # Let the kernel select its larger built-in console font for the HiDPI panel.
  console.font = lib.mkForce null;

  programs.steam.enable = true;

  environment.systemPackages = [ pkgs.lutris ];

  # The panel has a larger physical radius at its upper corners. Mask the two
  # lower corners so the visible display area has one consistent 15 px radius.
  systemd.user.services.display-corner-mask = {
    description = "Match the Tethys display's lower corners to its upper corners";
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    after = [ "niri.service" ];
    serviceConfig = {
      ExecStart = "${displayCornerMask}/bin/display-corner-mask eDP-1 15";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # Keep both kernel interfaces for the same physical keyboard backlight off.
  # Matching change events also neutralizes accidental brightness-key presses.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="chromeos::kbd_backlight", ATTR{brightness}="0"
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="framework_laptop::kbd_backlight", ATTR{brightness}="0"
  '';

  services.logind.settings.Login = {
    HandlePowerKey = "hibernate";
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  # Fn+F10 is exposed as a separate Framework wireless-radio input device.
  # Claim it explicitly because keyd's wildcard only matches full keyboards.
  services.keyd.keyboards.framework-radio = {
    ids = [ "32ac:0006" ];
    settings.main.rfkill = "noop";
  };

  zramSwap = {
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl."vm.page-cluster" = 0;
}
