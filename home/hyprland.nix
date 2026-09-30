# Hyprland, set up like dwm: one master window, the rest in a stack, tags
# 1-9. With it: hypridle (idle and sleep) and hyprlock (the lock screen).
#
# Colours come from stylix. mako and batsignal are user services and start
# by themselves (home/desktop.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The laptop panel, when it is on.
  laptopPanel = "eDP-1, 2880x1920@60, 1920x0, 2";

  # Hyprland takes no screenshots itself. grim takes the picture, slurp is
  # the area selection; nothing smaller does all three modes. `-l 1` is
  # light PNG compression: 56 ms a shot instead of 136, files 10% bigger.
  # Saved to ~/images/screenshots and copied to the clipboard.
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      grim
      slurp
      jq
      wl-clipboard
      hyprland
    ];
    text = ''
      file="$HOME/images/screenshots/$(date +%Y%m%d%H%M%S).png"
      case "''${1:-area}" in
        area) grim -l 1 -g "$(slurp)" "$file" ;;
        window) grim -l 1 -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$file" ;;
        screen) grim -l 1 -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$file" ;;
      esac
      wl-copy <"$file"
    '';
  };

  # Super+Escape. Ordered from what keeps the session to what ends it.
  powerMenu = pkgs.writeShellApplication {
    name = "power-menu";
    runtimeInputs = with pkgs; [
      fuzzel
      systemd
      hyprland
    ];
    text = ''
      choice=$(printf '%s\n' Lock Suspend Hibernate "Exit session" Reboot "Power off" |
        fuzzel --dmenu --lines 6 --prompt "Power Menu: ")

      case "$choice" in
        Lock) loginctl lock-session ;;
        Suspend) systemctl suspend ;;
        Hibernate) systemctl hibernate ;;
        "Exit session") hyprctl dispatch exit ;;
        Reboot) systemctl reboot ;;
        "Power off") systemctl poweroff ;;
      esac
    '';
  };

  scripts = "/home/jefaturico/.scripts";
in
{
  home.packages = [
    screenshot
    powerMenu
  ];

  # ---- Lock screen ---------------------------------------------------------
  # stylix colours it and sets the theme's wallpaper as the background.
  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true;
    };
  };

  # ---- Idle and sleep --------------------------------------------------------
  # Ten minutes without input suspends. The screen is locked before any
  # sleep, whatever started it (the timeout, the lid, the power menu).
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # `pidof` keeps a second lock screen from starting on top of one.
        lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
        before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
        after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 600;
          on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];
    };
  };

  # ---- Hyprland ------------------------------------------------------------
  wayland.windowManager.hyprland = {
    enable = true;
    # Hyprland itself and its portal come from the system (modules/desktop.nix).
    package = null;
    portalPackage = null;
    # The classic hyprland.conf format. Home Manager would otherwise write
    # the newer Lua one, which needs every bind written as Lua calls.
    configType = "hyprlang";

    settings = {
      monitor = [
        laptopPanel
        "desc:HP Inc. HP E223 3CQ9152Q27, 1920x1080@60, 0x100, 1"
        ", preferred, auto, 1"
      ];

      exec-once = [
        # The theme's wallpaper (modules/theme.nix).
        "swaybg -i ${config.xdg.configHome}/theme/wallpaper"
      ];

      # The lid switch further down only reports changes. This checks the lid
      # at login and again every time the config is reloaded, which every
      # rebuild does. Without it a reload turns the panel back on with the
      # lid shut, and tags end up on a screen nobody can see.
      exec = [
        "grep -q closed /proc/acpi/button/lid/LID0/state && hyprctl keyword monitor 'eDP-1, disable'"
      ];

      input = {
        kb_layout = "us";
        kb_variant = "altgr-intl";
        repeat_rate = 50;
        repeat_delay = 200;
        follow_mouse = 1;
        # The mouse: no acceleration.
        accel_profile = "flat";
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          drag_lock = true;
          disable_while_typing = true;
          scroll_factor = 0.5;
        };
      };

      # The touchpad keeps acceleration.
      device = [
        {
          name = "pixa3854:00-093a:0274-touchpad";
          accel_profile = "adaptive";
          sensitivity = 0.2;
        }
      ];

      cursor = {
        inactive_timeout = 5;
        hide_on_key_press = true;
      };

      general = {
        layout = "master";
        gaps_in = 0;
        gaps_out = 0;
        # A thin line around the focused window, in gruvbox orange. fuzzel and
        # the notifications use the same colour (home/desktop.nix).
        # Unfocused windows get a black one.
        border_size = 2;
        "col.active_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base09})";
        "col.inactive_border" = lib.mkForce "rgb(000000)";
      };

      decoration = {
        rounding = 0;
        shadow.enabled = false;
        blur.enabled = false;
      };

      # Smart borders: no border when the window is alone on its tag, or in
      # monocle, since there is nothing to tell it apart from.
      windowrule = [
        "border_size 0, match:float 0, match:workspace w[tv1]"
        "border_size 0, match:float 0, match:workspace f[1]"
      ];

      animations.enabled = false;

      # X apps (Steam) draw at the screen's real resolution instead of being
      # drawn small and stretched, which is what made them blurry.
      xwayland.force_zero_scaling = true;

      master = {
        # New windows go to the bottom of the stack; the master stays put.
        new_status = "slave";
        new_on_top = false;
        mfact = 0.5;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        # Reloaded explicitly, once, when its config is replaced
        # (home/theme-switch.nix). Watching the file reloaded it half-written
        # during a theme switch, and crashed it.
        disable_autoreload = true;
        force_default_wallpaper = 0;
      };

      "$mod" = "SUPER";

      bind = [
        # Programs.
        "$mod, Return, exec, foot"
        "$mod, X, exec, fuzzel"
        "$mod, W, exec, brave-origin"
        "$mod SHIFT, W, exec, ${scripts}/bookmarks"
        "$mod, BackSpace, exec, emacs"
        "$mod, D, exec, ${scripts}/find-document"
        "$mod, T, exec, ${scripts}/systeminfo"

        # The stack.
        "$mod, O, layoutmsg, cyclenext"
        "$mod SHIFT, O, layoutmsg, cycleprev"
        # Zoom: the focused window becomes the master. On the master itself,
        # it swaps with the top of the stack.
        "$mod, space, layoutmsg, swapwithmaster auto"
        "$mod, mouse_down, layoutmsg, cyclenext"
        "$mod, mouse_up, layoutmsg, cycleprev"

        "$mod, K, killactive"
        "$mod, Escape, exec, power-menu"
        # Next theme (home/theme-switch.nix).
        "$mod SHIFT, T, exec, theme-switch"
        # Monocle: the focused window takes the whole tag, the bar stays.
        "$mod, M, fullscreen, 1"
        "$mod SHIFT, M, fullscreen, 0"
        "$mod SHIFT CTRL, V, togglefloating"

        "$mod, period, focusmonitor, +1"
        "$mod SHIFT, period, movewindow, mon:+1"

        "$mod, S, exec, screenshot area"
        "$mod SHIFT, S, exec, screenshot window"
        "$mod CTRL SHIFT, S, exec, screenshot screen"
      ]
      # Tags: Super+N shows one, Super+Shift+N sends the window there and
      # stays where you are.
      ++ lib.concatMap (n: [
        "$mod, ${toString n}, workspace, ${toString n}"
        "$mod SHIFT, ${toString n}, movetoworkspacesilent, ${toString n}"
      ]) (lib.range 1 9);

      # Held down, these repeat. Resize the master area.
      binde = [
        "$mod, Left, layoutmsg, mfact -0.05"
        "$mod, Right, layoutmsg, mfact +0.05"
      ];

      # These also work on the lock screen.
      bindl = [
        ", XF86AudioRaiseVolume, exec, ${scripts}/volume up"
        ", XF86AudioLowerVolume, exec, ${scripts}/volume down"
        ", XF86AudioMute, exec, ${scripts}/volume mute"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioStop, exec, playerctl stop"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86MonBrightnessUp, exec, brightnessctl --class=backlight set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl --class=backlight set 10%-"

        # The laptop panel follows the lid: off when closed, so windows and
        # the pointer cannot end up on a screen nobody sees.
        ", switch:on:Lid Switch, exec, hyprctl keyword monitor 'eDP-1, disable'"
        ", switch:off:Lid Switch, exec, hyprctl keyword monitor '${laptopPanel}'"
      ];

      # Super and drag: move with the left button, resize with the right.
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
