{ ... }:

# The lock screen. PAM and fingerprint authentication for it are configured
# system-wide in `modules/nixos/desktop/login.nix`.
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
      };

      auth = {
        fingerprint = {
          enabled = true;
          ready_message = "(Scan fingerprint to unlock)";
          present_message = "Scanning fingerprint...";
        };
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      label = [
        {
          text = "$TIME";
          color = "rgba(240, 240, 240, 0.95)";
          font_size = 96;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 80";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 4;
          shadow_color = "rgba(0, 0, 0, 0.8)";
        }
        {
          text = ''cmd[update:60000] date +"%A, %B %d"'';
          color = "rgba(200, 200, 200, 0.85)";
          font_size = 20;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -10";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(0, 0, 0, 0.8)";
        }
      ];

      input-field = [
        {
          size = "280, 48";
          outline_thickness = 2;
          dots_size = 0.25;
          dots_spacing = 0.25;
          dots_center = true;
          dots_rounding = -1;
          outer_color = "rgba(255, 255, 255, 0.15)";
          inner_color = "rgba(18, 22, 28, 0.65)";
          font_color = "rgb(240, 240, 240)";
          font_family = "JetBrainsMono Nerd Font";
          fade_on_empty = true;
          fade_timeout = 1000;
          placeholder_text = ''<span foreground="##888888"><i>Password</i></span>'';
          hide_input = false;
          rounding = -1;
          check_color = "rgba(204, 136, 34, 0.8)";
          fail_color = "rgba(204, 34, 34, 0.8)";
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          fail_transition = 300;
          position = "0, -100";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(0, 0, 0, 0.8)";
        }
      ];
    };
  };
}
