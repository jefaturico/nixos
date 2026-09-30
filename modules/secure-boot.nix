# Secure Boot (lanzaboote) and unlocking the disk from the TPM. Both are on
# in hosts/coriolis/default.nix. A fresh install starts with both off (the
# `coriolis-install` variant in flake.nix) and setup.sh turns them on.
#
# The login follows from the two switches (modules/login.nix):
#
#   tpmUnlock = false   the disk passphrase is the one prompt, ly logs in
#                       by itself
#   tpmUnlock = true    the disk unlocks by itself, the ly password is the
#                       one prompt
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.coriolis;
in
{
  options.coriolis = {
    secureBoot = lib.mkEnableOption "Secure Boot through lanzaboote";
    tpmUnlock = lib.mkEnableOption "unlocking the disk from the TPM";
  };

  config = lib.mkMerge [
    {
      # Creates and enrolls the Secure Boot keys. Needed before the switch
      # is turned on, so always installed.
      environment.systemPackages = [ pkgs.sbctl ];

      assertions = [
        {
          assertion = cfg.tpmUnlock -> cfg.secureBoot;
          message = ''
            coriolis.tpmUnlock needs coriolis.secureBoot. Without Secure
            Boot the TPM hands the disk key to whatever is booted.
          '';
        }
      ];
    }

    (lib.mkIf cfg.secureBoot {
      # lanzaboote installs systemd-boot itself, signed, and takes the
      # timeout, the console mode and the editor setting from
      # modules/boot.nix.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    })

    (lib.mkIf cfg.tpmUnlock {
      # Try the TPM first. If it refuses (firmware update, Secure Boot keys
      # changed) the passphrase prompt comes back, nothing is lost.
      boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];
    })
  ];
}
