{ ... }:

# Fingerprint authentication, and every place it is accepted. Removing this
# file removes fingerprint auth everywhere at once.
{
  services.fprintd.enable = true;
  security.pam.services = {
    ly.fprintAuth = true;
    waylock.fprintAuth = true;
  };
}
