{
  inputs,
  pkgs,
  osConfig,
  config,
  lib,
  ...
}:

let
  symlinks = {
    emacs = "emacs";
    river = "river";
  };
in
{
  imports = [
    ./scripts.nix
    ./programs.nix
    ./services.nix
    ./session.nix
  ];

  home = {
    username = "jefaturico";
    homeDirectory = "/home/jefaturico";
    stateVersion = "25.11";

    file = {
      ".config/moxide/settings.toml".text = ''
        heading_completions = false
        title_headings = false
        link_filenames_only = true
      '';
    }
    // (builtins.listToAttrs (
      map (name: {
        name = ".config/${name}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/${symlinks.${name}}";
        };
      }) (builtins.attrNames symlinks)
    ));

  };

  home.packages = with pkgs; [
    anki
    antigravity
    bat
    brightnessctl
    emacs-lsp-booster # LSP performance optimization for Emacs
    fd
    fff
    ffmpeg
    gimp
    (pkgs.appimageTools.wrapType2 {
      pname = "helium";
      version = "0.8.1.1";
      src = pkgs.fetchurl {
        url = "https://github.com/imputnet/helium-linux/releases/download/0.8.1.1/helium-0.8.1.1-x86_64.AppImage";
        sha256 = "sha256-n1wn80h9O7GpZz4AygNSKMcilX8lr6fJkiQBBPPQXok=";
      };
      extraPkgs = pkgs: [ pkgs.libsecret ];
    })
    (pkgs.makeDesktopItem {
      name = "helium";
      desktopName = "Helium";
      genericName = "Web Browser";
      exec = "helium %U";
      icon = "helium";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeTypes = [
        "text/html"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    })
    imagemagick
    imv
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    keepassxc
    libnotify
    libreoffice
    lswt
    mpv
    obs-studio
    pandoc
    gsettings-desktop-schemas
    pwvucontrol
    ripgrep
    river-classic
    uget
    wbg
    wireplumber
    wl-clipboard
    wlrctl
    xwayland
    zoxide
    (dwl.overrideAttrs (old: {
      src = ../dots/dwl;
    }))
  ];

}
