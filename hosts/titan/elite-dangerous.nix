{
  lib,
  pkgs,
  ...
}:

let
  jrwmPackage = pkgs.callPackage ../../common/packages/jrwm.nix { };

  hotasCurve = pkgs.writeShellApplication {
    name = "elite-hotas-curve";
    runtimeInputs = [ (pkgs.python3.withPackages (python: [ python.evdev ])) ];
    text = ''
      exec python3 ${./hotas-curve.py} "$@"
    '';
  };

  # OpenTrack's native UI launches its Wine bridge outside Steam's FHS
  # environment. Share /tmp so that bridge and Elite can reach the same
  # /tmp/.wine-$UID wineserver socket.
  eliteSteam = pkgs.steam.override { privateTmp = false; };

  opentrackWithLinuxJoystickShortcuts = pkgs.opentrack.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./opentrack-linux-joystick-shortcuts.patch ];
  });

  eliteGame = pkgs.writeShellApplication {
    name = "elite-dangerous";
    runtimeInputs = [ eliteSteam ];
    text = ''
      exec steam steam://rungameid/359320
    '';
  };

  eliteOpenTrack = pkgs.writeShellApplication {
    name = "elite-opentrack";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.procps
      pkgs.zenity
    ];
    text = ''
      runtime_client="$(
        { pgrep -fa 'SteamLinuxRuntime_.*pressure-vessel.*/(EDLaunch|EliteDangerous64)\.exe' || true; } \
          | sed -n \
            's|.* \(/[^ ]*/SteamLinuxRuntime_[^/]*/pressure-vessel\)/.*|\1/bin/steam-runtime-launch-client|p' \
          | head -n 1
      )"

      if [ ! -x "$runtime_client" ]; then
        zenity --error --title='OpenTrack' \
          --text='Start Elite Dangerous first, then launch OpenTrack again.'
        exit 1
      fi

      exec "$runtime_client" \
        --bus-name=com.steampowered.App359320 \
        --pass-env-matching=DISPLAY \
        --pass-env-matching=WAYLAND_DISPLAY \
        --pass-env-matching=XDG_RUNTIME_DIR \
        --pass-env-matching=DBUS_SESSION_BUS_ADDRESS \
        --env=QT_QPA_PLATFORM=wayland \
        -- ${opentrackWithLinuxJoystickShortcuts}/bin/opentrack
    '';
  };

  eliteEdCoPilot = pkgs.writeShellApplication {
    name = "elite-edcopilot";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.procps
      pkgs.zenity
    ];
    text = ''
      runtime_client="$(
        { pgrep -fa 'SteamLinuxRuntime_.*pressure-vessel.*/(EDLaunch|EliteDangerous64)\.exe' || true; } \
          | sed -n \
            's|.* \(/[^ ]*/SteamLinuxRuntime_[^/]*/pressure-vessel\)/.*|\1/bin/steam-runtime-launch-client|p' \
          | head -n 1
      )"

      if [ ! -x "$runtime_client" ]; then
        zenity --error --title='EDCoPilot' \
          --text='Start Elite Dangerous and enter the game first, then launch EDCoPilot again.'
        exit 1
      fi

      steamapps="$(readlink -f "$HOME/.local/share/Steam/steamapps")"
      compat_data="$steamapps/compatdata/359320"
      proton_config="$compat_data/config_info"
      # LaunchEDCoPilot.exe calls WScript.Shell.SendKeys to focus Elite before
      # starting the real process. Wine does not implement that call and the
      # launcher treats the resulting COM error as fatal. Start the actual
      # application directly; no launcher lifecycle behavior is wanted here.
      edcopilot_exe="$compat_data/pfx/drive_c/EDCoPilot/EDCoPilot.exe"
      proton_path=""

      if [ -f "$proton_config" ]; then
        proton_path="$(
          grep -m 1 -E '/(common|compatibilitytools.d)/[^/]*(Proton|proton)' "$proton_config" \
            | sed 's|/files/.*||' \
            || true
        )"
      fi

      if [ ! -x "$proton_path/files/bin/wine" ] || [ ! -f "$edcopilot_exe" ]; then
        zenity --error --title='EDCoPilot' \
          --text="EDCoPilot or Elite's Proton runtime is not installed in the current Elite prefix."
        exit 1
      fi

      export WINEPREFIX="$compat_data/pfx"
      export WINEFSYNC=1
      export WINELOADER="$proton_path/files/bin/wine"
      export WINESERVER="$proton_path/files/bin/wineserver"
      export PROTON_WINE="$WINELOADER"
      export STEAM_COMPAT_DATA_PATH="$compat_data"
      export SteamGameId=359320

      exec "$runtime_client" \
        --bus-name=com.steampowered.App359320 \
        --pass-env-matching='WINE*' \
        --pass-env-matching='STEAM*' \
        --pass-env-matching='PROTON*' \
        --env=SteamGameId=359320 \
        -- "$WINELOADER" "$edcopilot_exe"
    '';
  };

  eliteGameDesktop = pkgs.makeDesktopItem {
    name = "elite-dangerous";
    desktopName = "Elite Dangerous";
    comment = "Launch Elite Dangerous through Steam";
    exec = "${eliteGame}/bin/elite-dangerous";
    icon = "steam_icon_359320";
    categories = [ "Game" ];
  };

  eliteOpenTrackDesktop = pkgs.makeDesktopItem {
    name = "elite-opentrack";
    desktopName = "OpenTrack (Elite)";
    comment = "Launch after Elite so Wine head tracking shares its Proton runtime";
    exec = "${eliteOpenTrack}/bin/elite-opentrack";
    icon = "opentrack";
    categories = [ "Game" ];
  };

  eliteEdCoPilotDesktop = pkgs.makeDesktopItem {
    name = "elite-edcopilot";
    desktopName = "EDCoPilot (Elite)";
    comment = "Launch after entering an Elite game session";
    exec = "${eliteEdCoPilot}/bin/elite-edcopilot";
    categories = [ "Game" ];
  };

  eliteInit = pkgs.writeShellApplication {
    name = "elite-dangerous-init";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xwayland-satellite
    ];
    text = ''
      set -u

      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      ${jrwmPackage}/bin/jrwm &

      export DISPLAY=":12"
      xwayland-satellite "$DISPLAY" \
        >"$runtime_dir/xwayland-satellite-elite-dangerous.log" 2>&1 &

      x_socket="/tmp/.X11-unix/X12"
      for _ in $(seq 1 100); do
        if [ -S "$x_socket" ]; then
          break
        fi
        sleep 0.05
      done
      if [ ! -S "$x_socket" ]; then
        echo "elite-dangerous: timed out waiting for $x_socket" >&2
        exit 1
      fi

      wait
    '';
  };

  eliteRiverSession = pkgs.writeShellApplication {
    name = "elite-dangerous-river-session";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      set -euo pipefail

      # A previous Eureka login may have left the generic graphical target
      # active in the persistent user manager. Stop it before starting the
      # isolated game session; the next Eureka login will start it normally.
      systemctl --user stop graphical-session.target >/dev/null 2>&1 || true

      exec ${pkgs.river}/bin/river -c ${eliteInit}/bin/elite-dangerous-init
    '';
  };

  eliteSession = pkgs.writeShellApplication {
    name = "elite-dangerous-session";
    runtimeInputs = [ pkgs.dbus ];
    text = ''
      set -euo pipefail

      export XDG_CURRENT_DESKTOP="river:elite-dangerous:X-NIXOS-SYSTEMD-AWARE"
      export XDG_SESSION_DESKTOP="elite-dangerous"
      export XDG_SESSION_TYPE="wayland"
      export XCURSOR_THEME="Adwaita"
      export XCURSOR_SIZE="24"
      export XKB_DEFAULT_LAYOUT="us"
      export XKB_DEFAULT_VARIANT="altgr-intl"
      export XKB_DEFAULT_OPTIONS="altwin:menu_win"
      unset NIXOS_OZONE_WL

      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        exec dbus-run-session -- ${eliteRiverSession}/bin/elite-dangerous-river-session
      fi

      exec ${eliteRiverSession}/bin/elite-dangerous-river-session
    '';
  };

  eliteDesktopSession = pkgs.symlinkJoin {
    name = "elite-dangerous-wayland-session";
    paths = [
      eliteSession
      (pkgs.writeTextDir "share/wayland-sessions/elite-dangerous.desktop" ''
        [Desktop Entry]
        Name=Elite Dangerous
        Comment=Minimal River session for Elite Dangerous
        Exec=${eliteSession}/bin/elite-dangerous-session
        Type=Application
        DesktopNames=river;elite-dangerous;X-NIXOS-SYSTEMD-AWARE
      '')
    ];
    passthru.providedSessions = [ "elite-dangerous" ];
  };
in
{
  jefaturico.allowedUnfreePackages = lib.mkAfter [
    "steam"
    "steam-unwrapped"
  ];

  programs.steam = {
    enable = true;

    # OpenTrack's Wine output starts its bridge with Elite's Proton binary and
    # prefix, but it runs as a native Wayland application outside Steam's FHS
    # environment.  The Steam wrapper normally gives Steam a private /tmp;
    # that hides Wine's /tmp/.wine-$UID wineserver socket and causes Proton to
    # start a second server.  Sharing /tmp lets the OpenTrack bridge and Elite
    # join the same wineserver, which is required for NPClient/FreeTrack data.
    package = eliteSteam;
  };
  programs.gamemode.enable = true;

  systemd.services.elite-hotas-curve = {
    description = "Curved virtual T.Flight HOTAS X";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig = {
      ExecStart = "${hotasCurve}/bin/elite-hotas-curve";
      Restart = "always";
      RestartSec = 1;
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # The daemon is the only consumer of the physical event node. Applications
  # discover and bind only its virtual clone, preventing Elite from selecting
  # the uncurved axes. The virtual device deliberately preserves name and USB
  # IDs so existing Elite and OpenTrack bindings remain stable.
  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="044f", ATTRS{idProduct}=="b108", OWNER="root", GROUP="root", MODE="0600", TAG-="uaccess", ENV{ID_INPUT_JOYSTICK}="0"
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{phys}=="elite-hotas-curve/input0", GROUP="input", MODE="0660", TAG+="uaccess", ENV{ID_INPUT_JOYSTICK}="1"
  '';

  services.displayManager.sessionPackages = [ eliteDesktopSession ];

  environment.systemPackages = [
    eliteGame
    eliteGameDesktop
    eliteOpenTrack
    eliteOpenTrackDesktop
    eliteEdCoPilot
    eliteEdCoPilotDesktop
  ];

  # OpenTrack launches Proton's generic Linux Wine binary outside Steam's FHS
  # container. nix-ld handles its 64-bit launcher, while Wine's 32-bit side
  # needs the corresponding interpreter at the standard FHS path.
  programs.nix-ld.enable = true;
  environment.ldso32 = "${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2";

  home-manager.users.jefaturico = { lib, ... }: {
    # Preserve all GUI-managed tracking/filter settings while forcing only the
    # Wine bridge onto the exact Proton prefix Steam uses. Steam/steamapps is a
    # symlink on Titan, and OpenTrack's App-ID discovery does not canonicalize
    # it, producing a second wineserver which Elite cannot see.
    home.activation.configureEliteOpenTrack = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      profile="$HOME/.config/opentrack-2.3/default.ini"
      steamapps="$(${pkgs.coreutils}/bin/readlink -f "$HOME/.local/share/Steam/steamapps")"
      proton_config="$steamapps/compatdata/359320/config_info"
      proton_path=""

      if [ -f "$proton_config" ]; then
        proton_path="$(${pkgs.gnugrep}/bin/grep -m 1 -E '/(common|compatibilitytools.d)/[^/]*(Proton|proton)' "$proton_config" \
          | ${pkgs.gnused}/bin/sed 's|/files/.*||')"
      fi

      if [ -f "$profile" ] \
        && [ -d "$steamapps/compatdata/359320/pfx" ] \
        && [ -d "$proton_path/files" ]; then
        ${pkgs.crudini}/bin/crudini --set "$profile" proto-wine variant-proton true
        ${pkgs.crudini}/bin/crudini --set "$profile" proto-wine variant-wine false
        ${pkgs.crudini}/bin/crudini --set "$profile" proto-wine variant-proton-steamplay false
        ${pkgs.crudini}/bin/crudini --set "$profile" proto-wine variant-proton-external true
        ${pkgs.crudini}/bin/crudini --set "$profile" proto-wine proton-version \
          "$proton_path/files"
        ${pkgs.crudini}/bin/crudini --set "$profile" proto-wine protonprefix \
          "$steamapps/compatdata/359320/pfx"

        # The Osmo Action 4 exposes only MJPEG/H.264 at 720p or 1080p. The
        # NeuralNet defaults (uncompressed 320x240) make V4L2 block and then
        # report "Cannot open the source".
        ${pkgs.crudini}/bin/crudini --set "$profile" neuralnet-tracker use-mjpeg true
        ${pkgs.crudini}/bin/crudini --set "$profile" neuralnet-tracker force-resolution 4
        ${pkgs.crudini}/bin/crudini --set "$profile" neuralnet-tracker force-fps 1
      fi
    '';
  };
}
