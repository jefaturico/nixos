;;; jf-ui.el --- Frames, themes, and buffer appearance -*- lexical-binding: t; -*-

(require 'subr-x)
(require 'use-package)

;;; Theme and frame appearance

(blink-cursor-mode t)
(setq make-pointer-invisible t)
(defvar jf/emacs-theme-light 'modus-operandi-deuteranopia)
(defvar jf/emacs-theme-dark 'ef-dream)

(defun jf/current-system-color-scheme ()
  "Return the desktop color scheme preference from dconf."
  (string-trim
   (shell-command-to-string "dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null")))

(defun jf/current-system-theme ()
  "Return the configured Emacs theme for the current system color scheme."
  (if (string= (jf/current-system-color-scheme) "'prefer-light'")
      jf/emacs-theme-light
    jf/emacs-theme-dark))

(defun jf/apply-current-theme ()
  "Apply the configured theme for the current system color scheme."
  (interactive)
  (mapc #'disable-theme (copy-sequence custom-enabled-themes))
  (setq custom-enabled-themes nil)
  (load-theme (jf/current-system-theme) t)
  (when (fboundp 'jf/apply-org-heading-faces)
    (jf/apply-org-heading-faces))
  (when (fboundp 'jf/apply-mode-line-faces)
    (jf/apply-mode-line-faces)))

;;; Buffer display

(setq display-line-numbers-type t)

;; Keep adjacent windows visually distinct when inactive mode lines are hidden.
(setq window-divider-default-places t
      window-divider-default-right-width 1
      window-divider-default-bottom-width 1)
(window-divider-mode 1)

(use-package visual-fill-column
  :commands visual-fill-column-mode)

(defun jf/reading-layout ()
  "Display the current buffer in a centered 80-column reading area."
  (setq-local visual-fill-column-width 80
              visual-fill-column-center-text t)
  (visual-line-mode 1)
  (visual-fill-column-mode 1))

(defun jf/display-line-numbers-unless-large ()
  (unless (> (buffer-size) 100000)
    (display-line-numbers-mode 1)))

(add-hook 'prog-mode-hook #'jf/display-line-numbers-unless-large)
(add-hook 'conf-mode-hook #'jf/display-line-numbers-unless-large)

(setq global-hl-line-sticky-flag nil)

(defun jf/disable-global-hl-line-mode ()
  "Disable global current-line highlighting in the current buffer."
  (setq-local global-hl-line-mode nil))

(dolist (hook '(eureka-mode-hook
                vterm-mode-hook
                minibuffer-setup-hook))
  (add-hook hook #'jf/disable-global-hl-line-mode))

(global-hl-line-mode 1)

(use-package ef-themes
  :demand t
  :config
  (when (fboundp 'jf/apply-current-theme)
    (jf/apply-current-theme)))

;;; Fonts

(defun jf/apply-fonts (&optional frame)
  (set-face-attribute 'default frame :font "JetBrainsMono Nerd Font" :height 160)
  (set-face-attribute 'fixed-pitch frame :font "JetBrainsMono Nerd Font" :height 160)
  (set-face-attribute 'variable-pitch frame :font "JetBrainsMono Nerd Font" :height 160 :weight 'regular))

(add-hook 'after-make-frame-functions #'jf/apply-fonts)
(jf/apply-fonts)

(provide 'jf-ui)
;;; jf-ui.el ends here
