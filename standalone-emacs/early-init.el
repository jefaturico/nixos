;;; early-init.el -*- lexical-binding: t; -*-

(defvar native-comp-async-report-warnings-errors)

(setq package-enable-at-startup nil
      frame-inhibit-implied-resize t)

(defvar jf/orig-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

(setq gc-cons-threshold (* 128 1024 1024)
      gc-cons-percentage 0.6)

(setq native-comp-async-report-warnings-errors 'silent)

(defvar jf/emacs-cache-directory
  (expand-file-name "emacs/" (or (getenv "XDG_CACHE_HOME")
                                 (expand-file-name ".cache" "~"))))

(let ((eln-cache (expand-file-name "eln-cache/" jf/emacs-cache-directory)))
  (make-directory eln-cache t)
  (startup-redirect-eln-cache eln-cache))

(setq inhibit-startup-screen t
      inhibit-startup-message t)

(defconst jf/early-background "#000000"
  "Initial frame background used before the real theme loads.")

(defconst jf/early-foreground "#ffffff"
  "Initial frame foreground used before the real theme loads.")

;; Restore file-name-handler after startup, but let gcmh handle GC
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist jf/orig-file-name-handler-alist)))

;; Prevent UI flash
(let ((jf/early-frame-parameters
       '((internal-border-width . 0)
         (menu-bar-lines . 0)
         (tool-bar-lines . 0)
         (vertical-scroll-bars . nil)
         (undecorated . t)))
      (jf/early-color-parameters
       `((background-color . ,jf/early-background)
         (foreground-color . ,jf/early-foreground)
         (cursor-color . ,jf/early-foreground)
         (mouse-color . ,jf/early-foreground)
         (border-color . ,jf/early-background))))
  (setq default-frame-alist
        (append jf/early-frame-parameters default-frame-alist)
        initial-frame-alist
        (append jf/early-color-parameters
                jf/early-frame-parameters
                initial-frame-alist)))

(fringe-mode 0)
(setq-default mode-line-format nil)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)
