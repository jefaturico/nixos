# Theme switching. Super+Shift+T, or `theme-switch [name]`.
#
# The themes are defined in modules/theme.nix. Home Manager builds this
# config once per theme and keeps them all; switching activates another one,
# so every program gets the files stylix writes for that theme and picks
# them up the next time it starts.
#
# What is on screen changes at once, straight from the new theme's files:
#   terminals  new colours as escape codes, sent to every open one
#   Emacs      reloads its theme (home/editors.nix)
#   Hyprland   window border
#   Brave      and other apps that follow the system light/dark setting
#   wallpaper  swapped if the theme has a different one
# Then, in the background, the activation writes every program's files and
# reloads Hyprland and mako once. fuzzel and the lock screen read their
# config each time they open.
#
# The default theme is what the system comes up in. A reboot or a rebuild
# returns to it.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  inherit (osConfig.coriolis) themes defaultTheme;
  others = lib.filterAttrs (name: _: name != defaultTheme) themes;
  stateFile = "${config.home.homeDirectory}/.local/state/theme";
  colors = config.lib.stylix.colors;

  # This generation's theme: the default, or the one a specialisation sets.
  current = lib.findFirst (
    name: themes.${name}.scheme == config.stylix.base16Scheme
  ) defaultTheme (lib.attrNames themes);

  # Escape codes that recolour a running terminal: the 16 colours, then text,
  # background and cursor. The same mapping stylix uses for foot.
  esc = builtins.fromJSON ''"\u001b"'';
  osc = code: color: "${esc}]${code};#${color}${esc}\\";
  terminalColors = with colors; [
    base00 base08 base0B base0A base0D base0E base0C base05
    base03 base08 base0B base0A base0D base0E base0C base07
  ];
  terminalSequence = lib.concatStrings (
    lib.imap0 (i: c: osc "4;${toString i}" c) terminalColors
    ++ [
      (osc "10" colors.base05)
      (osc "11" colors.base00)
      (osc "12" colors.base05)
    ]
  );

  themeSwitch = pkgs.writeShellApplication {
    name = "theme-switch";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      procps
      fuzzel
      mako
      hyprland
      dconf
    ];
    text = ''
      # One switch at a time. A second press while one runs is dropped.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/theme-switch.lock"
      flock -n 9 || exit 0

      current=$(cat ${stateFile} 2>/dev/null || echo ${defaultTheme})
      names=(${lib.concatStringsSep " " (lib.attrNames themes)})

      if [ $# -gt 0 ]; then
        target=$1
      elif [ "''${#names[@]}" -eq 2 ]; then
        # Two themes: flip to the other one.
        for n in "''${names[@]}"; do [ "$n" != "$current" ] && target=$n; done
      else
        target=$(printf '%s\n' "''${names[@]}" | fuzzel --dmenu --prompt "Theme: ") || exit 0
      fi
      [ -n "''${target:-}" ] && [ "$target" != "$current" ] || exit 0

      # /etc/hm-generation is the default theme, with the others inside it
      # (modules/theme.nix).
      if [ "$target" = ${defaultTheme} ]; then
        gen=/etc/hm-generation
      else
        gen=/etc/hm-generation/specialisation/$target
      fi
      [ -x "$gen/activate" ] || { echo "no theme called $target" >&2; exit 1; }

      files=$gen/home-files/.config

      # 1. What is on screen, straight from the new theme's files. All of it
      # together takes a few hundredths of a second.
      for pty in /dev/pts/[0-9]*; do
        [ -O "$pty" ] && cat "$files/theme/terminal" >"$pty" 2>/dev/null || true
      done
      border=$(sed -n 's/^ *col\.active_border *= *//p' "$files/hypr/hyprland.conf" | head -1)
      [ -n "$border" ] && hyprctl keyword general:col.active_border "$border" >/dev/null || true
      ln -sfn "$(readlink -f "$files/theme/base16-stylix-theme.el")" ~/.config/theme/base16-stylix-theme.el
      echo "$target" >${stateFile}
      dconf write /org/gnome/desktop/interface/color-scheme "'$(cat "$files/theme/color-scheme")'"

      # The new wallpaper is drawn before the old one goes, so nothing flashes.
      wallpaper=$(readlink -f "$files/theme/wallpaper")
      if [ "$wallpaper" != "$(readlink -f ~/.config/theme/wallpaper)" ]; then
        old=$(pgrep -x swaybg || true)
        hyprctl dispatch exec "swaybg -i $wallpaper" >/dev/null
        sleep 0.3
        [ -z "$old" ] || echo "$old" | xargs kill 2>/dev/null || true
      fi

      # 2. In the background: every program's files, so each picks up the
      # theme when it next starts, and one Hyprland reload (the onChange
      # below). Holds the lock until done, so switches never overlap.
      (
        "$gen/activate" >/dev/null 2>&1
        makoctl reload >/dev/null 2>&1 || true
      ) &
    '';
  };
in
{
  home.packages = [ themeSwitch ];

  # One specialisation per theme other than the default.
  specialisation = lib.mapAttrs (_: theme: {
    configuration.stylix = {
      base16Scheme = lib.mkForce theme.scheme;
      polarity = lib.mkForce theme.polarity;
      image = lib.mkForce theme.wallpaper;
    };
  }) others;

  xdg.configFile = {
    # What the switch reads from the new theme before activating it.
    "theme/terminal".text = terminalSequence;
    "theme/wallpaper".source = config.stylix.image;
    "theme/color-scheme".text = config.dconf.settings."org/gnome/desktop/interface".color-scheme;

    # Emacs' theme, loaded at runtime so it can change without a restart
    # (home/editors.nix). The same one stylix would build into Emacs.
    "theme/base16-stylix-theme.el".text = with colors.withHashtag; ''
      ;;; base16-stylix-theme.el --- stylix palette -*- lexical-binding: t -*-
      (require 'base16-theme)
      (deftheme base16-stylix)
      (base16-theme-define 'base16-stylix
        '(:base00 "${base00}" :base01 "${base01}" :base02 "${base02}" :base03 "${base03}"
          :base04 "${base04}" :base05 "${base05}" :base06 "${base06}" :base07 "${base07}"
          :base08 "${base08}" :base09 "${base09}" :base0A "${base0A}" :base0B "${base0B}"
          :base0C "${base0C}" :base0D "${base0D}" :base0E "${base0E}" :base0F "${base0F}"))
      (provide-theme 'base16-stylix)
    '';

    # Hyprland watches nothing (misc.disable_autoreload in home/hyprland.nix),
    # so it is reloaded exactly once, after every file is in place.
    "hypr/hyprland.conf".onChange = ''
      for sig in /run/user/$(id -u)/hypr/*/; do
        ${pkgs.hyprland}/bin/hyprctl -i "$(basename "$sig")" reload >/dev/null 2>&1 || true
      done
    '';
  };

  # The theme name, written after everything else is in place. Emacs
  # watches this file.
  home.activation.themeName = lib.hm.dag.entryAfter [ "linkGeneration" "dconfSettings" ] ''
    run mkdir -p ${builtins.dirOf stateFile}
    # Only when it differs: the switch has usually written it already, and
    # rewriting it would make Emacs reload its theme a second time.
    run sh -c '[ "$(cat ${stateFile} 2>/dev/null)" = ${current} ] || echo ${current} > ${stateFile}'
  '';
}
