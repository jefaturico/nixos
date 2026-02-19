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
    mpv
    obs-studio
    pandoc
    gsettings-desktop-schemas
    pwvucontrol
    helix
    ripgrep
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
      nativeBuildInputs = [ pkg-config wayland-scanner ];
      buildInputs = [ 
        libinput wayland wlroots 
        libxkbcommon pixman
        xorg.libxcb xorg.xcbutilwm 
        xwayland
      ];
      enableParallelBuilding = true;
      
      preBuild = ''
        cp ${../dots/dwl/config.h} config.h
        cp ${../dots/dwl/config.mk} config.mk
      '';
      
      installPhase = ''
        make PREFIX=$out install
      '';
    })
  ];

}
