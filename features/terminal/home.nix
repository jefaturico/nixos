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
        initial-window-size-chars = "120x40";
        resize-by-cells = "no";
        initial-color-theme = "dark";
      };

      # Kanagawa Dragon, written out once instead of generated at runtime.
      "colors-dark" = {
        background = "181616";
        foreground = "c5c9c5";
        regular0 = "181616";
        regular1 = "c4746e";
        regular2 = "8a9a7b";
        regular3 = "c4b28a";
        regular4 = "8ba4b0";
        regular5 = "a292a3";
        regular6 = "8ea4a2";
        regular7 = "c5c9c5";
        bright0 = "625e5a";
        bright1 = "c4746e";
        bright2 = "8a9a7b";
        bright3 = "c4b28a";
        bright4 = "8ba4b0";
        bright5 = "a292a3";
        bright6 = "8ea4a2";
        bright7 = "c8c093";
      };

      tweak.font-monospace-warn = "no";
    };
  };
}
