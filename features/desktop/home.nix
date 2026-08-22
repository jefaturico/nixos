{ pkgs, ... }:

# How the graphical session presents itself to applications: environment
# handed to every child process, widget-toolkit theming and decoration
# policy, standard directories, default handlers, and the two small user
# services that make the session comfortable.
{
  home = {
    username = "jefaturico";
    homeDirectory = "/home/jefaturico";
    stateVersion = "26.05";

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
    };
  };

  xdg = {
    dataFile."applications/jf-neovim.desktop".text = ''
      [Desktop Entry]
      Name=Neovim
      GenericName=Text Editor
      Comment=Edit files in Neovim inside Foot
      Exec=footclient nvim %F
      TryExec=footclient
      Icon=nvim
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

    # Individual handlers are declared by the module that owns the
    # application; this only turns the mechanism on.
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/plain" = [ "jf-neovim.desktop" ];
        "text/markdown" = [ "jf-neovim.desktop" ];
        "application/x-shellscript" = [ "jf-neovim.desktop" ];
      };
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-dialogs-use-header = false;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-dialogs-use-header = false;
    };
    # GTK has no setting that universally disables CSD.  Hide the title-only
    # headerbars globally; keep ordinary application headerbars/toolbars intact.
    # The negative margin is intentional: unlike min-height/padding overrides,
    # it also collapses GTK's built-in default-decoration headerbar.
    gtk3.extraCss = /* css */ ''
      headerbar.default-decoration,
      .titlebar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }

      window.csd decoration {
        box-shadow: none;
        border: none;
      }
    '';
    gtk4.extraCss = /* css */ ''
      headerbar.default-decoration,
      .titlebar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }

      window.csd {
        box-shadow: none;
      }
    '';
  };

  # Gammastep warms the display after sunset; udiskie mounts removable media
  # for the `usb` shell helper and the file dialogs. Both are session-scoped.
  services = {
    gammastep = {
      enable = true;
      provider = "manual";
      latitude = 40.4;
      longitude = -3.7;
      temperature = {
        day = 6500;
        night = 3500;
      };
      settings.general = {
        adjustment-method = "wayland";
        fade = 1;
      };
    };

    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };
  };

  # GTK applications installed through Home Manager look up GSettings schemas
  # relative to these; without them some of them abort on start.
  home.packages = with pkgs; [
    glib
    gsettings-desktop-schemas
  ];
}
