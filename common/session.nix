{ pkgs, ... }:
let
  ewwBrowser = pkgs.writeShellApplication {
    name = "eww-browser";
    runtimeInputs = [
      pkgs.emacs-pgtk
      pkgs.python3
    ];
    text = ''
      url="''${1:-}"
      if [ -z "$url" ]; then
        echo "usage: eww-browser URL" >&2
        exit 2
      fi

      # JSON strings use escaping accepted by the Emacs Lisp reader, avoiding
      # code injection or broken quoting for URLs passed in by other programs.
      url_literal="$(${pkgs.python3}/bin/python3 -c \
        'import json, sys; print(json.dumps(sys.argv[1]))' "$url")"
      exec ${pkgs.emacs-pgtk}/bin/emacsclient \
        --alternate-editor=${pkgs.emacs-pgtk}/bin/emacs \
        --eval "(eww-browse-url $url_literal)"
    '';
  };

  stremioNoCsd = pkgs.writeShellApplication {
    name = "stremio-no-csd";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      # WebKitGTK's DMA-BUF renderer trips over NVIDIA explicit sync during
      # startup.  Disable that driver path while retaining native Wayland and
      # DMA-BUF acceleration.
      exec flatpak run --env=__NV_DISABLE_EXPLICIT_SYNC=1 \
        com.stremio.Stremio --no-window-decorations "$@"
    '';
  };
in
{
  home = {
    packages = [
      ewwBrowser
      stremioNoCsd
    ];

    pointerCursor = {
      gtk.enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    sessionVariables = {
      GTK_CSD = "0";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      PATH = "$HOME/.local/bin:$PATH";
      XDG_DATA_DIRS = "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS";
    };
  };

  xdg = {
    dataFile."applications/jf-emacsclient.desktop".text = ''
      [Desktop Entry]
      Name=Emacs Client
      GenericName=Text Editor
      Comment=Edit files in the running Emacs session
      Exec=emacsclient --create-frame --alternate-editor=emacs %F
      Icon=emacs
      Type=Application
      Terminal=false
      Categories=Utility;TextEditor;
      MimeType=text/plain;text/markdown;application/x-shellscript;
      StartupNotify=true
    '';

    dataFile."applications/jf-eww.desktop".text = ''
      [Desktop Entry]
      Name=EWW
      GenericName=Web Browser
      Comment=Browse the web in Emacs
      Exec=${ewwBrowser}/bin/eww-browser %U
      TryExec=${ewwBrowser}/bin/eww-browser
      Icon=emacs
      Type=Application
      Terminal=false
      Categories=Network;WebBrowser;
      MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/about;x-scheme-handler/unknown;
      StartupNotify=false
    '';

    # Stremio supports undecorated windows natively.  Override the exported
    # Flatpak desktop entry so every graphical launch uses that mode.  D-Bus
    # activation must be disabled or it bypasses the command-line option.
    dataFile."applications/com.stremio.Stremio.desktop".text = ''
      [Desktop Entry]
      Name=Stremio
      Comment=Freedom to Stream
      Icon=com.stremio.Stremio
      Categories=Utility;AudioVideo;Video;Player;
      Keywords=Stremio;Media;Play;
      Type=Application
      Exec=${stremioNoCsd}/bin/stremio-no-csd %U
      TryExec=${stremioNoCsd}/bin/stremio-no-csd
      MimeType=x-scheme-handler/stremio;
      Terminal=false
      StartupNotify=true
      DBusActivatable=false
    '';

    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
      desktop = "$HOME/misc";
      documents = "$HOME/misc";
      download = "$HOME/downloads";
      projects = "$HOME/misc";
      music = "$HOME/misc";
      pictures = "$HOME/misc";
      publicShare = "$HOME/misc";
      templates = "$HOME/misc";
      videos = "$HOME/misc";
    };

    mimeApps = {
      enable = true;
      associations.added = {
        "x-scheme-handler/stremio" = [ "com.stremio.Stremio.desktop" ];
      };
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "text/plain" = [ "jf-emacsclient.desktop" ];
        "text/markdown" = [ "jf-emacsclient.desktop" ];
        "application/x-shellscript" = [ "jf-emacsclient.desktop" ];
        "text/html" = "jf-eww.desktop";
        "x-scheme-handler/http" = "jf-eww.desktop";
        "x-scheme-handler/https" = "jf-eww.desktop";
        "x-scheme-handler/about" = "jf-eww.desktop";
        "x-scheme-handler/stremio" = [ "com.stremio.Stremio.desktop" ];
        "x-scheme-handler/unknown" = "jf-eww.desktop";
      };
    };
  };

  gtk = {
    enable = true;
    gtk3.extraConfig = {
      gtk-dialogs-use-header = false;
    };
    gtk4.extraConfig = {
      gtk-dialogs-use-header = false;
    };
    # GTK has no setting that universally disables CSD.  Hide the title-only
    # headerbars globally; keep ordinary application headerbars/toolbars intact.
    # The negative margin is intentional: unlike min-height/padding overrides,
    # it also collapses GTK's built-in default-decoration headerbar.
    gtk3.extraCss = /* css */ ''
      window:not(#zen):not(.zen-browser) headerbar.default-decoration,
      window:not(#zen):not(.zen-browser) .titlebar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }

      window.csd decoration {
        box-shadow: none;
        border: none;
      }
    '';
    gtk4.extraCss = /* css */ ''
      window:not(#zen):not(.zen-browser) headerbar.default-decoration,
      window:not(#zen):not(.zen-browser) .titlebar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }

      window.csd {
        box-shadow: none;
      }
    '';
  };
}
