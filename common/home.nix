{ inputs, config, pkgs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/nixos/dotfiles";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configs = {
    niri = "niri";
    foot = "foot";
    fuzzel = "fuzzel";
    mako = "mako";
  };
in

  {
    home = {
      username = "jefaturico";
      homeDirectory = "/home/jefaturico";
      stateVersion = "25.11";

      pointerCursor = {
        gtk.enable = true;
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
        size = 24; 
      };

      sessionVariables = {
        XCURSOR_SIZE = "24";
        XCURSOR_THEME = "Adwaita";
        GDK_SCALE = "1";
        QT_AUTO_SCREEN_SCALE_FACTOR = "0";
        MOZ_ENABLE_WAYLAND = "1";
        WAYLAND_DISPLAY = "wayland-1";
      };

      file.".emacs.d" = {
        source = create_symlink "${dotfiles}/emacs/";
        recursive = true;
      };

      file.".zen" = {
        source = create_symlink "${dotfiles}/zen/";
        recursive = true;
      };
    };

    xdg = {
      configFile = builtins.mapAttrs 
        (name: subpath: {
          source = create_symlink "${dotfiles}/${subpath}";
          recursive = true;
        })
        configs;	

      userDirs = {
        enable = true;
        createDirectories = true;
        desktop = "$HOME";
        documents = "$HOME";
        download = "$HOME/downloads";
        music = "$HOME";
        pictures = "$HOME";
        publicShare = "$HOME";
        templates = "$HOME";
        videos = "$HOME";
      };
    };

    gtk = {
      enable = true;
      cursorTheme.name = "Adwaita";
      cursorTheme.size = 24;
    };

    programs = {

      bash = {
        enable = true;
        shellAliases = {};
        sessionVariables = {
          EDITOR = "vim";
        };
        initExtra = ''
          (cat ~/.cache/wal/sequences &)

    if [ -f ~/.cache/wal/colors-tty.sh ]; then
      source ~/.cache/wal/colors-tty.sh
    fi

    bind "set completion-ignore-case on"
    bind "set show-all-if-ambiguous on"

    PS1='\[\e[34m\]\w\[\e[0m\] \[\e[32m\]λ\[\e[0m\] '

    shopt -s autocd
    shopt -s cdspell
    shopt -s checkwinsize
    shopt -s cmdhist
    shopt -s dirspell
    shopt -s globstar
    shopt -s histappend
    shopt -s nocaseglob

    HISTCONTROL=ignoreboth:erasedups
    HISTSIZE=10000
    HISTFILESIZE=20000
        '';
      };

      emacs = {
        enable = true;
        package = pkgs.emacs-pgtk;
        extraPackages = epkgs: with epkgs; [
          vterm
          treesit-grammars.with-all-grammars
        ];
      };

      fuzzel = { enable = true; };

      git = {
	    enable = true;
        settings = {
	      user.name  = "jefaturico";
	      user.email = "jefaturico@gmail.com";
	      init.defaultBranch = "main";
	      safe.directory = "/etc/nixos";
        };
      };

      zathura = {
        enable = true;
        package = pkgs.zathura.override {
          plugins = [ pkgs.zathuraPkgs.zathura_pdf_mupdf ];
        };
        options = {
          database = "null";
          sandbox = "none";
          render-loading = "false";
          selection-clipboard = "clipboard";
          guioptions = "none";
          statusbar-h-padding = 0;
          statusbar-v-padding = 0;
          show-status-bar = "false";
          incremental-search = "true";
          page-cache-size = 512;
          stop-at-last-page = "true";
        };
      };
    };

    services = {
      emacs = {
        enable = true;
        startWithUserSession = "graphical";
      };

      mako = {
        enable = true;
      };
  
      gammastep = {
        enable = true;
        provider = "manual";
        latitude = 40.4;
        longitude = -3.7;
        temperature = {
	      day = 6500;
	      night = 3500;
        };
        settings = {
	      general = {
            adjustment-method = "wayland";
            fade = 1;
	      };
        };
      };
    };

    home.packages = with pkgs; [
      brightnessctl
      cmake
      emacs-lsp-booster
      foot
      fd
      gcc
      imagemagick
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      jq
      keepassxc
      libnotify
      libreoffice
      libtool
      ripgrep
      wbg
      wireplumber
      gimp
      json_c
      pkg-config
      xwayland-satellite
      zoxide

      (pkgs.python3.withPackages (ps: with ps; [
	    pywal
	    haishoku
      ]))
    ];
  }
