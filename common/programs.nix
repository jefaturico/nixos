{
  pkgs,
  osConfig,
  lib,
  ...
}:

let
  # Custom build of dwl (Dynamic Window Manager for Wayland).
  # This builds dwl from source using the files in ../dots/dwl.
  dwl-custom = pkgs.stdenv.mkDerivation {
    name = "dwl-custom";
    src = ../dots/dwl;
    nativeBuildInputs = with pkgs; [
      pkg-config
      wayland-scanner
    ];
    buildInputs = with pkgs; [
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
      # Inject our personal configuration headers into the build.
      cp ${../dots/dwl/config.def.h} config.h
      cp ${../dots/dwl/config.mk} config.mk

      # Dynamic wlroots version detection to ensure compatibility with nixpkgs.
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
  };
in
{

  programs = {

    bash = {
      enable = true;
      sessionVariables = {
        TERM = "foot";
        EDITOR = "hx";
        BROWSER = "brave";
        DEFAULT_BROWSER = "brave";
      };

      initExtra = /* bash */ ''
        export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"
        eval "$(zoxide init bash)"

        bind "set completion-ignore-case on"

        # Use a lambda prompt in graphical sessions, otherwise a standard '$'.
        if [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
          _prompt_char="λ"
        else
          _prompt_char="\$"
        fi
        PS1='\[\e[34m\]\w\[\e[0m\] \[\e[32m\]'"$_prompt_char"'\[\e[0m\] '

        # Bash quality-of-life shell options.
        shopt -s autocd     # 'cd' is optional for directories
        shopt -s cdspell    # fix minor typos in 'cd'
        shopt -s checkwinsize
        shopt -s cmdhist
        shopt -s dirspell
        shopt -s globstar   # recursive globbing (**/*.nix)
        shopt -s histappend

        HISTCONTROL=ignoreboth:erasedups
        HISTSIZE=10000
        HISTFILESIZE=20000
      '';
    };

    foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=16";
          pad = "24x24 center-when-maximized-and-fullscreen";
          initial-window-size-chars = "120x40";
          resize-by-cells = "no";
          workers = 8;
          include = "~/.cache/wallust/colors-foot.ini";
        };
        colors = {
          alpha = 1.0;
        };
        tweak = {
          font-monospace-warn = "no";
        };
      };
    };

    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=12";
          icons-enabled = "no";
          list-executables-in-path = "no";
          lines = 5;
          width = 40;
          horizontal-pad = 20;
          vertical-pad = 15;
          inner-pad = 5;
          include = "~/.cache/wallust/colors-fuzzel.ini";
          match-mode = "fzf";
        };

        border = {
          width = 1;
          radius = 0;
        };
        "key-bindings" = {
          execute-input = "Control+Return";
        };
      };
    };

    git = {
      enable = true;
      settings = {
        user.name = "jefaturico";
        user.email = "jefaturico@gmail.com";
        init.defaultBranch = "main";
        safe.directory = "/etc/nixos";
      };
    };

    zathura = {
      enable = true;
      package = pkgs.zathura.override {
        plugins = [
          pkgs.zathuraPkgs.zathura_pdf_mupdf
        ];
      };
      options = {
        render-loading = "false";
        guioptions = "none";
        page-cache-size = 1024;
        continuous-hist-save = true;
        selection-clipboard = "clipboard";
        database = "sqlite";
        sandbox = "none";
        include = "~/.cache/wallust/colors-zathura";
      };
    };

    nnn = {
      enable = true;
      package = pkgs.nnn;
      bookmarks = {
        d = "~/downloads";
        n = "~/nixos";
        w = "~/workbench";
      };
    };

    fzf.enable = true;
  };

  home.packages =
    with pkgs;
    [
      dwl-custom
      bat
      bc
      brightnessctl
      calibre
      calcurse
      fd
      ffmpeg
      gimp
      imagemagick
      imv
      librewolf
      (brave.override {
        commandLineArgs = [
          "--enable-features=VaapiVideoDecodeLinuxGL,PipeWireWebRTCScreensharing"
          "--disable-features=UseChromeOSDirectVideoDecoder"
          "--use-gl=egl"
          "--ozone-platform=wayland"
        ];
      })
      tor-browser
      libnotify
      libreoffice
      lswt
      helix
      mpv
      obsidian
      typst
      pandoc
      gsettings-desktop-schemas
      bitwarden-desktop
      pwvucontrol
      hugo
      markdown-oxide
      yacreader
      nil
      nixfmt-rfc-style
      texlab
      ripgrep
      uget # minimal alternative: aria2
      wbg
      wireplumber
      wl-clipboard
      qbittorrent # minimal alternative: tremc
      slurp
      grim
      wlrctl
      tinymist
      xwayland
      zoxide
    ]
    # Conditional package inclusion: only install heavy apps on non-laptop hosts.
    ++ lib.optionals (osConfig.networking.hostName != "coriolis") [
      (antigravity.override {
        commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu-compositing";
      })
      obs-studio
      qgis
    ]
    # Logitech mouse configuration tool: only needed on Galileo.
    ++ lib.optionals (osConfig.networking.hostName == "galileo") [
      piper
    ];
}
