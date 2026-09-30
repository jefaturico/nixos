# Secrets. They live encrypted in secrets/secrets.yaml, which is safe to
# commit, and are decrypted at login into files only you can read.
#
# One key opens all of them: ~/.config/sops/age/keys.txt. It is not in this
# repo and has to be backed up. Without it the secrets stay locked; nothing
# else on the system depends on it.
#
#   sops secrets/secrets.yaml      edit, in $EDITOR, decrypted while open
#
# A new secret needs a line in that file and a line under `secrets` below.
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  # Public, it only names the key.
  gpgFingerprint = "CB8A1EF7638AF9CE89667CED2382089EE3BE9149";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    defaultSopsFile = ../secrets/secrets.yaml;

    secrets = {
      # Read by mbsync and msmtp, see home/mail.nix.
      mail_personal = { };
      mail_google = { };

      # Loaded into the GPG keyring by the service below.
      gpg_key = { };

      # Put where ~/.ssh/config expects it.
      github_ssh_key = {
        path = "${config.home.homeDirectory}/.ssh/id_coriolis-github";
        mode = "0600";
      };
    };
  };

  # The public half, so `ssh-add -L` and GitHub's settings page can be
  # compared against something.
  home.file.".ssh/id_coriolis-github.pub".text = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP6byMqKtM0Svsu1tefeoUBBxKLOQTw6XIu0+xLNaQIc jefaturico@coriolis
  '';

  # oama encrypts the university login token with this GPG key (home/mail.nix).
  # Loading it from sops means the key is the same on every install, so its
  # ID in the config never changes. Importing a key that is already there
  # does nothing.
  systemd.user.services.gpg-key-import = {
    Unit = {
      Description = "Load the GPG key from sops into the keyring";
      After = [ "sops-nix.service" ];
      Requires = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "gpg-key-import" ''
        ${pkgs.gnupg}/bin/gpg --batch --import ${config.sops.secrets.gpg_key.path}
        echo "${gpgFingerprint}:6:" | ${pkgs.gnupg}/bin/gpg --batch --import-ownertrust
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.packages = [
    pkgs.sops
    pkgs.age
  ];
}
