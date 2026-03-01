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
    helix = "helix";
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
      ".latexmkrc".text = ''
        $pdf_previewer = 'zathura';
        $pdf_update_method = 0;
      '';
    }
    // (
      # Automatically symlink directories in ./dots/ to ~/.config/
      # We use mkOutOfStoreSymlink so that changes to files in the git repo
      # are immediately reflected without needing a 'nixos-rebuild switch'.
      builtins.listToAttrs (
        map (name: {
          name = ".config/${name}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/${symlinks.${name}}";
          };
        }) (builtins.attrNames symlinks)
      )
      // {
        # Wallust templates generate configuration files based on wallpaper colors.
        ".config/wallust/templates/colors-foot.ini".text = ''
          [colors]
          foreground={{foreground | strip}}
          background={{background | strip}}
          regular0={{color0 | strip}}
          regular1={{color1 | strip}}
          regular2={{color2 | strip}}
          regular3={{color3 | strip}}
          regular4={{color4 | strip}}
          regular5={{color5 | strip}}
          regular6={{color6 | strip}}
          regular7={{color7 | strip}}
          bright0={{color8 | strip}}
          bright1={{color9 | strip}}
          bright2={{color10 | strip}}
          bright3={{color11 | strip}}
          bright4={{color12 | strip}}
          bright5={{color13 | strip}}
          bright6={{color14 | strip}}
          bright7={{color15 | strip}}
        '';
        ".config/wallust/templates/colors-fuzzel.ini".text = ''
          [colors]
          background={{background | strip}}ff
          text={{foreground | strip}}ff
          match={{color1 | strip}}ff
          selection={{color2 | strip}}ff
          selection-text={{background | strip}}ff
          selection-match={{color1 | strip}}ff
          border={{color3 | strip}}ff
          prompt={{color4 | strip}}ff
        '';
        ".config/wallust/templates/colors-mako".text = ''
          background-color={{background}}ff
          text-color={{foreground}}ff
          border-color={{color3}}ff
        '';
        ".config/wallust/templates/colors-zathura".text = ''
          set default-bg "{{background}}"
          set default-fg "{{foreground}}"
          set statusbar-bg "{{background}}"
          set statusbar-fg "{{foreground}}"
          set inputbar-bg "{{background}}"
          set inputbar-fg "{{color4}}"
          set notification-bg "{{background}}"
          set notification-fg "{{foreground}}"
          set notification-error-bg "{{background}}"
          set notification-error-fg "{{color1}}"
          set notification-warning-bg "{{background}}"
          set notification-warning-fg "{{color3}}"
          set highlight-color "{{color1}}"
          set highlight-active-color "{{color2}}"
          set completion-bg "{{background}}"
          set completion-fg "{{color4}}"
          set completion-highlight-bg "{{color2}}"
          set completion-highlight-fg "{{background}}"
          set recolor-lightcolor "{{background}}"
          set recolor-darkcolor "{{foreground}}"
        '';

        ".config/wallust/templates/colors-obsidian.css".text = ''
          .theme-dark {
            --background-primary: {{background}} !important;
            --background-primary-alt: {{color0 | lighten(0.05)}} !important;
            --background-secondary: {{color0 | lighten(0.03)}} !important;
            --background-secondary-alt: {{color0 | lighten(0.06)}} !important;
            --background-modifier-border: {{color8}}44 !important;
            --text-normal: {{foreground}} !important;
            --text-muted: {{color7}} !important;
            --text-faint: {{color8}} !important;
            --text-accent: {{color4}} !important;
            --text-accent-hover: {{color12}} !important;
            --interactive-normal: {{color0 | lighten(0.05)}} !important;
            --interactive-hover: {{color0 | lighten(0.1)}} !important;
            --interactive-accent: {{color4}} !important;
            --interactive-accent-hover: {{color12}} !important;
            --text-selection: {{color2}}44 !important;
            --text-highlight-bg: {{color3}}33 !important;
            --titlebar-background: {{background}} !important;
            --titlebar-background-focused: {{background}} !important;
            --tab-text-color-focused-active: {{foreground}} !important;
          }
        '';
        ".config/wallust/wallust.toml".text = ''
          backend = "fastresize"
          check_contrast = true

          [templates]
          foot = { template = 'colors-foot.ini', target = '~/.cache/wallust/colors-foot.ini' }
          fuzzel = { template = 'colors-fuzzel.ini', target = '~/.cache/wallust/colors-fuzzel.ini' }
          mako = { template = 'colors-mako', target = '~/.cache/wallust/colors-mako' }
          zathura = { template = 'colors-zathura', target = '~/.cache/wallust/colors-zathura' }
          obsidian = { template = 'colors-obsidian.css', target = '~/zettelkasten/.obsidian/snippets/wallust.css' }

        '';
      }
    );

  };

  home.packages =
    with pkgs;
    [
      bat
      brightnessctl
      calibre
      calcurse
      fd
      ffmpeg
      gimp
      imagemagick
      imv
      qutebrowser
      (brave.override {
        commandLineArgs = [
          "--enable-features=VaapiVideoDecodeLinuxGL"
          "--disable-features=UseChromeOSDirectVideoDecoder"
          "--use-gl=egl"
          "--ozone-platform=wayland"
        ];
      })
      tor-browser
      keepassxc
      libnotify
      libreoffice
      lswt
      helix
      mpv
      obsidian
      pandoc
      gsettings-desktop-schemas
      pwvucontrol
      markdown-oxide
      nil
      nixfmt-rfc-style
      texlab
      ripgrep
      wallust
      uget # minimal alternative: aria2
      wbg
      wireplumber
      wl-clipboard
      qbittorrent # minimal alternative: tremc
      slurp
      grim
      wlrctl
      xwayland
      zoxide
    ]
    # Conditional package inclusion: only install heavy apps on non-laptop hosts.
    ++ lib.optionals (osConfig.networking.hostName != "coriolis") [
      antigravity
      obs-studio
    ];

}
