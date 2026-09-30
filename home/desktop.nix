{
  pkgs,
  dotfiles,
  ...
}:
{
  # ---- Raw files (symlinks into ~/nixos/dotfiles) ---------------------------
  xdg.configFile = {
    "niri/config.kdl".source = dotfiles "niri/config.kdl";
  };

  home.file = {
    # bookmarks, find-document, idle-behavior (swayidle + swaylock),
    # systeminfo, volume
    ".scripts".source = dotfiles "scripts";
    ".bookmarks.txt".source = dotfiles "bookmarks.txt";

    # niri (swaybg) and idle-behavior (swaylock) point at this path.
    "images/wallpapers/forest-fog-deer-3840x2160.jpg".source =
      ../dotfiles/wallpapers/forest-fog-deer-3840x2160.jpg;
    # niri saves screenshots here and does not create the directory.
    "images/screenshots/.keep".text = "";
  };

  # ---- Terminal ------------------------------------------------------------
  # Was ~/.config/foot/foot.ini, minus the commented defaults.
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "monospace:size=14";
        pad = "20x20 center-when-maximized-and-fullscreen";
        include = "${pkgs.foot.themes}/share/foot/themes/gruvbox";
      };
      colors-dark = {
        background = "2d353b";
        foreground = "d3c6aa";
        regular0 = "7a8478";
        regular1 = "e67e80";
        regular2 = "a7c080";
        regular3 = "dbbc7f";
        regular4 = "7fbbb3";
        regular5 = "d699b6";
        regular6 = "83c092";
        regular7 = "d3c6aa";
        bright0 = "9da9a0";
        bright1 = "e67e80";
        bright2 = "a7c080";
        bright3 = "dbbc7f";
        bright4 = "7fbbb3";
        bright5 = "d699b6";
        bright6 = "83c092";
        bright7 = "d3c6aa";
      };
    };
  };

  # ---- Launcher ------------------------------------------------------------
  # Was ~/.config/fuzzel/fuzzel.ini
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        prompt = "\"λ \"";
        icons-enabled = "no";
        minimal-lines = "yes";
        horizontal-pad = 40;
        vertical-pad = 20;
      };
      colors = {
        background = "1d1d1dff";
        text = "ffffffff";
        prompt = "ffffffff";
        placeholder = "999999ff";
        input = "999999ff";
        selection = "333333ff";
        selection-text = "ffffffff";
        # The Arch file had `f3000ff`, one digit short.
        match = "ff3000ff";
      };
      border = {
        width = 0;
        radius = 0;
      };
    };
  };

  # ---- Notifications -------------------------------------------------------
  # Was ~/.config/mako/config. Runs as a user service, so niri's config no
  # longer has `spawn-at-startup "mako"`.
  services.mako = {
    enable = true;
    settings = {
      sort = "-time";
      layer = "overlay";
      border-size = 2;
      border-radius = 0;
      default-timeout = 5000;
      font = "monospace 12";
      padding = "10";
      anchor = "top-center";

      "urgency=high" = {
        default-timeout = 0;
        anchor = "center";
      };

      # The volume script sends its notifications as app "osd".
      "app-name=osd" = {
        anchor = "center";
        text-alignment = "center";
      };
    };
  };

  # ---- Outputs -------------------------------------------------------------
  # Was ~/.config/kanshi/config. Also a user service now.
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "undocked";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
          }
        ];
      }
      {
        profile.name = "docked";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            # By name, not by port: the port number changes (DP-10 on Arch,
            # DP-9 here). Same name as in the niri config.
            criteria = "HP Inc. HP E223 3CQ9152Q27";
            status = "enable";
          }
        ];
      }
    ];
  };

  # ---- Battery warnings ----------------------------------------------------
  # Was batsignal.service plus a drop-in with these arguments.
  services.batsignal = {
    enable = true;
    extraArgs = [
      "-w"
      "20"
      "-c"
      "15"
      "-d"
      "10"
    ];
  };

  # ---- Cursor --------------------------------------------------------------
  # Arch had the Adwaita cursors as a dependency of something else. Here
  # nothing brings a cursor theme, and niri logs "no default icon".
  home.pointerCursor = {
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
  };

  # ---- GTK -----------------------------------------------------------------
  # Was in dconf. The rest of that database was window sizes and leftovers
  # from apps that are no longer installed.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  # ---- XDG -----------------------------------------------------------------
  # Was ~/.config/user-dirs.dirs: everything in $HOME except pictures.
  xdg.userDirs = {
    enable = true;
    createDirectories = false;
    desktop = "$HOME/";
    download = "$HOME/";
    templates = "$HOME/";
    publicShare = "$HOME/";
    documents = "$HOME/";
    music = "$HOME/";
    videos = "$HOME/";
    pictures = "$HOME/images";
    projects = "$HOME/";
  };

  # Was ~/.config/mimeapps.list. That file mostly pointed at programs that
  # are gone (zen, Evolution) or at entries Thunderbird generated for
  # itself. This is what it resolved to in practice.
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        browser = "brave-origin.desktop";
        mail = "thunderbird.desktop";
      in
      {
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/about" = browser;
        "x-scheme-handler/unknown" = browser;
        "text/html" = browser;
        "application/xhtml+xml" = browser;

        "x-scheme-handler/mailto" = mail;
        "x-scheme-handler/mid" = mail;
        "message/rfc822" = mail;
        "x-scheme-handler/webcal" = mail;
        "x-scheme-handler/webcals" = mail;
        "text/calendar" = mail;
        "application/rss+xml" = mail;
        "x-scheme-handler/feed" = mail;

        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "writer.desktop";
      };
  };
}
