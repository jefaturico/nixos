{
  writeShellApplication,
  coreutils,
  dconf,
  libnotify,
  mako,
  procps,
}:

# The single place the light/dark decision is made. Everything else either
# reads the portal's appearance setting (GTK, Qt, LibreWolf) or gets nudged
# by this script at runtime (mako), so no application ever needs to be
# restarted and no application is themed by hand.
#
#   desktop-theme            print the current theme
#   desktop-theme dark|light switch to that theme
#   desktop-theme toggle     switch to the other one
#   desktop-theme apply      re-apply the stored theme (session startup)
#   desktop-theme files      only refresh the on-disk fragments, no runtime
#                            calls; used from Home Manager activation, which
#                            runs outside the graphical session
writeShellApplication {
  name = "desktop-theme";
  runtimeInputs = [
    coreutils
    dconf
    libnotify
    mako
    procps
  ];
  text = ''
    set -euo pipefail

    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/desktop-theme"
    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"

    current_theme() {
      case "$(cat "$state_file" 2>/dev/null || true)" in
        light) echo light ;;
        *) echo dark ;;
      esac
    }

    store_theme() {
      mkdir -p "$(dirname "$state_file")"
      printf '%s\n' "$1" >"$state_file"
    }

    # fuzzel, kitty and sioyek are all started fresh with no portal
    # subscription of their own, and all three have an include directive, so
    # each one's whole palette is swapped by pointing a symlink at one of the
    # two generated files rather than rewriting anything.
    #
    # Sioyek gets no push_runtime counterpart on purpose. Its dark mode is a
    # shader toggled by `toggle_dark_mode`, for which there is no setter and
    # no way to read back which mode a window is in, so an already-open
    # document cannot be driven to a known state -- only the next one launched
    # follows the switch.
    write_files() {
      local theme="$1"
      mkdir -p "$config_home/fuzzel"
      if [ -e "$config_home/fuzzel/fuzzel-$theme.ini" ]; then
        ln -sfn "fuzzel-$theme.ini" "$config_home/fuzzel/fuzzel.ini"
      fi
      mkdir -p "$config_home/kitty"
      if [ -e "$config_home/kitty/kitty-$theme.conf" ]; then
        ln -sfn "kitty-$theme.conf" "$config_home/kitty/current-theme.conf"
      fi
      mkdir -p "$config_home/sioyek"
      if [ -e "$config_home/sioyek/sioyek-$theme.config" ]; then
        ln -sfn "sioyek-$theme.config" "$config_home/sioyek/current-theme.config"
      fi
    }

    # Everything that is already running.
    push_runtime() {
      local theme="$1" scheme gtk_theme
      if [ "$theme" = light ]; then
        scheme=prefer-light
        gtk_theme=Adwaita
      else
        scheme=prefer-dark
        gtk_theme=Adwaita-dark
      fi

      # This is the setting everything else keys off: xdg-desktop-portal-gtk
      # republishes it on org.freedesktop.appearance, which GTK 3/4, Qt 6 and
      # Chromium/Brave/Firefox/LibreWolf all subscribe to and act on without a
      # restart. kitty has no such subscription, hence the terminal-specific
      # branch just below.
      #
      # Written with dconf rather than gsettings on purpose: gsettings needs
      # the schemas on XDG_DATA_DIRS and fails outright without them, which
      # under `set -e` used to abort this function before it reached mako.
      # dconf talks to the same store and needs no schema.
      dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'"
      dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'"

      # mako has no reload-with-different-colors story, but it does have
      # modes: the config carries a [mode=light] block that overrides the
      # dark defaults, and this selects it without touching any file.
      makoctl mode -s "$theme" >/dev/null 2>&1 || true

      # kitty reloads its config file on SIGUSR1 — the same signal
      # home-manager already sends on a rebuild — so this just re-triggers
      # that now that write_files has repointed current-theme.conf at the
      # other palette.
      pkill -USR1 -u "$USER" kitty >/dev/null 2>&1 || true
    }

    set_theme() {
      local theme="$1"
      store_theme "$theme"
      write_files "$theme"
      push_runtime "$theme"
    }

    case "''${1:-current}" in
      current) current_theme ;;
      dark | light)
        set_theme "$1"
        notify-send \
          --app-name=theme \
          --hint=string:x-canonical-private-synchronous:theme \
          --expire-time=2000 \
          "Switched to the $1 theme"
        ;;
      toggle)
        if [ "$(current_theme)" = dark ]; then next=light; else next=dark; fi
        exec "$0" "$next"
        ;;
      apply)
        set_theme "$(current_theme)"
        ;;
      files)
        theme="$(current_theme)"
        store_theme "$theme"
        write_files "$theme"
        ;;
      *)
        echo 'usage: desktop-theme {current|dark|light|toggle|apply|files}' >&2
        exit 2
        ;;
    esac
  '';
}
