{
  lib,
  pkgs,
  ...
}:

let
  matugenConfig = pkgs.writeText "matugen-config.toml" ''
    [config]
    version_check = false
    caching = true

    [templates.foot]
    input_path = "${./matugen/foot-overrides.bash}"
    output_path = "~/.cache/matugen/dynamic/foot-overrides.bash"

    [templates.terminal]
    input_path = "${./matugen/terminal-colors.bash}"
    output_path = "~/.cache/matugen/dynamic/terminal-colors.bash"

    [templates.fuzzel-dark]
    input_path = "${./matugen/fuzzel.ini}"
    output_path = "~/.cache/matugen/dynamic/fuzzel-dark.ini"

    [templates.fuzzel-light]
    input_path = "${./matugen/fuzzel-light.ini}"
    output_path = "~/.cache/matugen/dynamic/fuzzel-light.ini"

    [templates.mako]
    input_path = "${./matugen/mako.conf}"
    output_path = "~/.cache/matugen/dynamic/mako.conf"

  '';
  dynamicTheme = pkgs.writeShellApplication {
    name = "dynamic-theme";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      matugen
      mako
    ];
    text = ''
      set -euo pipefail

      action="''${1:-apply}"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/wbg"
      generated_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/matugen/dynamic"

      current_wallpaper() {
        if [ -r "$state_dir/current" ]; then
          readlink -f -- "$state_dir/current"
        fi
      }

      generate() {
        local wallpaper="''${1:-}"
        if [ -z "$wallpaper" ] || [ "$wallpaper" = current ]; then
          wallpaper=$(current_wallpaper)
        fi
        [ -n "$wallpaper" ] && [ -r "$wallpaper" ] || return 0

        mkdir -p "$generated_dir"
        matugen image "$wallpaper" \
          --config=${matugenConfig} \
          --type=scheme-fidelity \
          --source-color-index=0 \
          --quiet
      }

      is_dark() {
        [ "$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)" != "'prefer-light'" ]
      }

      apply_terminal_colors() {
        local colors_file="$generated_dir/terminal-colors.bash"
        local background="" foreground="" cursor=""
        local background_dark="" foreground_dark="" cursor_dark=""
        local background_light="" foreground_light="" cursor_light=""
        local -a terminal_colors=()
        local -a terminal_colors_dark=() terminal_colors_light=()
        [ -r "$colors_file" ] || return 0
        # shellcheck disable=SC1090
        source "$colors_file"

        if is_dark; then
          background="$background_dark"
          foreground="$foreground_dark"
          cursor="$cursor_dark"
          terminal_colors=("''${terminal_colors_dark[@]}")
        else
          background="$background_light"
          foreground="$foreground_light"
          cursor="$cursor_light"
          terminal_colors=("''${terminal_colors_light[@]}")
        fi

        local sequence tty index
        sequence=$'\033]10;#'"$foreground"$'\033\\'
        sequence+=$'\033]11;#'"$background"$'\033\\'
        sequence+=$'\033]12;#'"$cursor"$'\033\\'
        for index in {0..15}; do
          sequence+=$'\033]4;'"$index"';#'"''${terminal_colors[$index]}"$'\033\\'
        done

        # Restrict palette updates to this user's writable PTYs and never
        # touch virtual consoles.
        for tty in /dev/pts/[0-9]*; do
          if [ -c "$tty" ] && [ -O "$tty" ] && [ -w "$tty" ]; then
            printf '%s' "$sequence" >"$tty" 2>/dev/null || true
          fi
        done
      }

      apply() {
        apply_terminal_colors

        # Mako keeps the mode selected by system-theme while re-reading the
        # generated palette. Fuzzel reads its selected file at each invocation.
        makoctl reload >/dev/null 2>&1 || true
        if is_dark; then
          makoctl mode -s dark >/dev/null 2>&1 || true
        else
          makoctl mode -s light >/dev/null 2>&1 || true
        fi

      }

      case "$action" in
        generate)
          generate "''${2:-current}"
          ;;
        apply)
          apply
          ;;
        refresh)
          generate "''${2:-current}"
          apply
          ;;
        *)
          echo "usage: dynamic-theme [generate [wallpaper]|apply|refresh [wallpaper]]" >&2
          exit 2
          ;;
      esac
    '';
  };
  ttyTheme = pkgs.writeShellApplication {
    name = "tty-theme";
    runtimeInputs = [ pkgs.dconf ];
    text = ''
      mode="''${1:-}"
      scope="''${2:-current}"

      if [ -z "$mode" ]; then
        color_scheme=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
        if [ "$color_scheme" = "'prefer-light'" ]; then
          mode=light
        else
          mode=dark
        fi
      fi

      case "$mode" in
        light) sequence=$'\033[?5h' ;;
        dark) sequence=$'\033[?5l' ;;
        *)
          echo "usage: tty-theme [light|dark] [current|all]" >&2
          exit 2
          ;;
      esac

      case "$scope" in
        current)
          if [ "''${TERM:-}" = linux ] && [ -t 1 ]; then
            printf '%s' "$sequence"
          fi
          ;;
        all)
          # Logged-in VTs are owned by the user, so no elevated access is
          # needed.  A VT not yet logged into is initialized by the shell hook.
          for tty in /dev/tty{1..63}; do
            if [ -c "$tty" ] && [ -w "$tty" ]; then
              printf '%s' "$sequence" > "$tty" || true
            fi
          done
          ;;
        *)
          echo "usage: tty-theme [light|dark] [current|all]" >&2
          exit 2
          ;;
      esac
    '';
  };
  fuzzelFallback = pkgs.writeText "fuzzel-fallback.ini" ''
    [main]
    icons-enabled=no
    namespace=fuzzel
    prompt="λ "
    vertical-pad=12
    inner-pad=8

    [border]
    width=0
    radius=15
    selection-radius=0
  '';
  systemTheme = pkgs.writeShellApplication {
    name = "system-theme";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      libnotify
      mako
      systemd
    ];
    text = ''
      set -euo pipefail

      action="''${1:-toggle}"

      case "$action" in
        apply)
          current=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
          if [ "$current" = "'prefer-light'" ]; then
            mode=light
          else
            mode=dark
          fi
          notify=0
          ;;
        toggle)
          current=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
          if [ "$current" = "'prefer-light'" ]; then
            mode=dark
          else
            mode=light
          fi
          notify=1
          ;;
        light|dark)
          mode="$action"
          notify=1
          ;;
        *)
          echo "usage: system-theme [apply|toggle|light|dark]" >&2
          exit 2
          ;;
      esac

      if [ "$mode" = light ]; then
        color_scheme=prefer-light
        gtk_theme=Adwaita
        foot_signal=SIGUSR2
      else
        color_scheme=prefer-dark
        gtk_theme=Adwaita-dark
        foot_signal=SIGUSR1
      fi

      dconf write /org/gnome/desktop/interface/color-scheme "'$color_scheme'"
      dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'"

      # Keep existing virtual-console sessions aligned with the same setting.
      ${ttyTheme}/bin/tty-theme "$mode" all

      # Foot applies this to every current client and remembers it for future
      # clients connected to the same server.
      if systemctl --user --quiet is-active foot-server.service; then
        systemctl --user kill --kill-whom=main --signal="$foot_signal" foot-server.service
      fi

      # Regenerate both variants from the current wallpaper, then apply the
      # selected one to every live consumer.
      ${dynamicTheme}/bin/dynamic-theme refresh current

      # Mako modes restyle current and future notifications without restarting
      # the daemon.  At login, briefly wait for its D-Bus interface to appear.
      if [ "$action" = apply ]; then
        for _attempt in {1..20}; do
          if makoctl mode -s "$mode" >/dev/null 2>&1; then
            break
          fi
          sleep 0.05
        done
      else
        makoctl mode -s "$mode" >/dev/null 2>&1 || true
      fi

      if [ "$notify" -eq 1 ]; then
        title_mode="''${mode^}"
        notify-send \
          --app-name=system-theme \
          --hint=string:x-canonical-private-synchronous:system-theme \
          --expire-time=1200 \
          "$title_mode theme"
      fi
    '';
  };
  initialWbg = pkgs.writeText "wbg-initial" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    wallpaper_dir="$HOME/images/wallpapers"
    [ -d "$wallpaper_dir" ] || exit 0
    mapfile -d "" -t wallpapers < <(
      ${pkgs.findutils}/bin/find "$wallpaper_dir" -maxdepth 1 -type f -print0 \
        | ${pkgs.coreutils}/bin/shuf -z
    )
    [ "''${#wallpapers[@]}" -gt 0 ] || exit 0
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/wbg"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
    temporary_link=$(${pkgs.coreutils}/bin/mktemp "$state_dir/.current.XXXXXX")
    ${pkgs.coreutils}/bin/rm -f "$temporary_link"
    ${pkgs.coreutils}/bin/ln -s -- "''${wallpapers[0]}" "$temporary_link"
    ${pkgs.coreutils}/bin/mv -Tf -- "$temporary_link" "$state_dir/current"
    exec ${pkgs.wbg}/bin/wbg "''${wallpapers[0]}"
  '';
  wallpaperSwitcher = pkgs.writeShellApplication {
    name = "wallpaper-switcher";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      systemd
      util-linux
    ];
    text = ''
      set -euo pipefail
      runtime_dir="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
      exec 9>"$runtime_dir/wallpaper-switcher.lock"
      flock --nonblock 9 || exit 0

      wallpaper_dir="$HOME/images/wallpapers"
      [ -d "$wallpaper_dir" ] || { printf 'Wallpaper directory does not exist: %s\n' "$wallpaper_dir" >&2; exit 1; }
      mapfile -d "" -t wallpapers < <(find "$wallpaper_dir" -maxdepth 1 -type f -print0 | sort -z)
      [ "''${#wallpapers[@]}" -gt 0 ] || { printf 'No wallpapers found in: %s\n' "$wallpaper_dir" >&2; exit 1; }
      choice=$({ printf '%s\n' "Random"; printf '%s\n' "''${wallpapers[@]##*/}"; } \
        | "$HOME/.local/bin/fuzzel" --dmenu --prompt="Wallpaper: " --lines=20 --minimal-lines) || exit 0
      if [ "$choice" = "Random" ]; then
        mapfile -d "" -t random_wallpaper < <(printf '%s\0' "''${wallpapers[@]}" | shuf -z -n 1)
        wallpaper="''${random_wallpaper[0]}"
      else
        wallpaper="$wallpaper_dir/$choice"
        [ -f "$wallpaper" ] || exit 0
      fi
      temporary=$(mktemp "$HOME/.wbg.XXXXXX")
      trap 'rm -f "$temporary"' EXIT
      { printf '#!%s\n' '${pkgs.bash}/bin/bash'; printf 'exec %q %q\n' '${pkgs.wbg}/bin/wbg' "$wallpaper"; } > "$temporary"
      chmod 0700 "$temporary"
      mv "$temporary" "$HOME/.wbg"
      trap - EXIT
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/wbg"
      mkdir -p "$state_dir"
      temporary_link=$(mktemp "$state_dir/.current.XXXXXX")
      rm -f "$temporary_link"
      ln -s -- "$wallpaper" "$temporary_link"
      mv -Tf -- "$temporary_link" "$state_dir/current"
      systemctl --user reset-failed wallpaper.service
      systemctl --user restart wallpaper.service
      dynamic-theme refresh "$wallpaper"
    '';
  };
in
{
  home.packages = [
    dynamicTheme
    pkgs.matugen
    systemTheme
    ttyTheme
    wallpaperSwitcher
  ];

  home.activation.initializeWbg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.wbg" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0700 ${initialWbg} "$HOME/.wbg"
    fi
  '';

  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Wayland session wallpaper";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "%h/.wbg";
      Restart = "on-failure";
      RestartSec = "250ms";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.file.".local/bin/fuzzel" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      color_scheme=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
      if [ "$color_scheme" = "'prefer-light'" ]; then
        generated="''${XDG_CACHE_HOME:-$HOME/.cache}/matugen/dynamic/fuzzel-light.ini"
      else
        generated="''${XDG_CACHE_HOME:-$HOME/.cache}/matugen/dynamic/fuzzel-dark.ini"
      fi
      config=${fuzzelFallback}
      [ ! -r "$generated" ] || config="$generated"
      exec ${pkgs.fuzzel}/bin/fuzzel --config="$config" "$@"
    '';
  };

  xdg.configFile."mako/config".text = ''
    anchor=top-right
    border-radius=5
    border-size=0
    default-timeout=5000
    font=JetBrainsMono Nerd Font 12
    width=360
  '';

  # The generated file contains both wallpaper-derived light and dark modes.
  home.file.".local/bin/mako-themed" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      generated="''${XDG_CACHE_HOME:-$HOME/.cache}/matugen/dynamic/mako.conf"
      if [ ! -r "$generated" ]; then
        ${dynamicTheme}/bin/dynamic-theme generate current
      fi
      if [ -r "$generated" ]; then
        exec ${pkgs.mako}/bin/mako --config "$generated" "$@"
      fi
      exec ${pkgs.mako}/bin/mako --config "$HOME/.config/mako/config" "$@"
    '';
  };

  systemd.user.services.system-theme-init = {
    Unit = {
      Description = "Apply the persisted desktop color scheme";
      After = [
        "wallpaper.service"
      ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${systemTheme}/bin/system-theme apply";
      ExecStartPre = "${dynamicTheme}/bin/dynamic-theme generate current";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Qt's GTK 3 platform integration reads the same interface settings as GTK,
  # keeping Qt 5 and Qt 6 applications on the selected light/dark variant.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
}
