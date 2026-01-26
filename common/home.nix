{
  inputs,
  pkgs,
  osConfig,
  ...
}:

{
  imports = [ ./scripts.nix ];

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
      GDK_SCALE = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      MOZ_ENABLE_WAYLAND = "1";
      GTK_CSD = "0";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "river";
      NIXOS_OZONE_WL = "1";
      PATH = "$HOME/.local/bin:$PATH";
    };

    file.".config/wal/templates/colors-fuzzel.ini".text = ''
      [colors]
      background={background.strip}ee
      text={foreground.strip}ff
      prompt={color4.strip}ff
      placeholder={color8.strip}ff
      input={foreground.strip}ff
      match={color4.strip}ff
      selection-match={background.strip}ff
      selection={color8.strip}ff
      selection-text={background.strip}ff
    '';

    file.".config/wal/templates/colors-task.theme".text = ''
      color.priorities.H=bold {color1}
      color.priorities.M={color2}
      color.priorities.L={color3}
      color.project.none={color4}
      color.tagged.all={color5}
      color.due={color1}
      color.overdue=bold {color1}
      color.active=black on {color2}
      color.scheduled={color6}
      color.calendar.today={color7}
    '';

    file.".config/wal/templates/colors-foot.ini".text = ''
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

    file.".config/helix/languages.toml".text = ''
      [[language]]
      name = "markdown"
      language-servers = ["markdown-oxide"]
      formatter = { command = "prettier", args = ["--parser", "markdown", "--prose-wrap", "never"] }
      text-width = 80
      auto-format = true
      soft-wrap = { enable = true, wrap-at-text-width = true }

      [language-server.markdown-oxide]
      command = "markdown-oxide"

    '';

    file.".config/moxide/settings.toml".text = ''
      heading_completions = false
      title_headings = false
      link_filenames_only = true
    '';




  };

  xdg = {

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

    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "text/plain" = [ "nvim.desktop" ];
        "text/markdown" = [ "nvim.desktop" ];
        "application/x-shellscript" = [ "nvim.desktop" ];
        "text/html" = "helium.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "x-scheme-handler/about" = "helium.desktop";
        "x-scheme-handler/unknown" = "helium.desktop";
      };
    };
  };

  gtk = {
    enable = true;
    gtk3.extraConfig = {
      gtk-dialogs-use-header = false;
    };
    gtk4.extraConfig = {
      gtk-dialogs-use-header = false;
    };
    gtk3.extraCss = /* css */ ''
      window:not(#zen):not(.zen-browser) headerbar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }
      window:not(#zen):not(.zen-browser) window.csd,
      window:not(#zen):not(.zen-browser) window.csd decoration {
        box-shadow: none;
      }
    '';
    gtk4.extraCss = /* css */ ''
      window:not(#zen):not(.zen-browser) headerbar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }
      window:not(#zen):not(.zen-browser) window.csd {
        box-shadow: none;
      }
    '';
  };

  programs = {

    bash = {
      enable = true;
      shellAliases = { };
      sessionVariables = {
        EDITOR = "hx";
        TERM = "foot";
        BROWSER = "helium";
        DEFAULT_BROWSER = "helium";
      };

      initExtra = /* bash */ ''
                export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"
                eval "$(zoxide init bash)"

                (cat ~/.cache/wal/sequences &)

                if [ -f ~/.cache/wal/colors-tty.sh ]; then
                  source ~/.cache/wal/colors-tty.sh
                fi

                bind "set completion-ignore-case on"

                PS1='\[\e[34m\]\w\[\e[0m\] \[\e[32m\]λ\[\e[0m\] '

                shopt -s autocd
                shopt -s cdspell
                shopt -s checkwinsize
                shopt -s cmdhist
                shopt -s dirspell
                shopt -s globstar
                shopt -s histappend

                HISTCONTROL=ignoreboth:erasedups
                HISTSIZE=10000
                HISTFILESIZE=20000

        hx() {
            if [ $# -eq 0 ]; then
              command hx .
            else
              command hx "$@"
            fi
          }
      '';
    };

    newsboat = {
      enable = true;
      autoReload = true;
      reloadThreads = 8;
      urls = [
        {
          url = "https://phys.org/rss-feed/earth-news/earth-sciences/";
          title = "Phys.org - Earth Sciences";
        }
        {
          url = "https://phys.org/rss-feed/earth-news/environment/";
          title = "Phys.org - Environment";
        }
        {
          url = "https://phys.org/rss-feed/breaking/";
          title = "Phys.org - Breaking News";
        }
      ];
      extraConfig = ''
        browser "open-focus"

        color background          default  default
        color listnormal          color15  default
        color listfocus           color0   color15 bold
        color listnormal_unread   color15  default
        color listfocus_unread    color0   color15 bold
        color info                color0   color4  bold
        color article             color15  default

        bind-key j down
        bind-key k up
        bind-key h quit
        bind-key l open
      '';
    };

    foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=16";
          pad = "24x24 center-when-maximized-and-fullscreen";
          include = "~/.cache/wal/colors-foot.ini";
        };
        colors = {
          alpha = if osConfig.networking.hostName == "galileo" then "0.97" else "0.8";
        };
      };
    };

    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=12";
          prompt = "\"λ \"";
          icons-enabled = "no";
          list-executables-in-path = "yes";
          lines = 5;
          width = 40;
          horizontal-pad = 20;
          vertical-pad = 15;
          inner-pad = 5;
          include = "~/.cache/wal/colors-fuzzel.ini";
        };
        border = {
          width = 0;
          radius = 0;
        };
      };
    };

    helix = {
      enable = true;
      settings = {
        editor = {
          color-modes = true;
          continue-comments = false;
          completion-replace = true;
          jump-label-alphabet = "fjdkslañ";
          line-number = "relative";
          popup-border = "none";
          scrolloff = 10;
          trim-final-newlines = true;
          trim-trailing-whitespace = true;
          file-picker = {
            ignore = false;
            git-ignore = false;
            git-global = false;
          };
          statusline = {
            left = [
              "mode"
              "file-name"
              "read-only-indicator"
              "file-modification-indicator"
            ];
          };
          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "block";
          };
          auto-pairs = false;
          soft-wrap = {
            enable = true;
            wrap-indicator = "";
          };
        };

        theme = "base16_transparent";
        keys.normal = {
          space.f = "file_picker";
          space.w = ":w";
          space.q = ":q";
          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];
        };
      };
    };

    taskwarrior = {
      enable = true;
      package = pkgs.taskwarrior2;
      config = {
        data.location = "~/.local/share/task";
        news.version = "3.9.9";
        news.auto = false;
        confirmation = false;
        allow.empty.filter = true;
        bulk = 0;
        nag = "";
        verbose = "blank,footnote";
        "default.command" = "ready";
        "project.indent" = "on";
        "summary.all.projects" = "on";
        "annotations" = "none";
        "report.notes.columns" = "entry,description";
        "report.notes.labels" = "Date,Annotation";
        "report.notes.sort" = "entry+";
        "report.notes.filter" = "status:pending";
        "report.next.columns" =
          "id,start,entry.age,depends,priority,project,tags,recur,scheduled.countdown,due.relative,until.remaining,description.count,urgency";
        "report.next.labels" = "ID,Active,Age,Deps,P,Project,Tag,Recur,S,Due,Until,Description,Urg";
        "report.ready.columns" = "id,start,scheduled,project,description.count";
        "report.ready.labels" = "ID,Active,Sched,Project,Description";
      };
      extraConfig = ''
        include $HOME/.cache/wal/colors-task.theme
      '';
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

    texlive = {
      enable = true;
      extraPackages = tpkgs: {
        inherit (tpkgs) scheme-small collection-langenglish;
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
        page-cache-size = 512;
        continuous-hist-save = true;
      };
    };

    fzf = {
      enable = true;
    };
  };

  wayland.windowManager.river = {
    enable = true;
    extraConfig = /* bash */ ''
      #!/bin/sh

      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=river

      systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
      systemctl --user start aurora.target graphical-session.target      riverctl background-color 0x000000

      if [ -f "$HOME/.cache/wal/colors.sh" ]; then
          . "$HOME/.cache/wal/colors.sh"

          FOCUSED="0x''${color1#\#}ff"
          UNFOCUSED="0x00000000"
      fi

      if [ -f "$HOME/.wbg" ]; then
          sh "$HOME/.wbg" &
          wal --saturate 0.2 -Rtneq -b 000000 &
      fi

      scratchTag=$((1 << 20))
      stickyTag=$((1 << 10))

      wideriver \
          --layout left \
          --layout-alt monocle \
          --stack even \
          --count-master 1 \
          --ratio-master 0.6 \
          --count-wide-left 0 \
          --ratio-wide 0.35 \
          --smart-gaps \
          --inner-gaps 6 \
          --outer-gaps 6 \
          --border-width 3 \
          --border-width-monocle 0 \
          --border-width-smart-gaps 0 \
          --border-color-focused "''${FOCUSED:-0x555555ff}" \
          --border-color-unfocused "''${UNFOCUSED:-0x111111ff}" \
          --log-threshold error &

      riverctl default-layout wideriver

      riverctl keyboard-layout -options "ctrl:nocaps" es
      riverctl set-repeat 50 200
      riverctl focus-follows-cursor normal

      riverctl input pointer-1267-12397-ELAN2202:00_04F3:306D_Touchpad natural-scroll enabled
      riverctl input pointer-1267-12397-ELAN2202:00_04F3:306D_Touchpad tap enabled

      riverctl input pointer-2-14-ETPS/2_Elantech_Touchpad natural-scroll enabled
      riverctl input pointer-2-14-ETPS/2_Elantech_Touchpad tap enabled
      riverctl input pointer-2-14-ETPS/2_Elantech_Touchpad pointer-accel 0.4

      riverctl map normal Mod4 J     focus-view next
      riverctl map normal Mod4 K     focus-view previous
      riverctl map normal Mod4 Space zoom

      riverctl map normal Mod4+Shift H send-layout-cmd wideriver "--layout left"
      riverctl map normal Mod4+Shift L send-layout-cmd wideriver "--layout right"
      riverctl map normal Mod4+Shift J send-layout-cmd wideriver "--layout bottom"
      riverctl map normal Mod4+Shift K send-layout-cmd wideriver "--layout top"
      riverctl map normal Mod4 M       send-layout-cmd wideriver "--layout monocle"

      riverctl map normal Mod4 L       send-layout-cmd wideriver "--ratio +0.1"
      riverctl map normal Mod4+Shift 0 send-layout-cmd wideriver "--ratio 0.5"
      riverctl map normal Mod4 H       send-layout-cmd wideriver "--ratio -0.1"

      riverctl map normal Mod4 plus   send-layout-cmd wideriver "--count +1"
      riverctl map normal Mod4 period send-layout-cmd wideriver "--count 1"
      riverctl map normal Mod4 minus  send-layout-cmd wideriver "--count -1"

      riverctl map-pointer normal Mod4 BTN_LEFT   move-view
      riverctl map-pointer normal Mod4 BTN_RIGHT  resize-view
      riverctl map-pointer normal Mod4 BTN_MIDDLE toggle-float
      riverctl map normal Mod4+Shift Space toggle-float

      riverctl map normal Mod4 Q       spawn "riverctl close"
      riverctl map normal Mod4 Return       spawn "footclient"
      riverctl map normal Mod4 P            spawn fuzzel

      riverctl map normal Mod4+Shift Escape exit

      riverctl map normal Mod4 B       spawn "river-setbg"
      riverctl map normal Mod4+Shift B spawn "river-setbg -r"

      riverctl map normal Mod4 D spawn "wdoc-find"
      riverctl map normal Mod4 W spawn "fuzzel-bookmarks"
      riverctl map normal Mod4+Shift W spawn "fuzzel-bookmarks --add"

      riverctl map normal Mod4 I spawn "systeminfo"
      riverctl map normal Mod4 T spawn "task-fuzzel"
      riverctl map normal Mod4+Shift N spawn "capture-thought"
      riverctl map normal Mod4 N spawn "shonke"
      riverctl map normal Mod4 E spawn "footclient -e hx ."

      riverctl map -repeat normal None XF86AudioRaiseVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+"
      riverctl map -repeat normal None XF86AudioLowerVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"
      riverctl map         normal None XF86AudioMute        spawn "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

      riverctl map -repeat normal None XF86MonBrightnessUp   spawn "brightnessctl set +10%"
      riverctl map -repeat normal None XF86MonBrightnessDown spawn "brightnessctl set 10%-"

      riverctl map normal Mod4 R spawn "pkill wideriver && ~/.config/river/init"

      riverctl map normal Mod4 1         spawn "river-lof helium helium 1 $stickyTag"
      riverctl map normal Mod4+Shift 1   set-view-tags 1
      riverctl map normal Mod4+Control 1 toggle-focused-tags 1

      for i in $(seq 2 9); do
          tags=$((1 << (i - 1)))
          riverctl map normal Mod4 $i         set-focused-tags $((tags | stickyTag))
          riverctl map normal Mod4+Shift $i   set-view-tags $tags
          riverctl map normal Mod4+Control $i toggle-focused-tags $tags
      done

      riverctl map normal Mod4 Backspace spawn "river-toggle-scratch $scratchTag scratchpad"
      riverctl spawn-tagmask $((((1 << 32) - 1) ^ scratchTag))

      riverctl map normal Super+Shift Backspace toggle-view-tags $stickyTag
      riverctl spawn-tagmask $((((1 << 32) - 1) ^ stickyTag))

      riverctl hide-cursor timeout 5000
      riverctl hide-cursor when-typing enabled

      riverctl rule-add -app-id "zen"     tags 1
      riverctl rule-add -app-id "helium"     tags 1
      riverctl rule-add -app-id "scratchpad" tags $scratchTag
      riverctl rule-add -app-id "scratchpad" float
      riverctl rule-add -app-id "*"       ssd

      riverctl set-focused-tags 2

      pgrep -x foot > /dev/null || foot --server
      lswt | grep -q "scratchpad" || footclient -a "scratchpad"
    '';
  };

  services = {

    mako = {
      enable = true;
      settings = {
        font = "JetBrainsMono Nerd Font Mono 12";
        background-color = "#000000";
        text-color = "#ffffff";
        border-size = 0;
        padding = "10";
        margin = "10";
        default-timeout = 2000;
      };
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

  systemd.user.services.mako = {
    Service = {
      Restart = "always";
      ExecStartPre = "${pkgs.procps}/bin/pkill -x mako || true";
    };
  };

  home.packages = with pkgs; [
    anki
    antigravity
    bat
    brightnessctl
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
    kdePackages.kdenlive
    keepassxc
    obsidian
    libnotify
    libreoffice
    lswt
    mpv
    nixd
    nixfmt
    obs-studio
    pandoc

    markdown-oxide
    nodePackages.prettier
    pwvucontrol
    ripgrep
    uget
    wbg
    wideriver
    wireplumber
    wl-clipboard
    wlrctl
    xwayland
    zoxide

    (pkgs.python3.withPackages (
      ps: with ps; [
        pywal
        haishoku
        colorthief
      ]
    ))
  ];

}
