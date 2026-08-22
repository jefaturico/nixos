{ ... }:

# Getting from power-on to an authenticated session, and back to one after
# locking. Ly is a console greeter, so it inherits the virtual-console font
# and keymap rather than an X11 or Wayland configuration of its own.
{
  services.displayManager.ly = {
    enable = true;
    settings = {
      background = "0x00000000";
      foreground = "0x00AAAAAA";
      full_color = true;
      animation = "matrix";
      animation_frame_delay = 10;
      colormix_col1 = "0x40FFFFFF";
      colormix_col2 = "0x40AAAAAA";
      colormix_col3 = "0x20000000";
      restore = true;
      session_log = "null";
      hide_version_string = true;
      hide_key_hints = true;
      hide_borders = false;
    };
  };

  # Fingerprint unlock at the greeter and at the lock screen. The lock screen
  # screen's own appearance is configured in `./home.nix`.
  services.fprintd.enable = true;
  programs.hyprlock.enable = true;
  security.pam.services = {
    ly.fprintAuth = true;
    hyprlock.fprintAuth = true;
  };
}
