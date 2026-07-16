{ pkgs, ... }:
let
  stremioNoCsd = pkgs.writeShellApplication {
    name = "stremio-no-csd";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      exec flatpak run com.stremio.Stremio --no-window-decorations "$@"
    '';
  };
in
{
  home = {
    packages = [ stremioNoCsd ];

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
      NNN_OPTS = "eEHR"; # entry, exit on q, hidden, relative
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
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "text/plain" = [ "jf-emacsclient.desktop" ];
        "text/markdown" = [ "jf-emacsclient.desktop" ];
        "application/x-shellscript" = [ "jf-emacsclient.desktop" ];
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
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
