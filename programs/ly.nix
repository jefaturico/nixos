{ ... }:

# The console greeter: getting from power-on to an authenticated session. Ly
# inherits the virtual-console font and keymap rather than carrying a display
# configuration of its own.
{
  services.displayManager.ly = {
    enable = true;
    # ly's compiled-in default drops this in $HOME's root; upstream's own
    # example config puts it under XDG state instead.
    settings.session_log = ".local/state/ly-session.log";
  };
}
