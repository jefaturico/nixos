{ ... }:

# The keyboard layout, held once for everything that asks.
{
  # Consulted through org.freedesktop.locale1 by clients that do not carry
  # their own keymap. Niri sets the same layout in its own configuration.
  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };
}
