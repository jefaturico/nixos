{ pkgs, ... }:

# Getting from power-on to an authenticated session, and back after locking.
# Ly is a console greeter, so it inherits the virtual-console font and keymap
# rather than carrying a display configuration of its own. Waylock is the
# screen locker: it draws a solid colour and nothing else, and authenticates
# through PAM.
{
  services.displayManager.ly = {
    enable = true;
    # ly's compiled-in default drops this in $HOME's root; upstream's own
    # example config puts it under XDG state instead.
    settings.session_log = ".local/state/ly-session.log";
  };

  environment.systemPackages = [ pkgs.waylock ];

  # Waylock ships its own PAM file, which NixOS does not read from the store.
  services.fprintd.enable = true;
  security.pam.services = {
    ly.fprintAuth = true;
    waylock.fprintAuth = true;
  };
}
