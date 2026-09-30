{ config, username, ... }:
{
  # One password prompt per boot.
  #
  # While the disk asks for its passphrase, that is the prompt, and ly logs
  # in by itself: whoever can type the passphrase already has everything
  # on the disk. Once the TPM unlocks the disk, nothing has been typed by
  # the time ly starts, so ly asks.
  services.displayManager = {
    ly = {
      enable = true;
      settings = {
        hide_key_hints = true;
        hide_keyboard_locks = true;
        hide_version_string = true;
      };
    };
    defaultSession = "niri";
    autoLogin = {
      enable = !config.coriolis.tpmUnlock;
      user = username;
    };
  };

  # swaylock needs a PAM service to be able to check the password at all.
  security.pam.services.swaylock = { };

  # Not carried over from Arch: pam_gnupg, which unlocked the GPG key with
  # the login password. The key has no passphrase now, see home/mail.nix.
}
