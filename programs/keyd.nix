{ ... }:

# Key remapping below every compositor and console, so the greeter, the
# virtual consoles, and the graphical session agree.
{
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
