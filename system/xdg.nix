{ pkgs, ... }:

# The XDG plumbing of the session: portals, standard directories, default
# handlers, and the Home Manager account identity itself.
{
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  home-manager.users.jefaturico =
    { pkgs, ... }:
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
          Comment=Edit files in Neovim inside kitty
          Exec=kitty nvim %F
          TryExec=kitty
          Icon=nvim
          Type=Application
          Terminal=false
          Categories=Utility;TextEditor;
          MimeType=text/plain;text/markdown;application/x-shellscript;
          StartupNotify=true
        '';

        # Lowercase paths, and `createDirectories = false` so a directory
        # exists only once something actually puts a file in it.
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
    };
}
