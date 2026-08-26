{ ... }:

# The application launcher.
{
  home-manager.users.jefaturico =
    { ... }:
    let
      palette = import ../lib/palette.nix;

    fuzzelConfig = colors: ''
      [main]
      font=JetBrainsMono Nerd Font:size=12
      prompt="λ "
      icons-enabled=no

      [colors]
      background=${colors.background}ff
      text=${colors.text}ff
      prompt=${colors.text}ff
      placeholder=${colors.dim}ff
      input=${colors.text}ff
      match=${colors.accent}ff
      selection=${colors.selection}ff
      selection-text=${colors.selectionText}ff
      selection-match=${colors.accent}ff
      border=${colors.border}ff

      [border]
      width=2
      radius=5
    '';
    in
    {
      # fuzzel has no include directive and no reload, so both configurations
      # are generated in full and `desktop-theme` points ~/.config/fuzzel.ini
      # at one of them. Every launch is a fresh process, so that is enough.
      programs.fuzzel.enable = true;

      # Monokai Pro, the same palette the terminal uses; the `ff` appended in
      # the template makes every colour fully opaque, so the launcher never
      # shows what is behind it. `desktop-theme` swaps the symlink between
      # these two.
      xdg.configFile = {
        "fuzzel/fuzzel-dark.ini".text = fuzzelConfig palette.dark.ui;
        "fuzzel/fuzzel-light.ini".text = fuzzelConfig palette.light.ui;
      };
    };
}
