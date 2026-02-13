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
      GDK_SCALE = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      MOZ_ENABLE_WAYLAND = "1";
      GTK_CSD = "0";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "wlroots";
      NIXOS_OZONE_WL = "1";
      PATH = "$HOME/.local/bin:$PATH";
      XDG_DATA_DIRS = "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS";
    };
  };

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME";
      documents = "$HOME";
      download = "$HOME/downloads";
      music = "$HOME";
      pictures = "$HOME";
      publicShare = "$HOME";
      templates = "$HOME";
      videos = "$HOME";
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "text/plain" = [ "nvim.desktop" ];
        "text/markdown" = [ "nvim.desktop" ];
        "application/x-shellscript" = [ "nvim.desktop" ];
        "text/html" = "helium.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "x-scheme-handler/about" = "helium.desktop";
        "x-scheme-handler/unknown" = "helium.desktop";
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
    gtk3.extraCss = /* css */ ''
      window:not(#zen):not(.zen-browser) headerbar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }
      window:not(#zen):not(.zen-browser) window.csd,
      window:not(#zen):not(.zen-browser) window.csd decoration {
        box-shadow: none;
      }
    '';
    gtk4.extraCss = /* css */ ''
      window:not(#zen):not(.zen-browser) headerbar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }
      window:not(#zen):not(.zen-browser) window.csd {
        box-shadow: none;
      }
    '';
  };


}
