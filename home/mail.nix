# mu4e + mbsync + msmtp, three accounts. The mu4e side is in
# dotfiles/emacs/init.el.
#
# No secret is stored here. The two mail passwords come from sops
# (home/secrets.nix). The university account logs in through `oama`, whose
# token is set up once per install:
#   oama authorize microsoft emiliohurtado@mail.ucv.es --device
{ config, pkgs, ... }:
let
  # The GPG key oama encrypts its token with. The key itself comes from sops
  # (home/secrets.nix), so this ID is the same on every install.
  gpgKey = "2382089EE3BE9149";

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

  universityAddress = "emiliohurtado@mail.ucv.es";
  mbsyncPackage = pkgs.isync.override { withCyrusSaslXoauth2 = true; };

  # What mu4e runs to fetch mail (dotfiles/emacs/init.el). Same as
  # `mbsync -a`, except that when Microsoft has dropped the university
  # login it opens a terminal with the sign-in link and code. Signing in
  # there is all it takes, the mail arrives when the window closes.
  mailSync = pkgs.writeShellApplication {
    name = "mail-sync";
    runtimeInputs = [
      mbsyncPackage
      pkgs.unstable.oama
      pkgs.curl
      pkgs.systemd
      pkgs.libnotify
    ];
    text = ''
      address=${universityAddress}

      # No token, and Microsoft is reachable: the login is gone, not the network.
      if ! oama access "$address" >/dev/null 2>&1 &&
        curl -s --max-time 5 -o /dev/null https://login.microsoftonline.com; then
        # The unit name keeps a second window from opening while one is up.
        if systemd-run --user --quiet --collect --unit=university-mail-login \
          --setenv=PATH="$PATH" \
          ${pkgs.foot}/bin/foot --title "University mail login" sh -c "
            oama authorize microsoft $address --device && mbsync university \\
              || { echo; echo 'That did not work. Press Enter to close.'; read -r _; }
          " 2>/dev/null; then
          notify-send "University mail" "Microsoft wants you to sign in again. The link and the code are in the window that just opened."
        fi
      fi

      exec mbsync -a
    '';
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
        passwordCommand = "cat ${config.sops.secrets.mail_personal.path}";
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
        passwordCommand = "cat ${config.sops.secrets.mail_google.path}";
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
    package = mbsyncPackage;
  };

  programs.msmtp.enable = true;

  programs.mu = {
    enable = true;
    # Has to match the mu4e inside emacs, see home/editors.nix.
    package = pkgs.unstable.mu;
  };

  home.packages = [
    mailSync
    # 0.22, stable has 0.20.
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

  # The key is meant to have no passphrase. It only encrypts the university
  # token, which sits on the encrypted disk. So nothing here caches or
  # presets a passphrase, and mail sync never prompts.
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
  };
}
