# The themes. This is the one place a colour scheme is defined: every
# program takes its colours from stylix, and stylix takes them from here.
#
# Each theme is a base16 scheme, light or dark, and a wallpaper. The first
# one, `defaultTheme`, is what the system starts in. Every other theme is
# built next to it and can be switched to with Super+Shift+T
# (home/theme-switch.nix). Schemes to pick from:
#   ls $(nix build --no-link --print-out-paths nixpkgs#base16-schemes)/share/themes
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  schemes = "${pkgs.base16-schemes}/share/themes";
  forest = ../dotfiles/wallpapers/forest-fog-deer-3840x2160.jpg;
  default = config.coriolis.themes.${config.coriolis.defaultTheme};
in
{
  options.coriolis = {
    defaultTheme = lib.mkOption { type = lib.types.str; };
    themes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            scheme = lib.mkOption { type = lib.types.str; };
            polarity = lib.mkOption {
              type = lib.types.enum [
                "dark"
                "light"
              ];
            };
            wallpaper = lib.mkOption { type = lib.types.path; };
          };
        }
      );
    };
  };

  config = {
    coriolis.defaultTheme = "gruvbox-dark";
    coriolis.themes = {
      gruvbox-dark = {
        scheme = "${schemes}/gruvbox-dark-medium.yaml";
        polarity = "dark";
        wallpaper = forest;
      };
      # Atom's One Light: near-black on near-white. Text 10.9:1 against the
      # background; its faintest syntax colour is 3.1:1.
      one-light = {
        scheme = "${schemes}/one-light.yaml";
        polarity = "light";
        wallpaper = forest;
      };
    };

    stylix = {
      enable = true;
      base16Scheme = default.scheme;
      inherit (default) polarity;
      image = default.wallpaper;

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font";
        };
        sansSerif = {
          package = pkgs.noto-fonts;
          name = "Noto Sans";
        };
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
        sizes = {
          # foot and Emacs, as before.
          terminal = 14;
          applications = 12;
          # mako and fuzzel.
          popups = 12;
          desktop = 12;
        };
      };

      # Off for Brave. stylix would set one seed colour by browser policy:
      # Brave derives its own shades from it, so the result is near the palette
      # but never equal to it, and the policy locks the theme setting. Without
      # it, Brave's "Use GTK" option (brave://settings/appearance) follows the
      # GTK theme, which has the exact colours.
      targets.chromium.enable = false;

      # Without a cursor theme the pointer falls back to an ugly default.
      cursor = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
        size = 24;
      };
    };

    # The theme switch (home/theme-switch.nix) needs to find the user
    # config of every theme. This puts the default one, which contains the
    # others, at a path that does not change.
    environment.etc."hm-generation".source =
      config.home-manager.users.${username}.home.activationPackage;
  };
}
