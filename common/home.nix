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
    helix = "helix";
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
    // (
      builtins.listToAttrs (
        map (name: {
          name = ".config/${name}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/${symlinks.${name}}";
          };
        }) (builtins.attrNames symlinks)
      )
      // {
        ".config/wal/templates/colors-foot.ini".text = ''
          [colors]
          foreground={foreground.strip}
          background={background.strip}
          regular0={color0.strip}
          regular1={color1.strip}
          regular2={color2.strip}
          regular3={color3.strip}
          regular4={color4.strip}
          regular5={color5.strip}
          regular6={color6.strip}
          regular7={color7.strip}
          bright0={color8.strip}
          bright1={color9.strip}
          bright2={color10.strip}
          bright3={color11.strip}
          bright4={color12.strip}
          bright5={color13.strip}
          bright6={color14.strip}
          bright7={color15.strip}
        '';
        ".config/wal/templates/colors-fuzzel.ini".text = ''
          [colors]
          background={background.strip}ff
          text={foreground.strip}ff
          match={color1.strip}ff
          selection={color2.strip}ff
          selection-text={background.strip}ff
          selection-match={color1.strip}ff
          border={color3.strip}ff
          prompt={color4.strip}ff
        '';
        ".config/wal/templates/colors-mako".text = ''
          background-color={background}ff
          text-color={foreground}ff
          border-color={color3}ff
        '';
      }
    );

  };

  home.packages = with pkgs; [
    antigravity
    bat
    brightnessctl
    calibre
    fd
    fff
    ffmpeg
    gimp
    imagemagick
    imv
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    keepassxc
    libnotify
    libreoffice
    lswt
    helix
    mpv
    obsidian
    obs-studio
    pandoc
    gsettings-desktop-schemas
    pwvucontrol
    markdown-oxide
    nil
    nixfmt-rfc-style
    texlab
    ripgrep
    pywal
    uget
    wbg
    wireplumber
    wl-clipboard
    wlrctl
    xwayland
    zoxide
    (stdenv.mkDerivation {
      name = "dwl-custom";
      src = ../dots/dwl;
      nativeBuildInputs = [
        pkg-config
        wayland-scanner
      ];
      buildInputs = [
        libinput
        wayland
        wlroots
        wayland-protocols
        libxkbcommon
        pixman
        xorg.libxcb
        xorg.xcbutilwm
        xwayland
      ];
      enableParallelBuilding = true;

      preBuild = ''
        cp ${../dots/dwl/config.h} config.h
        cp ${../dots/dwl/config.mk} config.mk

        echo "Checking for wlroots pkg-config..."
        if pkg-config --exists wlroots; then
          echo "Using wlroots.pc"
          substituteInPlace config.mk --replace "wlroots-0.19" "wlroots"
        elif pkg-config --exists wlroots-0.19; then
          echo "Using wlroots-0.19.pc"
        else
          echo "Error: wlroots pkg-config not found!"
          pkg-config --list-all | grep wlroots
          exit 1
        fi
      '';

      installPhase = ''
        make PREFIX=$out install
      '';
    })
  ];

}
