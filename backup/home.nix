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
    home.username = "jefaturico";
    home.homeDirectory = "/home/jefaturico";
    home.stateVersion = "25.11";
    home.sessionVariables = {
      XCURSOR_SIZE = "24";
      XCURSOR_THEME = "Adwaita";
      GDK_SCALE = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      MOZ_ENABLE_WAYLAND = "1";
    };

    programs.bash = {
      enable = true;
      shellAliases = {
      };
      sessionVariables = {
	EDITOR = "vim";
      };
      initExtra = ''
	# Import colorscheme from 'wal' asynchronously
			# &   Run the process in the background.
			# ( ) Hide shell job control messages.
			(cat ~/.cache/wal/sequences &)

			# To add support for TTYs
			if [ -f ~/.cache/wal/colors-tty.sh ]; then
			source ~/.cache/wal/colors-tty.sh
			fi
      '';
    };

    home.pointerCursor = {
      gtk.enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24; 
    };

    gtk.enable = true;
    gtk.cursorTheme.name = "Adwaita";
    gtk.cursorTheme.size = 24;

    programs.fuzzel = {
      enable = true;
    };

    programs.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
      extraPackages = epkgs: with epkgs; [
        vterm
        treesit-grammars.with-all-grammars
      ];
    };
    services.emacs.enable = true;

    programs.git = {
	enable = true;
      settings = {
	user.name  = "jefaturico";
	user.email = "jefaturico@gmail.com";
	init.defaultBranch = "main";
	safe.directory = "/etc/nixos";
      };
    };

    home.file.".emacs.d" = {
      source = create_symlink "${dotfiles}/emacs/";
      recursive = true;
    };

    home.file.".zen" = {
      source = create_symlink "${dotfiles}/zen/";
      recursive = true;
    };

    xdg.configFile = builtins.mapAttrs 
      (name: subpath: {
	source = create_symlink "${dotfiles}/${subpath}";
	recursive = true;
      })
      configs;	

    services.mako = {
      enable = true;
    };
  
    services.gammastep = {
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
	
    home.packages = with pkgs; [
      cmake
      gcc
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      libnotify
      libtool
      ripgrep
      brightnessctl
      wireplumber
      jq
      zoxide
      wbg
      xwayland-satellite
      emacs-lsp-booster
      keepassxc
      imagemagick
      foot

      (pkgs.python3.withPackages (ps: with ps; [
	pywal
	haishoku
      ]))
    ];
  }
