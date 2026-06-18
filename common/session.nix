{ pkgs, ... }:
{
  home = {
    pointerCursor = {
      gtk.enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    sessionVariables = {
      QT_QPA_PLATFORM = "wayland";
      XDG_CURRENT_DESKTOP = "niri";
      NIXOS_OZONE_WL = "1";
      NNN_OPTS = "eEHR"; # entry, exit on q, hidden, relative
      PATH = "$HOME/.local/bin:$PATH";
      XDG_DATA_DIRS = "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS";
    };
  };

  xdg = {
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
        "application/pdf" = [ "sioyek.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "text/plain" = [ "nvim.desktop" ];
        "text/markdown" = [ "nvim.desktop" ];
        "application/x-shellscript" = [ "nvim.desktop" ];
        "text/html" = "chromium.desktop";
        "x-scheme-handler/http" = "chromium.desktop";
        "x-scheme-handler/https" = "chromium.desktop";
        "x-scheme-handler/about" = "chromium.desktop";
        "x-scheme-handler/unknown" = "chromium.desktop";
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
    gtk3.extraCss = ''
      headerbar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }
      window.csd,
      window.csd decoration {
        box-shadow: none;
      }
    '';
    gtk4.extraCss = ''
      headerbar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }
      window.csd {
        box-shadow: none;
      }
    '';
  };
}
