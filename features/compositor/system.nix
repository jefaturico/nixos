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
    text = ''
      set -euo pipefail

      rows_output=$(niri msg --json windows | jq -r '
        [.[]
          | .title = (if .title == null or .title == "" then "(untitled)" else .title end)
          | .app_id = (if .app_id == null or .app_id == "" then "(unknown)" else .app_id end)
          | [.id, "\(.app_id) — \"\(.title)\""]
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
        | fuzzel --dmenu --index --prompt="Window: " --lines=20 --minimal-lines); then
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
    text = ''
      set -euo pipefail

      # The theme entry names the theme it switches *to*, so the label has to
      # be computed rather than listed, and matched back the same way.
      if [ "$(desktop-theme)" = dark ]; then
        theme_entry='Switch to light theme'
      else
        theme_entry='Switch to dark theme'
      fi

      choice=$(printf '%s\n' Lock Network "$theme_entry" Suspend Hibernate \
        'Exit session' Reboot 'Power off' \
        | fuzzel --dmenu --prompt='Power: ' --lines=8 --minimal-lines) || exit 0
      case "$choice" in
        Lock) exec waylock -fork-on-lock ;;
        Network) exec desktop-network ;;
        "$theme_entry") exec desktop-theme toggle ;;
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
    text = ''
      set -euo pipefail
      exec kitty \
        --class=com.mitchellh.kitty.NetworkConnections \
        --title="Network Connections" \
        env \
          NEWT_COLORS="root=white,default:border=yellow,default:window=white,default:shadow=default,default:title=yellow,default:button=white,gray:actbutton=yellow,gray:compactbutton=white,default:checkbox=white,default:actcheckbox=yellow,gray:entry=white,gray:actentry=yellow,gray:label=white,default:listbox=white,default:actlistbox=yellow,gray:sellistbox=white,gray:actsellistbox=yellow,gray:textbox=white,default:acttextbox=yellow,gray:helpline=gray,default:roottext=gray,default" \
          NMT_NEWT_COLORS="plainLabel=white,default:badLabel=red,default:disabledButton=gray,default:textboxWithBackground=white,gray" \
          nmtui
    '';
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

  # playerctl acts on whichever player is currently active, so the notification
  # reports what actually happened rather than echoing the key that was hit.
  desktopMedia = pkgs.writeShellApplication {
    name = "desktop-media";
    runtimeInputs = with pkgs; [
      libnotify
      playerctl
    ];
    text = ''
      set -euo pipefail
      case "''${1:-}" in
        play-pause | next | previous | stop) playerctl "$1" ;;
        *) echo 'usage: desktop-media {play-pause|next|previous|stop}' >&2; exit 2 ;;
      esac

      # Give the player a moment to settle before asking what it is doing.
      sleep 0.2
      status=$(playerctl status 2>/dev/null || echo Stopped)
      case "$status" in
        Playing) summary=$(playerctl metadata --format 'Playing {{artist}} — {{title}}' 2>/dev/null || echo Playing) ;;
        Paused) summary="Paused" ;;
        *) summary="Stopped" ;;
      esac
      notify-send \
        --app-name=media \
        --hint=string:x-canonical-private-synchronous:media \
        --expire-time=2000 \
        "$summary"
    '';
  };

  # There is no status bar, so this notification is the only clock and
  # battery readout available without opening a terminal.
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
