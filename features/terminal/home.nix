{ ... }:

# Foot runs as a shared server so new terminals open instantly; `footclient`
# comes from the same package and is what every keybinding spawns.
{
  programs.foot = {
    enable = true;
    server.enable = true;

    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=16";
        pad = "24x24 center-when-maximized-and-fullscreen";
      };

      # Not cosmetic: silences a startup warning about the Nerd Font not
      # advertising itself as monospace.
      tweak.font-monospace-warn = "no";
    };
  };
}
