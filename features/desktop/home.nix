{ pkgs, ... }:

# How the graphical session presents itself to applications: the environment
# handed to every child process, widget-toolkit theming, standard
# directories, default handlers, and the two small session services.
{
  home = {
    username = "jefaturico";
    homeDirectory = "/home/jefaturico";
    stateVersion = "26.05";

    # GTK applications installed through Home Manager look up GSettings
    # schemas relative to these; without them some abort on start.
    packages = with pkgs; [
      glib
      gsettings-desktop-schemas
    ];
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

    # Lowercase paths, and `createDirectories = false` so a directory exists
    # only once something actually puts a file in it.
    userDirs = {
      enable = true;
      createDirectories = false;
      setSessionVariables = true;
      desktop = "$HOME/desktop";
      documents = "$HOME/documents";
      download = "$HOME/downloads";
      music = "$HOME/music";
      pictures = "$HOME/pictures";
      projects = "$HOME/projects";
      publicShare = "$HOME/public";
      templates = "$HOME/templates";
      videos = "$HOME/videos";
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

  # Gammastep warms the display after sunset; udiskie mounts removable media
  # for the file dialogs. Both are session-scoped.
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
}
