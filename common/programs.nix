{
  pkgs,
  osConfig,
  lib,
  ...
}:

let

  calendarDirs = {
    Scheduled = "~/.calendars/emiliohurtadosr@gmail.com/";
    Critical = "~/.calendars/bf06f35ac421e7839cfe16e31fb6ca4532c850a29556616e724eb33e0fde934f@group.calendar.google.com/";
    Routine = "~/.calendars/ee2eb2b218fe4d5eee4bef53bd1502b96d1408b55f816968477d2bf8adedc9fb@group.calendar.google.com/";
    Holidays = "~/.calendars/clpissrgc5kms8r8dtm6ip31f506esjfelo2sthecdgmopbechgn4bj7dtnmer355phmur8@virtual/";
  };

in
{

  programs = {

    bash = {
      enable = true;
      sessionVariables = {
        TERM = "foot";
        EDITOR = "nvim";
        BROWSER = "brave";
        DEFAULT_BROWSER = "brave";
        LEDGER_FILE = "$HOME/finances/main.journal";
      };

      initExtra = ''
        export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"
        eval "$(zoxide init bash)"

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
        }) // {
          pname = pkgs.vscode-fhs.pname or "vscode";
          version = pkgs.vscode-fhs.version or "latest";
        };
    };
  };

  xdg.configFile."khal/config".text = ''
    [calendars]
    [[Scheduled]]
    path = ${calendarDirs.Scheduled}
    readonly = False
    color = light green

    [[Critical]]
    path = ${calendarDirs.Critical}
    readonly = False
    color = light red

    [[Routine]]
    path = ${calendarDirs.Routine}
    readonly = False
    color = yellow

    [[Holidays]]
    path = ${calendarDirs.Holidays}
    readonly = True
    color = dark gray

    [default]
    default_calendar = Scheduled
    timedelta = 7d

    [locale]
    timeformat = %H:%M
    dateformat = %m-%d
    longdateformat = %Y-%m-%d
    datetimeformat = %m-%d %H:%M
    longdatetimeformat = %Y-%m-%d %H:%M

    [keybindings]
    external_edit = e
    export = meta E
  '';

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    config = {
      urgency.user.tag.uni.coefficient = 6.0;
      urgency.user.tag.cert.coefficient = 3.0;
      urgency.user.tag.personal.coefficient = 1.0;
      urgency.user.tag.deep.coefficient = 3.5;
      urgency.user.tag.shallow.coefficient = 0.0;
      urgency.user.tag.quick.coefficient = 2.0;
      urgency.user.tag.away.coefficient = 0.0;
      urgency.user.tag.waiting.coefficient = -5.0;
      urgency.tags.coefficient = 1.0;
    };
  };

  home.packages =
    with pkgs;
    [
      bat
      brightnessctl
      calibre
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
      libnotify
      libreoffice
      neovim
      mpv
      obsidian
      kdePackages.okular
      typst
      pandoc
      playerctl
      gsettings-desktop-schemas
      bitwarden-desktop
      pwvucontrol
      hugo
      hledger
      hledger-iadd
      hledger-web
      markdown-oxide
      nil
      nixfmt-rfc-style
      ripgrep
      ruff
      ripdrag
      shfmt
      stylua
      uget
      wbg
      wireplumber
      wl-clipboard
      subsurface
      qbittorrent
      slurp
      grim
      wlrctl
      tinymist
      khal
      xwayland-satellite
      python3
      zoxide
      taskwarrior-tui
      vdirsyncer
      visidata
      obs-studio
      qgis
    ]

    ++ lib.optionals (osConfig.networking.hostName == "galileo") [
      piper
    ];
}
