;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; Prefer packages already exposed by Nix or the system.  Download only
;; libraries that are genuinely absent from `load-path'.
(require 'jf-package-bootstrap)
(jf/ensure-required-packages)
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
