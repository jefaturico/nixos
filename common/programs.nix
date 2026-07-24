{
  pkgs,
  ...
}:

let

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

in
{

  programs = {
    bash = {
      enable = true;
      enableCompletion = false;
      sessionVariables = {
        EDITOR = "emacsclient --tty --alternate-editor=emacs";
        VISUAL = "emacsclient --create-frame --wait --alternate-editor=emacs";
        BROWSER = "eww-browser";
        DEFAULT_BROWSER = "eww-browser";
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

        # Let vterm track the shell's working directory and prompt boundaries
        # through its native OSC 51 protocol.
        if [[ "$INSIDE_EMACS" == vterm ]]; then
          _vterm_prompt_end() {
            printf '\e]51;A%s@%s:%s\e\\' "''${USER}" "''${HOSTNAME}" "$PWD"
          }
          PS1+='\[$(_vterm_prompt_end)\]'
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
      mappings = {
        o = "exec \"${zathuraOpenOkular}/bin/zathura-open-okular '$FILE' $PAGE\"";
        n = "navigate previous";
        p = "navigate next";
        "<C-n>" = "scroll down";
        "<C-p>" = "scroll up";
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
              --unset NIXOS_OZONE_WL \
              --set ELECTRON_OZONE_PLATFORM_HINT x11 \
              --add-flags "--ozone-platform=x11"
          '';
        })
        // {
          pname = pkgs.vscode-fhs.pname or "vscode";
          version = pkgs.vscode-fhs.version or "latest";
          meta = (pkgs.vscode-fhs.meta or { }) // {
            mainProgram = "code";
          };
        };
    };

  };

  xdg = {
    configFile = {
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
      zathuraOpenOkular
      libreoffice
      mpv
      brave
      librewolf
      pdfarranger
      kdePackages.okular
      pandoc
      playerctl
      gsettings-desktop-schemas
      glib
      pwvucontrol
      hugo
      hledger
      markdown-oxide
      moonlight-qt
      nil
      nixfmt
      ripgrep
      antigravity
      unzip
      ruff
      ripdrag
      shfmt
      uget
      subsurface
      waypipe
      qbittorrent
      python3
      zoxide
      obs-studio
      qgis
    ];
}
