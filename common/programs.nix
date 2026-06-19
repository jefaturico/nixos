{
  config,
  pkgs,
  osConfig,
  lib,
  ...
}:

let

  chromiumApp = pkgs.writeShellApplication {
    name = "chromium-app";
    runtimeInputs = [
      pkgs.jq
    ];
    text = ''
      set -u

      trim() {
          local value="$1"
          value="''${value#"''${value%%[![:space:]]*}"}"
          value="''${value%"''${value##*[![:space:]]}"}"
          printf '%s' "$value"
      }

      search_url() {
          local query encoded
          query="$1"
          encoded="$(jq -rn --arg q "$query" '$q | @uri')"
          printf 'https://duckduckgo.com/?q=%s' "$encoded"
      }

      normalize_target() {
          local target
          target="$(trim "$1")"

          if [ -z "$target" ]; then
              printf 'about:blank'
              return
          fi

          case "$target" in
              *[[:space:]]*)
                  search_url "$target"
                  return
                  ;;
          esac

          case "$target" in
              [a-zA-Z][a-zA-Z0-9+.-]*:*)
                  printf '%s' "$target"
                  ;;
              localhost|localhost/*|localhost:*)
                  printf 'http://%s' "$target"
                  ;;
              *.*)
                  printf 'https://%s' "$target"
                  ;;
              *)
                  search_url "$target"
                  ;;
          esac
      }

      url="$(normalize_target "$*")"
      exec ${lib.getExe config.programs.chromium.finalPackage} --app="$url"
    '';
  };

in
{

  programs = {
    chromium = {
      enable = true;
      package = pkgs.ungoogled-chromium;
      commandLineArgs = [
        "--ozone-platform=wayland"
        "--no-first-run"
        "--no-default-browser-check"
        "--enable-features=ExtensionMimeRequestHandling,OverlayScrollbar,ScrollableTabStrip"
        "--remote-debugging-address=127.0.0.1"
        "--remote-debugging-port=9222"
      ];
    };

    bash = {
      enable = true;
      enableCompletion = false;
      shellAliases = {
        vim = "nvim";
      };
      sessionVariables = {
        EDITOR = "nvim";
        BROWSER = "chromium-app";
        DEFAULT_BROWSER = "chromium-app";
        LEDGER_FILE = "$HOME/documents/personal/finance/main.journal";
      };
      initExtra = ''
        export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"

        usb() {
          local media_root target
          media_root="/run/media/''${USER:-$(${pkgs.coreutils}/bin/id -un)}"

          _usb_mounts() {
            [[ -d "$media_root" ]] || return 0
            ${pkgs.findutils}/bin/find "$media_root" \
              -mindepth 1 \
              -maxdepth 1 \
              -type d \
              -printf '%T@\t%p\n' 2>/dev/null \
              | ${pkgs.coreutils}/bin/sort -rn \
              | ${pkgs.coreutils}/bin/cut -f2-
          }

          case "''${1:-}" in
            -l|--list)
              target="$(_usb_mounts | ${pkgs.fzf}/bin/fzf --prompt='USB: ' --no-sort)" || return "$?"
              ;;
            -h|--help)
              printf '%s\n\n%s\n%s\n' \
                'Usage: usb [-l]' \
                '  usb     cd to the most recently mounted removable device and list it' \
                '  usb -l  choose a mounted removable device with fzf, cd to it, and list it'
              return 0
              ;;
            "")
              target="$(_usb_mounts | ${pkgs.coreutils}/bin/head -n 1)"
              ;;
            *)
              printf 'usb: unknown option: %s\n' "$1" >&2
              return 2
              ;;
          esac

          if [[ -z "$target" ]]; then
            printf 'usb: no mounted removable devices found under /run/media/%s\n' "$USER" >&2
            return 1
          fi

          cd "$target" && ls
        }

        bind "set completion-ignore-case on"

        if [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
          _prompt_char="λ"
        else
          _prompt_char="\$"
        fi
        PS1='\[\e[34m\]\w\[\e[0m\] \[\e[32m\]'"$_prompt_char"'\[\e[0m\] '

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

        eval "$(${pkgs.zoxide}/bin/zoxide init bash --cmd cd)"
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
        "colors-dark" = {
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
        adjust-open = "width";
        continuous-hist-save = true;
        database = "sqlite";
        guioptions = "none";
        page-cache-size = 2048;
        recolor = false;
        render-loading = false;
        sandbox = "none";
        scroll-step = 80;
        selection-clipboard = "clipboard";
        statusbar-basename = true;
        window-title-basename = true;
      };
    };

    nnn = {
      enable = true;
      package = pkgs.nnn;
      bookmarks = {
        d = "~/downloads";
        n = "~/nixos";
      };
    };

    fzf.enable = true;

    vscode = {
      enable = true;
      package =
        (pkgs.symlinkJoin {
          name = "vscode";
          paths = [ pkgs.vscode-fhs ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/code \
              --add-flags "--enable-features=UseOzonePlatform,WebUIDarkMode --ozone-platform=wayland --disable-gpu-compositing"
          '';
        })
        // {
          pname = pkgs.vscode-fhs.pname or "vscode";
          version = pkgs.vscode-fhs.version or "latest";
        };
    };
  };

  xdg.dataFile."applications/chromium.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Chromium
    GenericName=Web Browser
    Exec=chromium-app %U
    Terminal=false
    NoDisplay=true
    Categories=Network;WebBrowser;
    MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/about;x-scheme-handler/unknown;
  '';

  home.packages =
    with pkgs;
    [
      bat
      calibre
      fd
      ffmpeg
      gimp
      imagemagick
      imv
      chromiumApp
      libreoffice
      neovim
      mpv
      obsidian
      blanket
      pdfarranger
      kdePackages.okular
      typst
      pandoc
      playerctl
      gsettings-desktop-schemas
      pwvucontrol
      hugo
      hledger
      hledger-iadd
      hledger-web
      markdown-oxide
      nil
      nixfmt
      ripgrep
      unzip
      ruff
      ripdrag
      shfmt
      stylua
      gnome-solanum
      uget
      wl-clipboard
      subsurface
      qbittorrent
      tinymist
      calcure
      xwayland-satellite
      python3
      zoxide
      visidata
      obs-studio
      qgis
    ]

    ++ lib.optionals (osConfig.networking.hostName == "galileo") [
      piper
    ];
}
