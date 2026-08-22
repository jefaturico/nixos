{ lib, pkgs, ... }:

let
  niriWindowMenu = pkgs.writeShellApplication {
    name = "niri-window-menu";
    runtimeInputs = [
      pkgs.jq
      pkgs.niri
    ];
    text = ''
      set -euo pipefail

      rows_output=$(niri msg --json windows | jq -r '
        [.[]
          | .title = (if .title == null or .title == "" then "(untitled)" else .title end)
          | .app_id = (if .app_id == null or .app_id == "" then "(unknown)" else .app_id end)
          | .label = (
              if .app_id == "librewolf" or .app_id == "firefox" then
                "browser — \"\(.title | sub(" — LibreWolf$"; "") | sub(" — Mozilla Firefox$"; ""))\""
              elif .app_id == "footclient" or .app_id == "foot" then
                "terminal — \"\(.title)\""
              else
                "\(.app_id) — \"\(.title)\""
              end
            )
          | [.id, .label]
          | @tsv]
        | .[]
      ')

      [ -n "$rows_output" ] || exit 0
      mapfile -t rows <<<"$rows_output"
      ids=()
      labels=()
      for row in "''${rows[@]}"; do
        ids+=("''${row%%$'\t'*}")
        labels+=("''${row#*$'\t'}")
      done

      if ! selected_index=$(printf '%s\n' "''${labels[@]}" \
        | "$HOME/.local/bin/fuzzel" --dmenu --index --prompt="Window: " \
          --lines=20 --minimal-lines); then
        exit 0
      fi
      if [[ ! "$selected_index" =~ ^[0-9]+$ ]] \
        || [ "$selected_index" -ge "''${#ids[@]}" ]; then
        echo "niri-window-menu: fuzzel returned an invalid index: $selected_index" >&2
        exit 1
      fi

      niri msg action focus-window --id "''${ids[$selected_index]}"
    '';
  };

  desktopLock = pkgs.writeShellApplication {
    name = "desktop-lock";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hyprlock
      pkgs.procps
    ];
    text = ''
      set -euo pipefail
      if pgrep -x hyprlock >/dev/null; then
        exit 0
      fi
      hyprlock --immediate-render &
      # Give hyprlock a short window to initialize and map its surface
      # before letting sleep inhibitors release.
      sleep 0.2
    '';
  };

  desktopPowerMenu = pkgs.writeShellApplication {
    name = "desktop-power-menu";
    runtimeInputs = [
      pkgs.niri
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail
      choice=$(printf '%s\n' Lock Suspend Hibernate 'Exit session' Reboot 'Power off' \
        | "$HOME/.local/bin/fuzzel" --dmenu --prompt='Power: ' \
          --lines=6 --minimal-lines) || exit 0
      case "$choice" in
        Lock) exec ${desktopLock}/bin/desktop-lock ;;
        Suspend) exec systemctl suspend ;;
        Hibernate) exec systemctl hibernate ;;
        'Exit session') exec niri msg action quit --skip-confirmation ;;
        Reboot) exec systemctl reboot ;;
        'Power off') exec systemctl poweroff ;;
      esac
    '';
  };

  desktopNetwork = pkgs.writeShellApplication {
    name = "desktop-network";
    runtimeInputs = with pkgs; [
      coreutils
      networkmanager
    ];
    text = ''
      set -euo pipefail
      exec "$HOME/.local/bin/footclient" \
        -E \
        --app-id=desktop-network \
        --title="Network Connections" \
        env \
          NEWT_COLORS="root=lightgray,default:border=blue,default:window=lightgray,default:shadow=gray,default:title=blue,default:button=lightgray,default:actbutton=black,blue:compactbutton=lightgray,default:checkbox=lightgray,default:actcheckbox=black,blue:entry=lightgray,gray:actentry=black,cyan:label=lightgray,default:listbox=lightgray,default:actlistbox=blue,default:actsellistbox=black,blue:sellistbox=lightgray,gray:textbox=lightgray,default:acttextbox=lightgray,default:helpline=gray,default:roottext=gray,default" \
          NMT_NEWT_COLORS="plainLabel=lightgray,default:badLabel=red,default:disabledButton=gray,default:textboxWithBackground=lightgray,gray" \
          nmtui
    '';
  };

  desktopVolume = pkgs.writeShellApplication {
    name = "desktop-volume";
    runtimeInputs = with pkgs; [
      gawk
      gnugrep
      libnotify
      wireplumber
    ];
    text = ''
      set -euo pipefail
      action="''${1:-}"
      target="@DEFAULT_AUDIO_SINK@"
      notification_id="volume"
      label="Volume"
      case "$action" in
        up) wpctl set-mute "$target" 0; wpctl set-volume --limit 1.0 "$target" 10%+ ;;
        down) wpctl set-mute "$target" 0; wpctl set-volume "$target" 10%- ;;
        mute) wpctl set-mute "$target" toggle ;;
        mic-mute)
          target="@DEFAULT_AUDIO_SOURCE@"
          notification_id="microphone"
          label="Microphone"
          wpctl set-mute "$target" toggle
          ;;
        *) echo 'usage: desktop-volume {up|down|mute|mic-mute}' >&2; exit 2 ;;
      esac
      state=$(wpctl get-volume "$target")
      percent=$(awk '{ printf "%d", $2 * 100 }' <<<"$state")
      notification_args=(
        --app-name=volume
        --hint="string:x-canonical-private-synchronous:$notification_id"
        --expire-time=400
      )
      if grep -q '\[MUTED\]' <<<"$state"; then
        summary="$label muted"
      else
        summary="$label $percent%"
        notification_args+=(--hint="int:value:$percent")
      fi
      notify-send "''${notification_args[@]}" "$summary"
    '';
  };

  desktopBrightness = pkgs.writeShellApplication {
    name = "desktop-brightness";
    runtimeInputs = with pkgs; [
      brightnessctl
      gawk
      libnotify
    ];
    text = ''
      set -euo pipefail
      case "''${1:-}" in
        up) brightnessctl --class=backlight set 10%+ >/dev/null ;;
        down) brightnessctl --class=backlight set 10%- >/dev/null ;;
        *) echo 'usage: desktop-brightness {up|down}' >&2; exit 2 ;;
      esac
      percent=$(brightnessctl --machine-readable --class=backlight info \
        | awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }')
      notify-send \
        --app-name=brightness \
        --hint=string:x-canonical-private-synchronous:brightness \
        --hint="int:value:$percent" \
        --expire-time=400 \
        "Brightness $percent%"
    '';
  };

  systemInfo = pkgs.writeShellApplication {
    name = "systeminfo";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = ''
      set -euo pipefail
      message="It's $(date '+%I:%M %P')."
      for power_supply in /sys/class/power_supply/*; do
        [ -r "$power_supply/type" ] || continue
        [ "$(<"$power_supply/type")" = "Battery" ] || continue
        [ -r "$power_supply/capacity" ] || continue
        capacity=$(<"$power_supply/capacity")
        message="$message Battery is at $capacity%."
        break
      done
      notify-send \
        --app-name=systeminfo \
        --hint=string:x-canonical-private-synchronous:systeminfo \
        --expire-time=5000 \
        "$message"
    '';
  };

in

{
  programs.niri = {
    enable = true;
    # Keep visible file selection consistent with the other GTK portal dialogs
    # without pulling Nautilus into the session closure.
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
    desktopLock
    desktopNetwork
    desktopPowerMenu
    desktopVolume
    niriWindowMenu
    pkgs.xwayland-satellite
    systemInfo
  ];

  systemd.user.services = {
    niri-idle = {
      description = "Idle handling for niri";
      unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
      after = [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.swayidle}/bin/swayidle -w -C /dev/null timeout 600 '${pkgs.systemd}/bin/systemctl suspend' before-sleep '${desktopLock}/bin/desktop-lock' lock '${desktopLock}/bin/desktop-lock'";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

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

    fnott = {
      description = "Fnott notification daemon";
      unitConfig = {
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
        # Theme changes intentionally restart Fnott so it reads the newly
        # generated configuration. Keep those restarts below a narrow,
        # service-local burst limit instead of leaving it start-limited.
        StartLimitIntervalSec = 30;
        StartLimitBurst = 20;
      };
      after = [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "%h/.local/bin/fnott-themed";
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
