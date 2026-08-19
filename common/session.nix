{ pkgs, ... }:
let
  stremioWayland = pkgs.symlinkJoin {
    name = "stremio-wayland";
    paths = [ pkgs.stremio-linux-shell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      unlink "$out/bin/stremio"
      makeWrapper ${pkgs.stremio-linux-shell}/bin/stremio "$out/bin/stremio" \
        --set GDK_BACKEND wayland \
        --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
        --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
        --set __NV_DISABLE_EXPLICIT_SYNC 1

      # The desktop file uses D-Bus activation, which otherwise bypasses the
      # wrapped executable and launches the upstream package directly.
      unlink "$out/share/dbus-1/services/com.stremio.Stremio.service"
      substitute \
        ${pkgs.stremio-linux-shell}/share/dbus-1/services/com.stremio.Stremio.service \
        "$out/share/dbus-1/services/com.stremio.Stremio.service" \
        --replace-fail \
        ${pkgs.stremio-linux-shell}/bin/stremio \
        "$out/bin/stremio"
    '';
  };

in
{
  home = {
    packages = [
      stremioWayland
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
      QT_QPA_PLATFORMTHEME = "gtk3";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      PATH = "$HOME/.local/bin:$PATH";
      XDG_DATA_DIRS = "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS";
    };
  };

  xdg = {
    dataFile."applications/jf-helix.desktop".text = ''
      [Desktop Entry]
      Name=Helix
      GenericName=Text Editor
      Comment=Edit files in Helix inside Foot
      Exec=footclient hx %F
      TryExec=footclient
      Icon=helix
      Type=Application
      Terminal=false
      Categories=Utility;TextEditor;
      MimeType=text/plain;text/markdown;application/x-shellscript;
      StartupNotify=true
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
        "text/plain" = [ "jf-helix.desktop" ];
        "text/markdown" = [ "jf-helix.desktop" ];
        "application/x-shellscript" = [ "jf-helix.desktop" ];
        "text/html" = "brave";
        "x-scheme-handler/http" = "brave";
        "x-scheme-handler/https" = "brave";
        "x-scheme-handler/about" = "brave";
        "x-scheme-handler/stremio" = [ "com.stremio.Stremio.desktop" ];
        "x-scheme-handler/unknown" = "brave";
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
