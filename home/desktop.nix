{
  config,
  lib,
  pkgs,
  dotfiles,
  ...
}:
let
  # fuzzel and mako were in the monospace font. stylix would give them the
  # sans one, so they are pointed back at its monospace font.
  mono = config.stylix.fonts.monospace.name;
  popupSize = toString config.stylix.fonts.sizes.popups;

  # The border colour of fuzzel and the notifications: gruvbox orange, the
  # same as the focused window in Hyprland (home/hyprland.nix). Other
  # choices from the palette: base08 red, base0A yellow, base0B green,
  # base0C aqua, base0D blue, base0E purple.
  accent = config.lib.stylix.colors.base09;
in
{
  # ---- Raw files (symlinks into ~/nixos/dotfiles) ---------------------------
  home.file = {
    # bookmarks, find-document, systeminfo, volume
    ".scripts".source = dotfiles "scripts";
    ".bookmarks.txt".source = dotfiles "bookmarks.txt";

    # Hyprland (swaybg) and the lock screen point at this path.
    "images/wallpapers/forest-fog-deer-3840x2160.jpg".source =
      ../dotfiles/wallpapers/forest-fog-deer-3840x2160.jpg;
    # Screenshots are saved here, and nothing creates the directory.
    "images/screenshots/.keep".text = "";
  };

  # ---- Terminal ------------------------------------------------------------
  # Colours and font come from stylix (modules/theme.nix).
  programs.foot = {
    enable = true;
    settings = {
      main = {
        pad = "20x20 center-when-maximized-and-fullscreen";
      };
    };
  };

  # ---- Launcher ------------------------------------------------------------
  # Colours and font come from stylix.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = lib.mkForce "${mono}:size=${popupSize}";
        prompt = "\"λ \"";
        icons-enabled = "no";
        minimal-lines = "yes";
        horizontal-pad = 40;
        vertical-pad = 20;
      };
      # Two pixels, like the window borders.
      border = {
        width = 2;
        radius = 0;
      };
      colors.border = lib.mkForce "${accent}ff";
    };
  };

  # ---- Notifications -------------------------------------------------------
  # Colours and font come from stylix. Runs as a user service.
  services.mako = {
    enable = true;
    settings = {
      sort = "-time";
      layer = "overlay";
      border-size = 2;
      border-color = lib.mkForce "#${accent}";
      border-radius = 0;
      default-timeout = 5000;
      font = lib.mkForce "${mono} ${popupSize}";
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

  # ---- fzf -----------------------------------------------------------------
  # Enabled as a module rather than a plain package so stylix colours it.
  # Its shell key bindings stay off.
  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
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
