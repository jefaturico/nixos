;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

(declare-function jf/startup-mark "early-init" (event))
(declare-function jf/startup-log-flush "early-init" ())

(jf/startup-mark "init entry")

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(setq use-package-always-ensure nil)

;; Foundations: persistence, server lifecycle, and baseline editor behavior.
(require 'jf-core)

;; Presentation and interaction.
(require 'jf-ui)
(require 'jf-modeline)
(require 'jf-completion)

;; Editing domains.
(require 'jf-programming)
(require 'jf-org)
(require 'jf-org-roam)

;; Standalone commands and integrations.
(require 'jf-tools)
(require 'jf-network)
(require 'jf-nixos)
(require 'jf-gptel)

;; Global bindings that cross module boundaries.
(keymap-global-set "C-x C-r" #'consult-recent-file)
(keymap-global-set "C-x C-b" #'ibuffer)
(keymap-global-set "C-x k" #'kill-current-buffer)
(keymap-global-set "C-c a" #'org-agenda)
(keymap-global-set "C-c c" #'org-capture)
(keymap-global-set "C-c d" #'jf/org-drill)
(keymap-global-set "C-c t" #'org-timer-set-timer)
(keymap-global-set "C-M-<return>" #'org-insert-subheading)

(add-hook 'emacs-startup-hook
          (lambda () (jf/startup-mark "emacs-startup-hook")))
(run-with-idle-timer
 0 nil
 (lambda ()
   (jf/startup-mark "first idle callback")
   (jf/startup-log-flush)))

(jf/startup-mark "init exit")
