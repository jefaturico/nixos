{ ... }:

# Keyboard behaviour that must hold before any compositor starts, so the
# greeter, the virtual consoles, and the graphical session agree.
{
  # Consulted through org.freedesktop.locale1 by clients that do not carry
  # their own keymap. Niri sets the same layout in its own configuration.
  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        capslock = "overload(control, esc)";
        menu = "leftmeta";
      };
    };
  };

  # keyd re-emits events through a virtual device. Without this quirk libinput
  # classifies it as external and disables internal-keyboard behaviour such as
  # disable-while-typing.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd Virtual Keyboard]
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';
}
