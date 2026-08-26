{ pkgs, ... }:

# The screen locker: it draws a solid colour and nothing else, and
# authenticates through PAM.
{
  environment.systemPackages = [ pkgs.waylock ];

  # Waylock ships its own PAM file, which NixOS does not read from the store.
  security.pam.services.waylock = { };
}
