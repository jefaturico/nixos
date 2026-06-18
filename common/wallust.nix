{ pkgs, ... }:
{
  home.packages = [ pkgs.wallust ];

  home.file = {
    ".config/wallust/wallust.toml".text = ''
      backend = "wal"
      palette = "dark16"
      check_contrast = true
      colorspace = "lab"

      [templates]
      foot = { template = 'colors-foot.ini', target = '~/.cache/wallust/colors-foot.ini' }
      footclient = { template = 'footclient-overrides.bash', target = '~/.cache/wallust/footclient-overrides.bash' }
      fuzzel = { template = 'colors-fuzzel.ini', target = '~/.cache/wallust/colors-fuzzel.ini' }
      mako = { template = 'colors-mako', target = '~/.cache/wallust/colors-mako' }
      obsidian = { template = 'colors-obsidian.css', target = '~/documents/notes/.obsidian/snippets/wallust.css' }
      neopywal = { template = 'colors_neopywal.vim', target = '~/.cache/wallust/colors_neopywal.vim' }

    '';

    # These Mustache-style templates are processed by wallust to generate
    # program-specific color configs from the current wallpaper palette.

    ".config/wallust/templates/colors_neopywal.vim".text = ''
      let background = "{{background}}"
      let foreground = "{{foreground}}"
      let cursor = "{{cursor}}"
      let color0 = "{{color0}}"
      let color1 = "{{color1}}"
      let color2 = "{{color2}}"
      let color3 = "{{color3}}"
      let color4 = "{{color4}}"
      let color5 = "{{color5}}"
      let color6 = "{{color6}}"
      let color7 = "{{color7}}"
      let color8 = "{{color8}}"
      let color9 = "{{color9}}"
      let color10 = "{{color10}}"
      let color11 = "{{color11}}"
      let color12 = "{{color12}}"
      let color13 = "{{color13}}"
      let color14 = "{{color14}}"
      let color15 = "{{color15}}"
    '';

    ".config/wallust/templates/colors-foot.ini".text = ''
      [colors-dark]
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

    ".config/wallust/templates/footclient-overrides.bash".text = ''
      footclient_color_args=(
        -o 'colors-dark.foreground={{foreground | strip}}'
        -o 'colors-light.foreground={{foreground | strip}}'
        -o 'colors-dark.background={{background | strip}}'
        -o 'colors-light.background={{background | strip}}'
        -o 'colors-dark.regular0={{color0 | strip}}'
        -o 'colors-light.regular0={{color0 | strip}}'
        -o 'colors-dark.regular1={{color1 | strip}}'
        -o 'colors-light.regular1={{color1 | strip}}'
        -o 'colors-dark.regular2={{color2 | strip}}'
        -o 'colors-light.regular2={{color2 | strip}}'
        -o 'colors-dark.regular3={{color3 | strip}}'
        -o 'colors-light.regular3={{color3 | strip}}'
        -o 'colors-dark.regular4={{color4 | strip}}'
        -o 'colors-light.regular4={{color4 | strip}}'
        -o 'colors-dark.regular5={{color5 | strip}}'
        -o 'colors-light.regular5={{color5 | strip}}'
        -o 'colors-dark.regular6={{color6 | strip}}'
        -o 'colors-light.regular6={{color6 | strip}}'
        -o 'colors-dark.regular7={{color7 | strip}}'
        -o 'colors-light.regular7={{color7 | strip}}'
        -o 'colors-dark.bright0={{color8 | strip}}'
        -o 'colors-light.bright0={{color8 | strip}}'
        -o 'colors-dark.bright1={{color9 | strip}}'
        -o 'colors-light.bright1={{color9 | strip}}'
        -o 'colors-dark.bright2={{color10 | strip}}'
        -o 'colors-light.bright2={{color10 | strip}}'
        -o 'colors-dark.bright3={{color11 | strip}}'
        -o 'colors-light.bright3={{color11 | strip}}'
        -o 'colors-dark.bright4={{color12 | strip}}'
        -o 'colors-light.bright4={{color12 | strip}}'
        -o 'colors-dark.bright5={{color13 | strip}}'
        -o 'colors-light.bright5={{color13 | strip}}'
        -o 'colors-dark.bright6={{color14 | strip}}'
        -o 'colors-light.bright6={{color14 | strip}}'
        -o 'colors-dark.bright7={{color15 | strip}}'
        -o 'colors-light.bright7={{color15 | strip}}'
      )
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
      background-color=#{{background | strip}}ff
      text-color=#{{foreground | strip}}ff
      border-color=#{{color3 | strip}}ff
      progress-color=over #{{color3 | strip}}ff
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

  };
}
