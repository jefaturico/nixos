;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(initial-buffer-choice t)
 '(menu-bar-mode nil)
 '(package-selected-packages '(org-timeblock))
 '(scroll-bar-mode nil)
 '(tool-bar-mode nil))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

;; The colours and the font are not set here. They come from stylix, see
;; ~/nixos/home/editors.nix and ~/nixos/home/theme-switch.nix.

(use-package mu4e
  :ensure nil
  :bind ("C-c e" . mu4e)

  :custom
  ;; mbsync -a, plus a sign-in window when the university login has expired.
  ;; Defined in home/mail.nix.
  (mu4e-get-mail-command "mail-sync")
  (mu4e-update-interval 300)

  (message-send-mail-function #'message-send-mail-with-sendmail)
  (sendmail-program "msmtp")
  (message-sendmail-extra-arguments '("--read-envelope-from"))
  (message-sendmail-f-is-evil t)
  (user-full-name "Emilio Hurtado")
  (mu4e-context-policy 'pick-first)
  (mu4e-compose-context-policy 'ask-if-none)
  ;; mbsync keeps UIDs in filenames; moved files must be renamed or sync breaks.
  (mu4e-change-filenames-when-moving t)

  :config
  ;; Trashing is a plain move to Trash; otherwise mbsync expunges it for good.
  ;; (A defvar, not a defcustom, so :custom would silently ignore it.)
  (setq mu4e-trash-without-flag t)

  (defun my-mu4e-context (name address sent-behavior)
    (let ((dir (concat "/" name)))
      (make-mu4e-context
       :name name
       :match-func (lambda (msg)
                     (when msg
                       (string-prefix-p (concat dir "/") (mu4e-message-field msg :maildir))))
       :vars `((user-mail-address . ,address)
               (mu4e-sent-folder . ,(concat dir "/Sent"))
               (mu4e-drafts-folder . ,(concat dir "/Drafts"))
               (mu4e-trash-folder . ,(concat dir "/Trash"))
               (mu4e-refile-folder . ,(concat dir "/Archive"))
               (mu4e-sent-messages-behavior . ,sent-behavior)))))

  ;; msmtp picks its account from the From: address (--read-envelope-from).
  ;; Microsoft and Gmail store sent mail themselves, so don't save a second copy.
  (setq mu4e-contexts
        (list (my-mu4e-context "personal" "emilio@hurtadosanchez.com" 'sent)
              (my-mu4e-context "university" "emiliohurtado@mail.ucv.es" 'delete)
              (my-mu4e-context "google" "emiliohurtadosr@gmail.com" 'delete))))

;; ---- Programming: Typst and Python ----------------------------------------
;; A language server per file type (tinymist, pylsp), both installed by
;; home/editors.nix and home/packages.nix. It gives:
;;   errors      underlined as you type. M-n / M-p jump between them,
;;               C-h . shows the full message, M-x flymake-show-buffer-diagnostics lists them.
;;   lookup      M-. go to definition, M-, back, M-? find uses.
;;               Documentation for the thing at point shows in the echo area.
;;   completion  TAB, only when you press it. Nothing pops up by itself.
;; Emacs 31 only shows a language server's errors for files it trusts,
;; because checking a file can mean running code from it. These are the
;; folders with your own work. Add a line for any other place you write
;; code; files elsewhere still get lookup and completion, just no errors.
(setq trusted-content '("~/projects/"
                        "~/documents/"
                        "~/nixos/"))

(use-package typst-ts-mode
  :ensure nil
  :mode "\\.typ\\'")

(use-package eglot
  :ensure nil
  :hook ((python-mode python-ts-mode typst-ts-mode) . eglot-ensure)
  :custom
  ;; Stop the server when its last file is closed.
  (eglot-autoshutdown t)
  ;; No type hints drawn into the code, no reformatting while typing.
  (eglot-ignored-server-capabilities
   '(:inlayHintProvider :documentOnTypeFormattingProvider))
  :config
  (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist"))))

(use-package flymake
  :ensure nil
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)))

;; TAB indents first; if the line is already indented it completes.
(setq tab-always-indent 'complete)
;; File names complete too, in any buffer, after what the language offers.
(autoload 'comint-filename-completion "comint")
(add-hook 'completion-at-point-functions #'comint-filename-completion t)

(keymap-unset global-map "C-x C-c")

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
