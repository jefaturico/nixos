{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  librewolfChrome = import ./librewolf-chrome.nix;

  fnott = pkgs.fnott.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/fnott-placement.patch
      ./patches/fnott-vertical-text-bounds.patch
      ./patches/fnott-centered-min-width.patch
    ];
    postInstall = (old.postInstall or "") + ''
      # The graphical-session service is the sole lifecycle owner. Direct
      # D-Bus activation would bypass fnott-themed and its generated config.
      rm -f "$out/share/dbus-1/services/fnott.service"
    '';
  });

  # Tinty's package expression still reads the deprecated `pkgs.system` alias.
  # Supply the same value explicitly until upstream switches to hostPlatform.
  tinty = inputs.tinty.lib.mkTinty {
    pkgs = pkgs // {
      system = pkgs.stdenv.hostPlatform.system;
    };
  };

  applyDesktopTheme = pkgs.writeShellApplication {
    name = "apply-desktop-theme";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      set -euo pipefail
      : "''${TINTY_THEME_FILE_PATH:?}"

      if [ "''${TINTY_COMMIT:-0}" = 1 ]; then
        systemctl --user restart fnott.service || true
        exit 0
      fi

      theme_color() {
                local base=$1 channel variable value=""
                for channel in R G B; do
                  variable="TINTY_SCHEME_PALETTE_''${base}_HEX_''${channel}"
                  value+="''${!variable}"
                done
                printf '%s' "$value"
              }
              base00=$(theme_color BASE00)
              base01=$(theme_color BASE01)
              base02=$(theme_color BASE02)
              base03=$(theme_color BASE03)
              base05=$(theme_color BASE05)
              base06=$(theme_color BASE06)
      base08=$(theme_color BASE08)
      base0a=$(theme_color BASE0A)
      base0b=$(theme_color BASE0B)
      base0c=$(theme_color BASE0C)
              base0d=$(theme_color BASE0D)
              base0e=$(theme_color BASE0E)

                config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
                state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
                librewolf_chrome="$config_home/librewolf/librewolf/default/chrome"
                mkdir -p "$config_home/foot" "$config_home/fuzzel" "$config_home/fnott" \
                  "$librewolf_chrome" "$state_home/tinted-theming"

                install -m 0600 "$TINTY_THEME_FILE_PATH" "$config_home/foot/tinty-theme.ini"

                temporary=$(mktemp "$config_home/fuzzel/.tinty.XXXXXX")
                cat > "$temporary" <<EOF
              [main]
              icons-enabled=no
              namespace=fuzzel
              prompt="λ "
              vertical-pad=12
              inner-pad=8

              [colors]
            background=''${base00}b3
            text=''${base05}ff
            prompt=''${base0d}ff
            placeholder=''${base03}ff
            input=''${base05}ff
            match=''${base0c}ff
            selection=''${base02}f2
            selection-text=''${base06}ff
            selection-match=''${base0a}ff
            counter=''${base0e}ff
            border=''${base00}b3

              [border]
              width=0
              radius=15
              selection-radius=0
      EOF
                mv -f "$temporary" "$config_home/fuzzel/tinty.ini"

                temporary=$(mktemp "$config_home/fnott/.tinty.XXXXXX")
                cat > "$temporary" <<EOF
              anchor=top-center
              center-app-names=volume,brightness,movement-break
              center-min-width=720
              max-width=720
              edge-margin-vertical=20
              edge-margin-horizontal=20
              notification-margin=10
              selection-helper=fuzzel --dmenu0 --prompt=Action:
              selection-helper-uses-null-separator=yes
              max-icon-size=32
              layer=overlay
            background=''${base00}b3
            border-color=''${base00}b3
              border-radius=30
              border-size=0
              padding-vertical=24
              padding-horizontal=24
              title-font=JetBrainsMono Nerd Font:size=12
            title-color=''${base03}ff
              title-format=
              summary-font=JetBrainsMono Nerd Font:weight=bold:size=12
            summary-color=''${base05}ff
              body-font=JetBrainsMono Nerd Font:size=12
            body-color=''${base05}ff
            progress-color=''${base0d}66
              progress-style=background
              default-timeout=5

              [low]
            title-color=''${base03}ff
            summary-color=''${base03}ff
            body-color=''${base03}ff

              [critical]
            background=''${base01}e6
            border-color=''${base08}ff
              default-timeout=0
            title-color=''${base08}ff
            summary-color=''${base08}ff
            body-color=''${base05}ff
      EOF
              mv -f "$temporary" "$config_home/fnott/tinty.ini"

              temporary=$(mktemp "$librewolf_chrome/.tinty.XXXXXX")
              cat > "$temporary" <<EOF
      ${librewolfChrome}
      EOF
              mv -f "$temporary" "$librewolf_chrome/tinty.css"

      terminal_colors=(
        "$base00" "$base08" "$base0b" "$base0a"
        "$base0d" "$base0e" "$base0c" "$base05"
        "$base03" "$base08" "$base0b" "$base0a"
        "$base0d" "$base0e" "$base0c" "$base06"
      )
      sequence=$'\033]10;#'"$base05"$'\033\\'
      sequence+=$'\033]11;#'"$base00"$'\033\\'
      sequence+=$'\033]12;#'"$base05"$'\033\\'
      for index in {0..15}; do
        sequence+=$'\033]4;'"$index"';#'"''${terminal_colors[$index]}"$'\033\\'
      done

      # Foot applies OSC palette changes immediately. Restrict the broadcast
      # to this user's writable pseudoterminals and never touch virtual
      # consoles; the client wrapper supplies the same palette to future
      # windows connected to the server.
      for tty in /dev/pts/[0-9]*; do
        if [ -c "$tty" ] && [ -O "$tty" ] && [ -w "$tty" ]; then
          printf '%s' "$sequence" > "$tty" 2>/dev/null || true
        fi
      done

      if [ "''${TINTY_PREVIEW:-0}" != 1 ]; then
        systemctl --user restart fnott.service || true
      fi
    '';
  };

  applyNeovimTheme = pkgs.writeShellApplication {
    name = "apply-neovim-theme";
    runtimeInputs = with pkgs; [
      coreutils
      neovim
      procps
    ];
    text = ''
      set -euo pipefail
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tinted-theming"
      mkdir -p "$config_dir/colors" "$state_dir"
      theme_file=$(basename "$TINTY_THEME_FILE_PATH")
      theme_name="''${theme_file%.vim}"
      install -m 0600 "$TINTY_THEME_FILE_PATH" "$config_dir/colors/$theme_file"
      rm -f "$config_dir/tinty.lua"
      temporary=$(mktemp "$state_dir/.neovim-theme.XXXXXX")
      trap 'rm -f "$temporary"' EXIT
      printf '%s\n' "$theme_name" > "$temporary"
      mv -f "$temporary" "$state_dir/neovim-theme"
      trap - EXIT

      reloaded=0
      runtime_dir="''${XDG_RUNTIME_DIR:-}"
      if [ -n "$runtime_dir" ]; then
        shopt -s nullglob
        for server in "$runtime_dir"/jf-nvim-*.sock; do
          [ -S "$server" ] || continue
          if nvim --server "$server" --remote-expr \
            'execute("doautocmd <nomodeline> User TintyThemeChanged")' \
            >/dev/null 2>&1; then
            reloaded=1
          fi
        done
      fi
      if [ "$reloaded" -eq 0 ]; then
        pkill -USR1 -x nvim >/dev/null 2>&1 || true
      fi
    '';
  };

  initialWbg = pkgs.writeText "wbg-initial" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    wallpaper_dir="$HOME/images/wallpapers"
    [ -d "$wallpaper_dir" ] || exit 0
    mapfile -d "" -t wallpapers < <(
      ${pkgs.findutils}/bin/find "$wallpaper_dir" -maxdepth 1 -type f -print0 \
        | ${pkgs.coreutils}/bin/shuf -z
    )
    [ "''${#wallpapers[@]}" -gt 0 ] || exit 0
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/wbg"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
    temporary_link=$(${pkgs.coreutils}/bin/mktemp "$state_dir/.current.XXXXXX")
    ${pkgs.coreutils}/bin/rm -f "$temporary_link"
    ${pkgs.coreutils}/bin/ln -s -- "''${wallpapers[0]}" "$temporary_link"
    ${pkgs.coreutils}/bin/mv -Tf -- "$temporary_link" "$state_dir/current"
    exec ${pkgs.wbg}/bin/wbg "''${wallpapers[0]}"
  '';
  wallpaperSwitcher = pkgs.writeShellApplication {
    name = "wallpaper-switcher";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      systemd
      tinty
      util-linux
    ];
    text = ''
      set -euo pipefail
      runtime_dir="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
      exec 9>"$runtime_dir/wallpaper-switcher.lock"
      flock --nonblock 9 || exit 0

      wallpaper_dir="$HOME/images/wallpapers"
      [ -d "$wallpaper_dir" ] || { printf 'Wallpaper directory does not exist: %s\n' "$wallpaper_dir" >&2; exit 1; }
      mapfile -d "" -t wallpapers < <(find "$wallpaper_dir" -maxdepth 1 -type f -print0 | sort -z)
      [ "''${#wallpapers[@]}" -gt 0 ] || { printf 'No wallpapers found in: %s\n' "$wallpaper_dir" >&2; exit 1; }
      choice=$({ printf '%s\n' "Random"; printf '%s\n' "''${wallpapers[@]##*/}"; } \
        | "$HOME/.local/bin/fuzzel" --dmenu --prompt="Wallpaper: " --lines=20 --minimal-lines) || exit 0
      if [ "$choice" = "Random" ]; then
        mapfile -d "" -t random_wallpaper < <(printf '%s\0' "''${wallpapers[@]}" | shuf -z -n 1)
        wallpaper="''${random_wallpaper[0]}"
      else
        wallpaper="$wallpaper_dir/$choice"
        [ -f "$wallpaper" ] || exit 0
      fi
      temporary=$(mktemp "$HOME/.wbg.XXXXXX")
      trap 'rm -f "$temporary"' EXIT
      { printf '#!%s\n' '${pkgs.bash}/bin/bash'; printf 'exec %q %q\n' '${pkgs.wbg}/bin/wbg' "$wallpaper"; } > "$temporary"
      chmod 0700 "$temporary"
      mv "$temporary" "$HOME/.wbg"
      trap - EXIT
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/wbg"
      mkdir -p "$state_dir"
      temporary_link=$(mktemp "$state_dir/.current.XXXXXX")
      rm -f "$temporary_link"
      ln -s -- "$wallpaper" "$temporary_link"
      mv -Tf -- "$temporary_link" "$state_dir/current"
      systemctl --user reset-failed wallpaper.service
      systemctl --user restart wallpaper.service

      associations="''${XDG_STATE_HOME:-$HOME/.local/state}/tinted-theming/wallpapers.tsv"
      theme=""
      if [ -r "$associations" ]; then
        theme=$(awk -F '\t' -v wallpaper="''${wallpaper##*/}" '$1 == wallpaper { selected = $2 } END { print selected }' "$associations")
      fi
      if [ -z "$theme" ]; then
        recommendations=$(${themeRanker}/bin/theme-ranker "$wallpaper" || true)
        theme="''${recommendations%%$'\n'*}"
      fi
      if [ -n "$theme" ]; then
        tinty apply "$theme" --quiet
      fi
    '';
  };

  themePreview = pkgs.writeShellApplication {
    name = "theme-preview";
    runtimeInputs = [ tinty ];
    text = ''
      set -euo pipefail
      [ "$#" -eq 1 ] || exit 2
      TINTY_PREVIEW=1 tinty apply "$1" --quiet
    '';
  };

  themeRanker = pkgs.writeTextFile {
    name = "theme-ranker";
    destination = "/bin/theme-ranker";
    executable = true;
    text = ''
      #!${pkgs.python3}/bin/python3
      import json
      import math
      import subprocess
      import sys
      from collections import defaultdict

      SAMPLE_SIZE = 64


      def srgb_channel(value):
          value /= 255.0
          return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


      def rgb_to_oklab(rgb):
          red, green, blue = (srgb_channel(value) for value in rgb)
          l_value = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue
          m_value = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue
          s_value = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue
          l_root = math.copysign(abs(l_value) ** (1.0 / 3.0), l_value)
          m_root = math.copysign(abs(m_value) ** (1.0 / 3.0), m_value)
          s_root = math.copysign(abs(s_value) ** (1.0 / 3.0), s_value)
          return (
              0.2104542553 * l_root + 0.7936177850 * m_root - 0.0040720468 * s_root,
              1.9779984951 * l_root - 2.4285922050 * m_root + 0.4505937099 * s_root,
              0.0259040371 * l_root + 0.7827717662 * m_root - 0.8086757660 * s_root,
          )


      def lab_chroma(lab):
          return math.hypot(lab[1], lab[2])


      def lab_hue(lab):
          return math.atan2(lab[2], lab[1]) % (2.0 * math.pi)


      def weighted_average(entries):
          total = sum(weight for _, weight in entries) or 1.0
          return tuple(sum(lab[index] * weight for lab, weight in entries) / total for index in range(3))


      def lab_distance(first, second, lightness_weight=1.0):
          return math.sqrt(
              (lightness_weight * (first[0] - second[0])) ** 2
              + (first[1] - second[1]) ** 2
              + (first[2] - second[2]) ** 2
          )


      def accent_distance(first, second):
          first_chroma = lab_chroma(first)
          second_chroma = lab_chroma(second)
          if min(first_chroma, second_chroma) < 0.018:
              hue_term = 0.65
          else:
              hue_delta = abs(lab_hue(first) - lab_hue(second))
              hue_term = min(hue_delta, 2.0 * math.pi - hue_delta) / math.pi
          chroma_term = abs(min(first_chroma, 0.22) - min(second_chroma, 0.22)) / 0.22
          lightness_term = abs(first[0] - second[0])
          return 0.68 * hue_term + 0.20 * chroma_term + 0.12 * lightness_term


      def sample_wallpaper(path):
          raw = subprocess.check_output([
              "${pkgs.imagemagick}/bin/magick",
              path,
              "-auto-orient",
              "-resize", f"{SAMPLE_SIZE}x{SAMPLE_SIZE}!",
              "-alpha", "off",
              "-colorspace", "sRGB",
              "-depth", "8",
              "rgb:-",
          ])
          expected = SAMPLE_SIZE * SAMPLE_SIZE * 3
          if len(raw) != expected:
              raise RuntimeError(f"ImageMagick returned {len(raw)} bytes instead of {expected}")
          return [rgb_to_oklab(raw[offset:offset + 3]) for offset in range(0, len(raw), 3)]


      def wallpaper_profile(pixels):
          ordered = sorted(pixels, key=lambda color: color[0])
          shadow_count = max(1, len(ordered) // 4)
          highlight_count = max(1, len(ordered) // 5)
          shadow = weighted_average([(color, 1.0) for color in ordered[:shadow_count]])
          highlight = weighted_average([(color, 1.0) for color in ordered[-highlight_count:]])

          highlight_chroma = lab_chroma(highlight)
          if highlight_chroma > 0.04:
              scale = 0.04 / highlight_chroma
          else:
              scale = 1.0
          foreground_target = (0.88, highlight[1] * scale, highlight[2] * scale)

          buckets = defaultdict(lambda: [0, 0.0, 0.0, 0.0])
          for pixel in pixels:
              key = tuple(int(round(component * 16.0)) for component in pixel)
              bucket = buckets[key]
              bucket[0] += 1
              for index in range(3):
                  bucket[index + 1] += pixel[index]

          candidates = []
          for count, l_sum, a_sum, b_sum in buckets.values():
              color = (l_sum / count, a_sum / count, b_sum / count)
              chroma = lab_chroma(color)
              if 0.16 <= color[0] <= 0.92 and chroma >= 0.025:
                  candidates.append((color, count * (0.35 + chroma)))
          candidates.sort(key=lambda entry: entry[1], reverse=True)

          accents = []
          for color, weight in candidates:
              if all(lab_distance(color, selected, 0.5) >= 0.075 for selected, _ in accents):
                  accents.append((color, weight))
              if len(accents) == 7:
                  break
          if not accents:
              accents = [(weighted_average([(color, 1.0) for color in pixels]), 1.0)]

          total_weight = sum(weight for _, weight in accents)
          accents = [(color, weight / total_weight) for color, weight in accents]
          return shadow, foreground_target, accents


      def score_theme(theme, shadow, foreground_target, wallpaper_accents):
          palette = theme["palette"]
          background = rgb_to_oklab(palette["base00"]["rgb"])
          foreground = rgb_to_oklab(palette["base05"]["rgb"])
          if background[0] >= 0.40:
              return None

          theme_accents = [rgb_to_oklab(palette[f"base0{suffix}"]["rgb"])
                           for suffix in "89ABCDEF"]

          target_background = (min(shadow[0], 0.22), shadow[1] * 0.55, shadow[2] * 0.55)
          background_cost = lab_distance(background, target_background, 1.35)
          foreground_cost = lab_distance(foreground, foreground_target, 0.9)

          wallpaper_coverage = sum(
              weight * min(accent_distance(color, accent) for accent in theme_accents)
              for color, weight in wallpaper_accents
          )
          theme_coherence = sum(
              min(accent_distance(accent, color) for color, _ in wallpaper_accents)
              for accent in theme_accents
          ) / len(theme_accents)
          accent_cost = 0.68 * wallpaper_coverage + 0.32 * theme_coherence

          # Accent affinity is the primary aesthetic signal. Background and
          # foreground tint break ties while retaining a consistently dark UI.
          return 0.66 * accent_cost + 0.19 * background_cost + 0.15 * foreground_cost


      def main():
          if len(sys.argv) != 2:
              raise SystemExit("usage: theme-ranker WALLPAPER")
          pixels = sample_wallpaper(sys.argv[1])
          shadow, foreground_target, accents = wallpaper_profile(pixels)
          themes = json.loads(subprocess.check_output(["${tinty}/bin/tinty", "list", "--json"]))
          ranked = []
          for theme in themes:
              if theme.get("system") != "base16":
                  continue
              score = score_theme(theme, shadow, foreground_target, accents)
              if score is not None:
                  ranked.append((score, theme["id"]))
          ranked.sort(key=lambda entry: (entry[0], entry[1]))
          for _, theme_id in ranked:
              print(theme_id)


      if __name__ == "__main__":
          main()
    '';
  };

  themePicker = pkgs.writeShellApplication {
    name = "theme-picker";
    runtimeInputs = with pkgs; [
      coreutils
      fzf
      gawk
      tinty
    ];
    text = ''
      set -euo pipefail
      wallpaper_link="''${XDG_STATE_HOME:-$HOME/.local/state}/wbg/current"
      [ -L "$wallpaper_link" ] || { printf 'No current wallpaper is recorded.\n' >&2; exit 1; }
      wallpaper=$(basename "$(readlink -f "$wallpaper_link")")
      wallpaper_path=$(readlink -f "$wallpaper_link")
      if ! themes=$(${themeRanker}/bin/theme-ranker "$wallpaper_path"); then
        themes=$(tinty list | awk '/^base16-/')
      fi
      original=$(tinty current)
      restore=1
      restore_original() {
        if [ "$restore" -eq 1 ] && [ -n "$original" ]; then
          tinty apply "$original" --quiet || true
        fi
      }
      trap restore_original EXIT

      theme=$(
        printf '%s\n' "$themes" \
          | fzf \
              --prompt="Theme for $wallpaper: " \
              --layout=reverse \
              --border=rounded \
              --info=inline \
              --bind='focus:execute-silent(${themePreview}/bin/theme-preview {})'
      ) || exit 0
      [ -n "$theme" ] || exit 0
      TINTY_COMMIT=1 tinty apply "$theme" --quiet

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tinted-theming"
      associations="$state_dir/wallpapers.tsv"
      mkdir -p "$state_dir"
      temporary=$(mktemp "$state_dir/.wallpapers.XXXXXX")
      trap 'rm -f "$temporary"' EXIT
      if [ -r "$associations" ]; then
        awk -F '\t' -v wallpaper="$wallpaper" '$1 != wallpaper' "$associations" > "$temporary"
      fi
      printf '%s\t%s\n' "$wallpaper" "$theme" >> "$temporary"
      mv -f "$temporary" "$associations"
      trap - EXIT
      restore=0
    '';
  };

  themeSwitcher = pkgs.writeShellApplication {
    name = "theme-switcher";
    text = ''
      exec "$HOME/.local/bin/footclient" \
        --app-id=theme-preview \
        --title="Theme Preview" \
        --window-size-chars=76x24 \
        ${themePicker}/bin/theme-picker
    '';
  };
in
{
  home.packages = [
    applyDesktopTheme
    applyNeovimTheme
    fnott
    tinty
    themeSwitcher
    wallpaperSwitcher
  ];

  xdg.configFile."tinted-theming/tinty/config.toml".text = ''
    shell = "${pkgs.bash}/bin/bash -c '{}'"
    default-scheme = "base16-kanagawa-dragon"

    [[items]]
    name = "tinted-terminal"
    path = "${inputs.tinted-terminal}"
    themes-dir = "themes/foot"
    supported-systems = ["base16", "base24"]
    hook = "${applyDesktopTheme}/bin/apply-desktop-theme"

    [[items]]
    name = "tinted-vim"
    path = "${inputs.tinted-vim}"
    themes-dir = "colors"
    supported-systems = ["base16"]
    hook = "${applyNeovimTheme}/bin/apply-neovim-theme"
  '';

  home.activation.initializeWbg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.wbg" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0700 ${initialWbg} "$HOME/.wbg"
    fi
  '';

  home.activation.initializeTinty = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    tinty_data="''${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$tinty_data/repos"
    link_tinty_repository() {
      name=$1
      source=$2
      target="$tinty_data/repos/$name"
      if [ -L "$target" ] && [ "$(${pkgs.coreutils}/bin/readlink -f "$target")" = "$source" ]; then
        return
      fi
      if [ -e "$target" ] || [ -L "$target" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$target" "$target.pre-nix"
      fi
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -s "$source" "$target"
    }
    link_tinty_repository schemes ${inputs.tinted-schemes}
    link_tinty_repository tinted-terminal ${inputs.tinted-terminal}
    link_tinty_repository tinted-vim ${inputs.tinted-vim}
    $DRY_RUN_CMD ${tinty}/bin/tinty init
    current_theme=$(${tinty}/bin/tinty current)
    if [ -n "$current_theme" ]; then
      $DRY_RUN_CMD ${tinty}/bin/tinty apply "$current_theme" --quiet
    fi
  '';

  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Wayland session wallpaper";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "%h/.wbg";
      Restart = "on-failure";
      RestartSec = "250ms";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.foot.settings.main.include = "~/.config/foot/tinty-theme.ini";
  programs.foot.settings."colors-dark" = {
    alpha = 0.7;
    alpha-mode = "matching";
    blur = true;
  };

  home.file.".local/bin/fuzzel" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      exec ${pkgs.fuzzel}/bin/fuzzel --config="''${XDG_CONFIG_HOME:-$HOME/.config}/fuzzel/tinty.ini" "$@"
    '';
  };

  home.file.".local/bin/fnott-themed" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      export PATH="$HOME/.local/bin:$PATH"
      exec ${fnott}/bin/fnott --config="''${XDG_CONFIG_HOME:-$HOME/.config}/fnott/tinty.ini" "$@"
    '';
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
}
