{
  config,
  pkgs,
  ...
}:

let
  eurekaPackage = import ./packages/eureka.nix { inherit pkgs; };
  canoePackage = import ./packages/canoe.nix { inherit pkgs; };

  eurekaEmacs = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages (
    import ./emacs-packages.nix { extraPackages = [ eurekaPackage ]; }
  );

  eurekaSessionVariables = {
    XDG_CURRENT_DESKTOP = "river";
    XDG_SESSION_DESKTOP = "eureka";
    ELECTRON_OZONE_PLATFORM_HINT = "x11";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    XKB_DEFAULT_LAYOUT = "us";
    XKB_DEFAULT_VARIANT = "altgr-intl";
    XKB_DEFAULT_OPTIONS = "altwin:menu_win";
  };

  eurekaSessionExports = pkgs.lib.concatStringsSep "\n" (
    pkgs.lib.mapAttrsToList (name: value: ''export ${name}="${value}"'') eurekaSessionVariables
  );

  eurekaInit = pkgs.writeShellApplication {
    name = "eureka-init";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      xwayland-satellite
    ];
    text = ''
      set -euo pipefail

      startup_state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/eureka"
      mkdir -p "$startup_state_dir"
      EUREKA_STARTUP_LOG="$startup_state_dir/startup-$(date -u +%Y%m%dT%H%M%S)-$$.log"
      export EUREKA_STARTUP_LOG
      EUREKA_STARTUP_EPOCH_NS="$(date +%s%N)"
      export EUREKA_STARTUP_EPOCH_NS
      printf '# started_utc=%s\n# epoch_ns=%s\n# pid=%s\n' \
        "$(date -u --iso-8601=ns)" "$EUREKA_STARTUP_EPOCH_NS" "$$" \
        >"$EUREKA_STARTUP_LOG"

      startup_mark() {
        now_ns="$(date +%s%N)"
        elapsed_ms=$(( (now_ns - EUREKA_STARTUP_EPOCH_NS) / 1000000 ))
        printf '%8d ms  shell  %s\n' "$elapsed_ms" "$1" >>"$EUREKA_STARTUP_LOG"
      }

      startup_mark "eureka-init entry"

      ${eurekaSessionExports}
      unset NIXOS_OZONE_WL

      startup_mark "systemd import-environment start"
      systemctl --user import-environment \
        WAYLAND_DISPLAY \
        XDG_CURRENT_DESKTOP \
        XDG_SESSION_DESKTOP \
        XDG_SESSION_TYPE \
        ELECTRON_OZONE_PLATFORM_HINT \
        XCURSOR_THEME \
        XCURSOR_SIZE \
        XKB_DEFAULT_LAYOUT \
        XKB_DEFAULT_VARIANT \
        XKB_DEFAULT_OPTIONS >/dev/null 2>&1 || true
      startup_mark "systemd import-environment end"

      xwayland-satellite >/tmp/xwayland-satellite-eureka.log 2>&1 &
      startup_mark "xwayland-satellite spawned"

      startup_mark "exec emacs"
      exec env GTK_THEME=Adwaita:dark GTK_APPLICATION_PREFER_DARK_THEME=1 ${eurekaEmacs}/bin/emacs \
        --init-directory "$HOME/.config/emacs" \
        -l "$HOME/.config/emacs/lisp/jf-eureka.el"
    '';
  };

  eurekaSession = pkgs.writeShellApplication {
    name = "eureka-session";
    runtimeInputs = with pkgs; [
      dbus
      river
    ];
    text = ''
      set -euo pipefail

      ${eurekaSessionExports}
      export XDG_SESSION_TYPE="wayland"
      unset NIXOS_OZONE_WL

      # The checked-in river/ tree is reference material for Eureka protocol work.
      # This session intentionally runs nixpkgs' River and relies on its protocol support.
      river_cmd=("${pkgs.river}/bin/river" "-c" "${eurekaInit}/bin/eureka-init")

      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        exec dbus-run-session -- "''${river_cmd[@]}"
      fi

      exec "''${river_cmd[@]}"
    '';
  };

  eurekaDebugSession = pkgs.writeShellApplication {
    name = "eureka-debug-session";
    runtimeInputs = with pkgs; [ dbus river ];
    text = ''
      set -euo pipefail

      ${eurekaSessionExports}
      export XDG_SESSION_TYPE="wayland"
      export XDG_SESSION_DESKTOP="eureka-debug"
      export EUREKA_DEBUG="1"
      unset NIXOS_OZONE_WL

      river_cmd=("${pkgs.river}/bin/river" "-log-level" "debug" "-c" "${eurekaInit}/bin/eureka-init")
      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        exec dbus-run-session -- "''${river_cmd[@]}"
      fi
      exec "''${river_cmd[@]}"
    '';
  };

  eurekaDesktopSession = pkgs.symlinkJoin {
    name = "eureka-wayland-session";
    paths = [
      eurekaSession
      (pkgs.writeTextDir "share/wayland-sessions/eureka.desktop" ''
        [Desktop Entry]
        Name=Eureka
        Comment=Emacs-driven River session via Eureka
        Exec=${eurekaSession}/bin/eureka-session
        Type=Application
        DesktopNames=river;eureka
      '')
    ];
    passthru.providedSessions = [ "eureka" ];
  };

  eurekaDebugDesktopSession = pkgs.symlinkJoin {
    name = "eureka-debug-wayland-session";
    paths = [
      eurekaDebugSession
      (pkgs.writeTextDir "share/wayland-sessions/eureka-debug.desktop" ''
        [Desktop Entry]
        Name=Eureka (Debug Logs)
        Comment=Emacs-driven River session with verbose diagnostics
        Exec=${eurekaDebugSession}/bin/eureka-debug-session
        Type=Application
        DesktopNames=river;eureka
      '')
    ];
    passthru.providedSessions = [ "eureka-debug" ];
  };

  eurekaStartupReport = pkgs.writeShellApplication {
    name = "eureka-startup-report";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/eureka"
      latest=""
      for file in "$state_dir"/startup-*.log; do
        [ -e "$file" ] || continue
        if [ -z "$latest" ] || [ "$file" -nt "$latest" ]; then
          latest="$file"
        fi
      done

      if [ -z "$latest" ]; then
        echo "No Eureka startup logs found in $state_dir" >&2
        exit 1
      fi

      echo "$latest"
      cat "$latest"
    '';
  };

  eurekaRecover = pkgs.writeShellApplication {
    name = "eureka-recover";
    runtimeInputs = with pkgs; [ coreutils procps systemd ];
    text = ''
      set -euo pipefail

      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      wayland_display="''${WAYLAND_DISPLAY:-}"
      mapfile -t emacs_candidates < <(
        pgrep -u "$(id -u)" -f 'emacs.*jf-eureka\.el' || true
      )

      # From a TTY, prefer the display recorded by the actual Eureka Emacs
      # process. Picking the first wayland-* socket is unreliable when stale or
      # nested compositor sockets exist.
      if [ -z "$wayland_display" ]; then
        for pid in "''${emacs_candidates[@]}"; do
          wayland_display=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null \
            | sed -n 's/^WAYLAND_DISPLAY=//p' | head -n1)
          if [ -n "$wayland_display" ]; then
            break
          fi
        done
      fi
      if [ -z "$wayland_display" ]; then
        for socket in "$runtime_dir"/wayland-*; do
          if [ -S "$socket" ]; then
            wayland_display="''${socket##*/}"
            break
          fi
        done
      fi

      if [ -z "$wayland_display" ]; then
        echo "eureka-recover: no Wayland socket found in $runtime_dir" >&2
        exit 1
      fi

      # End only the Emacs process attached to this River display. This drops
      # Eureka's WM protocol object while preserving River and all application
      # windows. Canoe can then claim the active WM role.
      eureka_pids=()
      for pid in "''${emacs_candidates[@]}"; do
        if tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null \
          | grep -Fxq "WAYLAND_DISPLAY=$wayland_display"; then
          eureka_pids+=("$pid")
          kill -TERM "$pid"
        fi
      done

      for _ in $(seq 1 50); do
        still_running=false
        for pid in "''${eureka_pids[@]}"; do
          if kill -0 "$pid" 2>/dev/null; then
            still_running=true
          fi
        done
        if [ "$still_running" = false ]; then
          break
        fi
        sleep 0.1
      done

      systemctl --user stop eureka-fallback-wm.service 2>/dev/null || true
      systemd-run --user \
        --unit=eureka-fallback-wm \
        --collect \
        --service-type=exec \
        --setenv="XDG_RUNTIME_DIR=$runtime_dir" \
        --setenv="WAYLAND_DISPLAY=$wayland_display" \
        --setenv="PATH=${pkgs.lib.makeBinPath [ pkgs.foot pkgs.fuzzel ]}:$PATH" \
        ${canoePackage}/bin/canoe

      echo "Canoe recovery WM started on $wayland_display"
      echo "Super+Space: launcher; Super+Shift+Return: terminal; Super+w: close"
    '';
  };
in
{
  services.displayManager = {
    defaultSession = "eureka";
    sessionPackages = [ eurekaDesktopSession eurekaDebugDesktopSession ];
  };

  environment.sessionVariables = eurekaSessionVariables;

  environment.systemPackages = with pkgs; [
    brightnessctl
    canoePackage
    eurekaEmacs
    eurekaStartupReport
    foot
    fuzzel
    eurekaRecover
    river
    eurekaPackage
    wl-clipboard
    xwayland-satellite
  ];

  xdg.portal = {
    wlr = {
      enable = true;
      settings.screencast = {
        chooser_type = "simple";
        chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Output: %o' -or";
        max_fps = 60;
      };
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      river = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
        "org.freedesktop.impl.portal.Inhibit" = [ "none" ];
      };
      eureka = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
        "org.freedesktop.impl.portal.Inhibit" = [ "none" ];
      };
    };
  };
}
