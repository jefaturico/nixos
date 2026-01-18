{
  inputs,
  pkgs,
  osConfig,
  ...
}:

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
      GDK_SCALE = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      MOZ_ENABLE_WAYLAND = "1";
      GTK_CSD = "0";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "river";
    };

    file.".config/wal/templates/fuzzel.ini".text = ''
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
      };

      initExtra = /* bash */ ''
                eval "$(zoxide init bash)"

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

        hx() {
            if [ $# -eq 0 ]; then
              command hx .
            else
              command hx "$@"
            fi
          }
      '';
    };

    foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=16";
          pad = "24x24 center-when-maximized-and-fullscreen";
        };
        colors = {
          alpha = if osConfig.networking.hostName == "galileo" then "0.98" else "0.8";
        };
      };
    };

    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=12";
          prompt-font = "JetBrainsMono Nerd Font:weight=bold:size=12";
          prompt = "\"λ \"";
          icons-enabled = "no";
          list-executables-in-path = "no";
          lines = 5;
          width = 40;
          horizontal-pad = 20;
          vertical-pad = 15;
          inner-pad = 5;
          include = "~/.cache/wal/fuzzel.ini";
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
        news.version = "99.9.9";
        confirmation = false;
        allow.empty.filter = true;
        bulk = 0;
        nag = "";
        verbose = "blank,header,footnote";
        "default.command" = "ready";
        "project.indent" = "on";
        "summary.all.projects" = "on";
        "annotations" = "none";
        "report.next.columns" =
          "id,start,entry.age,deps,priority,project,tags,recur,scheduled.countdown,due.relative,until.remaining,description.count,urgency";
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
        plugins = [ pkgs.zathuraPkgs.zathura_pdf_mupdf ];
      };
      options = {
        database = "null";
        render-loading = "false";
        selection-clipboard = "clipboard";
        guioptions = "none";
        statusbar-h-padding = 0;
        statusbar-v-padding = 0;
        page-cache-size = 512;
        window-title-basename = "true";
        default-bg = "rgba(0,0,0,${if osConfig.networking.hostName == "galileo" then "0.98" else "0.8"})";
        recolor = true;
        recolor-lightcolor = "rgba(0,0,0,0)";
        continuous-hist-save = true;
      };
    };
  };

  wayland.windowManager.river = {
    enable = true;
    extraConfig = /* bash */ ''
            #!/bin/sh

            dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=river

            riverctl background-color 0x000000

            if [ -f "$HOME/.cache/wal/colors.sh" ]; then
                . "$HOME/.cache/wal/colors.sh"

                FOCUSED="0x''${color4#\#}ff"

                UNFOCUSED="0x000000${if osConfig.networking.hostName == "galileo" then "fa" else "cc"}"
            fi

            if [ -f "$HOME/.wbg" ]; then
                sh "$HOME/.wbg" &
                FULL_PATH=$(grep -o '/home/[^" ]* ' "$HOME/.wbg")
                wal --saturate 0.2 -n -q -b 000000 -i "$FULL_PATH" &
            fi

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

            riverctl map normal Mod4 plus  send-layout-cmd wideriver "--count +1"
            riverctl map normal Mod4       period send-layout-cmd wideriver "--count 1"
            riverctl map normal Mod4       minus send-layout-cmd wideriver "--count -1"

            riverctl map-pointer normal Mod4 BTN_LEFT   move-view
            riverctl map-pointer normal Mod4 BTN_RIGHT  resize-view
            riverctl map-pointer normal Mod4 BTN_MIDDLE toggle-float
            riverctl map normal Mod4+Shift space toggle-float

            riverctl map normal Mod4 Escape spawn "riverctl close"
            riverctl map normal Mod4 Return spawn "footclient"
            riverctl map normal Mod4+Shift Return spawn "footclient -a 'floater'"
            riverctl map normal Mod4 P      spawn fuzzel

            riverctl map normal Mod4+Shift Escape exit

            riverctl map normal Mod4 B       spawn "$HOME/nixos/utils/shell/river-setbg.sh"
            riverctl map normal Mod4+Shift B spawn "$HOME/nixos/utils/shell/river-setbg.sh -r"

            riverctl map normal Mod4 D spawn "$HOME/nixos/utils/shell/wpdf-find.sh"

            riverctl map -repeat normal None XF86AudioRaiseVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+"
            riverctl map -repeat normal None XF86AudioLowerVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"
            riverctl map         normal None XF86AudioMute        spawn "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

            riverctl map -repeat normal None XF86MonBrightnessUp   spawn "brightnessctl set +20%"
            riverctl map -repeat normal None XF86MonBrightnessDown spawn "brightnessctl set 20%-"

            riverctl map normal Mod4 R spawn "pkill wideriver && ~/.config/river/init"

            riverctl map normal Mod4 1         spawn "$HOME/nixos/utils/shell/river-lof.sh zen zen 1"
            riverctl map normal Mod4+Shift 1   set-view-tags 1
            riverctl map normal Mod4+Control 1 toggle-focused-tags 1

            for i in $(seq 2 9); do
                tags=$((1 << (i - 1)))
                riverctl map normal Mod4 $i         set-focused-tags $tags
                riverctl map normal Mod4+Shift $i   set-view-tags $tags
                riverctl map normal Mod4+Control $i toggle-focused-tags $tags
            done

            riverctl hide-cursor timeout 5000
            riverctl hide-cursor when-typing enabled

            riverctl rule-add -app-id "zen"         tags 1
            riverctl rule-add -app-id "floater"     float
            riverctl rule-add -app-id "*"           ssd

            riverctl set-focused-tags 2

            [ -x "$(pgrep foot)" ] || foot --server
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
        default-timeout = 3000;
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

  home.packages = with pkgs; [
    anki
    bat
    brightnessctl
    cmake
    fd

    fzf
    gcc
    gimp
    imagemagick
    imv
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    kdePackages.kdenlive
    keepassxc
    libnotify
    libreoffice
    libtool
    markdown-oxide
    mpv
    nixfmt
    obs-studio
    pandoc
    pwvucontrol
    ripgrep
    stylua
    fff
    ffmpeg
    antigravity
    wbg
    wideriver
    wl-clipboard
    wireplumber
    xwayland
    nixd
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
