;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(initial-buffer-choice t)
 '(menu-bar-mode nil)
 '(package-selected-packages '(gruvbox-theme org-timeblock popper))
 '(scroll-bar-mode nil)
 '(tool-bar-mode nil))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

(use-package gruvbox-theme
  :ensure t
  :config
  (load-theme 'gruvbox-dark-medium t))

(use-package mu4e
  :ensure nil
  :bind ("C-c e" . mu4e)

  :custom
  (mu4e-get-mail-command "mbsync -a")
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

(set-face-attribute 'default nil
                    :font "JetBrains Mono Nerd Font"
                    :height 140)

(keymap-unset global-map "C-x C-c")

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
