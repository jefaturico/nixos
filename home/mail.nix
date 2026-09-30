# mu4e + mbsync + msmtp, three accounts. Was ~/.mbsyncrc,
# ~/.config/msmtp/config and ~/.config/oama/config.yaml. The mu4e side is in dotfiles/emacs/init.el.
#
# No secret is stored here. Passwords come from `pass`, the university
# token from `oama`. After the install both have to be set up again:
#   pass init <key id>; pass insert mail/personal; pass insert mail/google
#   oama authorize microsoft emiliohurtado@mail.ucv.es --device
{ pkgs, ... }:
let
  # The GPG key that pass and oama encrypt to. This is the key of the Arch
  # install. After generating a new one, put its ID here.
  gpgKey = "012D316E03535D39";

  # Every channel syncs the same way.
  sync = {
    Create = "Near";
    Expunge = "Both";
    SyncState = "*";
  };

  # One mbsync channel that maps a server folder to a local one.
  folder = far: near: {
    farPattern = far;
    nearPattern = near;
    extraConfig = sync;
  };

  inbox = {
    patterns = [ "INBOX" ];
    extraConfig = sync;
  };
in
{
  accounts.email = {
    maildirBasePath = "email";

    accounts = {
      # ---- Migadu ----------------------------------------------------------
      personal = {
        primary = true;
        address = "emilio@hurtadosanchez.com";
        userName = "emilio@hurtadosanchez.com";
        realName = "Emilio Hurtado";
        passwordCommand = "pass show mail/personal";
        folders.inbox = "INBOX";

        imap = {
          host = "imap.migadu.com";
          port = 993;
          tls.enable = true;
        };
        smtp = {
          host = "smtp.migadu.com";
          port = 465;
          tls.enable = true;
        };

        mbsync = {
          enable = true;
          create = "maildir";
          expunge = "both";
          patterns = [ "*" ];
          subFolders = "Verbatim";
          extraConfig.account.AuthMechs = "LOGIN";
        };
        msmtp.enable = true;
        mu.enable = true;
      };

      # ---- University (Microsoft 365, OAuth2 through oama) -------------------
      # If sync fails with an authentication error the login was revoked:
      #   oama authorize microsoft emiliohurtado@mail.ucv.es --device
      # (without --device it gets stuck)
      university = {
        address = "emiliohurtado@mail.ucv.es";
        userName = "emiliohurtado@mail.ucv.es";
        realName = "Emilio Hurtado";
        passwordCommand = "oama access emiliohurtado@mail.ucv.es";
        folders.inbox = "INBOX";

        imap = {
          host = "outlook.office365.com";
          port = 993;
          tls.enable = true;
        };
        smtp = {
          host = "smtp.office365.com";
          port = 587;
          tls = {
            enable = true;
            useStartTls = true;
          };
        };

        mbsync = {
          enable = true;
          subFolders = "Verbatim";
          extraConfig.account.AuthMechs = "XOAUTH2";
          # Server folders are in Spanish, local names in English.
          groups.university.channels = {
            inbox = inbox;
            archive = folder "Archivo" "Archive";
            drafts = folder "Borradores" "Drafts";
            junk = folder "Correo no deseado" "Junk";
            trash = folder "Elementos eliminados" "Trash";
            sent = folder "Elementos enviados" "Sent";
          };
        };
        msmtp = {
          enable = true;
          extraConfig.auth = "xoauth2";
        };
        mu.enable = true;
      };

      # ---- Gmail (app password) ----------------------------------------------
      google = {
        address = "emiliohurtadosr@gmail.com";
        userName = "emiliohurtadosr@gmail.com";
        realName = "Emilio Hurtado";
        passwordCommand = "pass show mail/google";
        folders.inbox = "INBOX";

        imap = {
          host = "imap.gmail.com";
          port = 993;
          tls.enable = true;
        };
        smtp = {
          host = "smtp.gmail.com";
          port = 465;
          tls.enable = true;
        };

        mbsync = {
          enable = true;
          subFolders = "Verbatim";
          extraConfig.account.AuthMechs = "LOGIN";
          groups.google.channels = {
            inbox = inbox;
            sent = folder "[Gmail]/Sent Mail" "Sent";
            drafts = folder "[Gmail]/Drafts" "Drafts";
            trash = folder "[Gmail]/Trash" "Trash";
            junk = folder "[Gmail]/Spam" "Junk";
            archive = folder "[Gmail]/All Mail" "Archive";
          };
        };
        msmtp.enable = true;
        mu.enable = true;
      };
    };
  };

  programs.mbsync = {
    enable = true;
    # XOAUTH2 is a SASL plugin. Arch got it by accident from libkgapi.
    package = pkgs.isync.override { withCyrusSaslXoauth2 = true; };
  };

  programs.msmtp.enable = true;

  programs.mu = {
    enable = true;
    # Has to match the mu4e inside emacs, see home/editors.nix.
    package = pkgs.unstable.mu;
  };

  home.packages = [
    pkgs.pass
    # 0.22 like on Arch, stable has 0.20.
    pkgs.unstable.oama
  ];

  # Was ~/.config/oama/config.yaml
  xdg.configFile."oama/config.yaml".text = ''
    ## oama config, see `oama printenv` for all defaults.
    encryption:
      tag: GPG
      contents: ${gpgKey}

    services:
      microsoft:
        ## Thunderbird's public OAuth client ID. Not a secret, and there is
        ## no client secret.
        client_id: 9e5f94bc-e8a4-4e73-b8be-63364c29d753
        auth_scope: https://outlook.office.com/IMAP.AccessAsUser.All
          https://outlook.office.com/SMTP.Send
          offline_access
  '';

  # ---- GnuPG ---------------------------------------------------------------
  programs.gpg.enable = true;

  # The key is meant to have no passphrase. It only encrypts the two mail
  # passwords and the university token, all of which sit on the encrypted
  # disk, and on Arch the agent kept it unlocked for the whole session
  # anyway. So nothing here caches or presets a passphrase, and mail sync
  # never prompts.
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
  };
}
