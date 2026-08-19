{
  config,
  pkgs,
  ...
}:

let

  zathuraPackage = pkgs.zathura.override {
    plugins = [
      pkgs.zathuraPkgs.zathura_pdf_mupdf
    ];
  };

  zathuraOpenOkular = pkgs.writeShellApplication {
    name = "zathura-open-okular";
    text = ''
      file="''${1:-}"
      page="''${2:-1}"
      if [ -z "$file" ]; then
        exit 1
      fi

      case "$page" in
        *[!0-9]*|"")
          page=1
          ;;
      esac

      case "$file" in
        file://*)
          file="$(${pkgs.python3}/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(urllib.parse.urlparse(sys.argv[1]).path))' "$file")"
          ;;
      esac

      exec ${pkgs.kdePackages.okular}/bin/okular --page "$page" "$file"
    '';
  };

  findDocument = pkgs.writeShellApplication {
    name = "find-document";
    runtimeInputs = with pkgs; [
      coreutils
      fd
      fuzzel
      libreoffice
      util-linux
      zathuraPackage
    ];
    text = ''
      set -euo pipefail
      umask 077

      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/find-document"
      index="$cache_dir/index"
      lock="$cache_dir/index.lock"
      max_age=300

      refresh_index() {
        local new_index

        mkdir -p "$cache_dir"
        exec 9>"$lock"
        flock 9
        new_index=$(mktemp "$cache_dir/index.XXXXXX")
        trap 'rm -f "$new_index"' RETURN

        # Hidden directories are omitted deliberately: this excludes internal
        # trees such as .cache, .config, .local, and .git while retaining every
        # arbitrarily named user-facing directory below $HOME.
        fd --type f --type l --color never --print0 --no-ignore \
          --extension pdf \
          --extension epub \
          --extension odt --extension ods --extension odp --extension odg \
          --extension odf --extension odb \
          --extension fodt --extension fods --extension fodp --extension fodg \
          --extension ott --extension ots --extension otp --extension otg \
          --extension sxw --extension sxc --extension sxi --extension sxd \
          --extension doc --extension docx \
          --extension xls --extension xlsx \
          --extension ppt --extension pptx \
          --extension rtf \
          . "$HOME" >"$new_index"

        mv -f "$new_index" "$index"
        trap - RETURN
      }

      case "''${1:-}" in
        --refresh)
          refresh_index
          exit
          ;;
        --help|-h)
          printf '%s\n' \
            'Usage: find-document [--refresh]' \
            "Fuzzy-find documents below $HOME and open them." \
            'The index refreshes in the background after five minutes.'
          exit
          ;;
        "") ;;
        *)
          printf 'find-document: unknown option: %s\n' "$1" >&2
          exit 2
          ;;
      esac

      if [[ ! -f "$index" ]]; then
        refresh_index
      elif (( $(date +%s) - $(stat -c %Y "$index") > max_age )); then
        "$0" --refresh >/dev/null 2>&1 &
      fi

      if ! selected_index=$("$HOME/.local/bin/fuzzel" \
        --dmenu0 \
        --index \
        --only-match \
        --no-run-if-empty \
        --prompt='Find document: ' \
        --lines=15 \
        --minimal-lines \
        --match-mode=fzf \
        --counter \
        <"$index"); then
        exit 0
      fi

      if [[ ! "$selected_index" =~ ^[0-9]+$ ]]; then
        printf 'find-document: fuzzel returned an invalid index: %s\n' "$selected_index" >&2
        exit 1
      fi

      mapfile -d "" -t documents <"$index"
      selected="''${documents[$selected_index]:-}"
      [[ -n "$selected" ]] || exit 0

      if [[ ! -f "$selected" ]]; then
        printf 'find-document: file no longer exists: %s\n' "$selected" >&2
        refresh_index
        exit 1
      fi

      case "''${selected,,}" in
        *.pdf|*.epub)
          setsid --fork zathura "$selected" >/dev/null 2>&1
          ;;
        *)
          setsid --fork libreoffice "$selected" >/dev/null 2>&1
          ;;
      esac
    '';
  };

in
{

  imports = [
    ./services.nix
    ./session.nix
  ];

  programs = {
    bash = {
      enable = true;
      enableCompletion = false;
      shellAliases.o = "xdg-open";
      sessionVariables = {
        EDITOR = "hx";
        VISUAL = "hx";
        BROWSER = "qutebrowser";
        DEFAULT_BROWSER = "qutebrowser";
        LEDGER_FILE = "$HOME/documents/personal/finance/main.journal";
      };
      initExtra = ''
        export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"

        # A Linux virtual console has no desktop settings API of its own, so
        # initialize it from the persisted dconf light/dark preference.
        if [[ $TERM == linux ]]; then
          tty-theme
        fi

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

        # Keep graphical terminal titles useful to window selectors: show the
        # foreground command while it runs and the working directory at the
        # prompt. Applications can override this with a richer title of their
        # own.
        if [[ $TERM != linux && $TERM != dumb ]]; then
          _terminal_set_title() {
            printf '\e]0;%s\e\\' "$1"
          }

          _terminal_preexec() {
            local command="''${1#"''${1%%[![:space:]]*}"}"
            local program="''${command%%[[:space:]]*}"
            program="''${program##*/}"
            [[ -n $program ]] && _terminal_set_title "$program"
          }

          _terminal_prompt_end() {
            local command_status=$?
            _terminal_set_title "''${PWD/#$HOME/~}"

            return "$command_status"
          }

          trap '_terminal_preexec "$BASH_COMMAND"' DEBUG
          PROMPT_COMMAND+=(_terminal_prompt_end)
        fi
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
        };
        # Matugen supplies both color slots to each client. These settings only
        # retain the mode-specific transparency policy before a palette exists.
        "colors-dark" = {
          alpha = 0.7;
          alpha-mode = "matching";
          blur = true;
        };
        "colors-light" = {
          alpha = 0.7;
          alpha-mode = "matching";
          blur = true;
        };
        tweak = {
          font-monospace-warn = "no";
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

    qutebrowser = {
      enable = true;
      # Keep interactive site permissions and per-site exceptions while the
      # declarative settings below remain authoritative on every activation.
      loadAutoconfig = true;
      searchEngines = {
        DEFAULT = "https://duckduckgo.com/?q={}";
        g = "https://www.google.com/search?q={}";
        np = "https://search.nixos.org/packages?query={}";
        nw = "https://wiki.nixos.org/w/index.php?search={}";
      };
      settings = {
        auto_save.session = true;
        confirm_quit = [ "downloads" ];
        content = {
          autoplay = false;
          blocking.method = "adblock";
        };
        downloads.location.directory = "~/downloads";
        editor.command = [
          "footclient"
          "hx"
          "{file}"
        ];
        session.lazy_restore = true;
        url = {
          default_page = "about:blank";
          start_pages = [ "about:blank" ];
        };
      };
    };

    zathura = {
      enable = true;
      package = zathuraPackage;
      options = {
        adjust-open = "width";
        continuous-hist-save = true;
        database = "sqlite";
        guioptions = "none";
        page-cache-size = 2048;
        recolor = false;
        render-loading = false;
        sandbox = "normal";
        scroll-step = 80;
        selection-clipboard = "clipboard";
        statusbar-basename = true;
        window-title-basename = true;
      };
      mappings = {
        o = "exec \"${zathuraOpenOkular}/bin/zathura-open-okular '$FILE' $PAGE\"";
        n = "navigate previous";
        p = "navigate next";
        "<C-n>" = "scroll down";
        "<C-p>" = "scroll up";
      };
    };

    fzf.enable = true;

  };

  xdg = {
    configFile = {
      "helix" = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/helix";
      };

      "okularrc" = {
        force = true;
        text = ''
          MenuBar=Disabled

          [Desktop Entry]
          FullScreen=false

          [General]
          LockSidebar=true
          ShowSidebar=false

          [MainWindow]
          MenuBar=Disabled
        '';
      };

      "okularpartrc" = {
        force = true;
        text = ''
          [Core Performance]
          MemoryLevel=Low

          [Dlg Performance]
          EnableCompositing=false

          [General]
          MaxRecentItems=8
          ShowEmbeddedContentMessages=false
          ShowOSD=false
          ttsVoice=samantha

          [Main View]
          ShowBottomBar=false
          ShowLeftPanel=false

          [PageView]
          BackgroundColor=0,0,0
          PrimaryAnnotationToolBar=QuickAnnotationToolBar
          ShowScrollBars=false
          SmoothScrolling=false
          TrimMargins=true
          UseCustomBackgroundColor=true

          [Reviews]
          AnnotationContinuousMode=true
          QuickAnnotationDefaultAction=0
          QuickAnnotationTools=<tool default="true" id="1" name="Yellow Highlighter" type="highlight"><engine color="#ffff00" type="TextSelector"><annotation color="#ffffff00" type="Highlight"/></engine><shortcut>1</shortcut></tool>,<tool default="true" id="2" name="Green Highlighter" type="highlight"><engine color="#00ff00" type="TextSelector"><annotation color="#ff00ff00" type="Highlight"/></engine><shortcut>2</shortcut></tool>,<tool id="3" type="underline"><engine color="#ff0000" type="TextSelector"><annotation color="#ffff0000" type="Underline"/></engine><shortcut>3</shortcut></tool>,<tool default="true" id="4" name="Insert Text" type="typewriter"><engine block="true" type="PickPoint"><annotation color="#00ffffff" textColor="#000000" type="Typewriter" width="0"/></engine><shortcut>4</shortcut></tool>,<tool id="5" type="note-inline"><engine block="true" color="#ffff00" hoverIcon="tool-note-inline" type="PickPoint"><annotation color="#ffffff00" textColor="#ff000000" type="FreeText"/></engine><shortcut>5</shortcut></tool>,<tool id="6" type="note-linked"><engine color="#ffff00" hoverIcon="tool-note"><annotation color="#ffffff00" icon="Note" type="Text"/></engine><shortcut>6</shortcut></tool>
        '';
      };
    };

  };

  home.packages = with pkgs; [
    antigravity
    bat
    brave
    calibre
    fd
    ffmpeg
    findDocument
    gcc
    gimp
    glib
    gsettings-desktop-schemas
    hledger
    hugo
    imagemagick
    imv
    kdePackages.okular
    libreoffice
    lua-language-server
    markdown-oxide
    mpv
    helix
    nil
    nixfmt
    obs-studio
    pandoc
    pdfarranger
    pwvucontrol
    python3
    qbittorrent
    qgis
    ripdrag
    ripgrep
    ruff
    shfmt
    stylua
    subsurface
    tinymist
    tree-sitter
    vim
    uget
    unzip
    waypipe
    zathuraOpenOkular
    zoxide
  ];
}
