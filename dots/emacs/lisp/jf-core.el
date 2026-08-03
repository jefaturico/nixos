;;; jf-core.el --- Core Emacs behavior and persistence -*- lexical-binding: t; -*-

(require 'seq)
(require 'server)
(require 'subr-x)
(require 'use-package)

;;; Editor defaults

(setq undo-limit (* 10 1024 1024)        ;; 10MB
      undo-strong-limit (* 15 1024 1024) ;; 15MB
      undo-outer-limit (* 50 1024 1024)) ;; 50MB

(setq custom-file null-device)

;; Some laptop firmware emits this input event when the lid opens.
(keymap-global-set "<WakeUp>" #'ignore)

;;; Session safety

(unless (server-running-p)
  (server-start))

(defvar jf/shutdown-inhibitor-process nil
  "Process holding a shutdown inhibitor while Emacs has unsaved buffers.")

(defun jf/start-inhibitor (name what who why)
  "Start a systemd inhibitor process tied to this Emacs process.

NAME identifies the Emacs process.  WHAT, WHO and WHY are passed to
systemd-inhibit.  The inhibited command waits for EOF on a pipe owned by
Emacs, so the lock is also released if Emacs exits unexpectedly."
  (when-let ((systemd-inhibit (executable-find "systemd-inhibit")))
    (let ((process-connection-type nil))
      (start-process
       name nil systemd-inhibit
       (concat "--what=" what)
       "--mode=block"
       (concat "--who=" who)
       (concat "--why=" why)
       "sh" "-c" "read -r _"))))

(defun jf/save-worthy-buffer-p (&optional buffer)
  "Return non-nil when modified BUFFER should block shutdown."
  (let ((buffer (or buffer (current-buffer))))
    (and (buffer-live-p buffer)
         (buffer-modified-p buffer)
         (not (string-prefix-p " " (buffer-name buffer)))
         (with-current-buffer buffer
           (or buffer-file-name
               buffer-offer-save
               (string= (buffer-name buffer) "*scratch*"))))))

(defun jf/modified-user-buffers ()
  "Return modified buffers worth protecting from shutdown."
  (seq-filter #'jf/save-worthy-buffer-p (buffer-list)))

(defun jf/update-shutdown-inhibitor (&rest _)
  "Hold a shutdown inhibitor while any user-visible buffer is modified."
  (if (jf/modified-user-buffers)
      (unless (process-live-p jf/shutdown-inhibitor-process)
        (when-let ((process
                    (jf/start-inhibitor
                     "emacs-shutdown-inhibitor"
                     "shutdown:handle-power-key"
                     "Emacs"
                     "Warning: Unsaved buffers detected in Emacs!")))
          (setq jf/shutdown-inhibitor-process process)
          (set-process-query-on-exit-flag
           jf/shutdown-inhibitor-process nil)))
    (jf/release-shutdown-inhibitor)))

(defun jf/release-shutdown-inhibitor ()
  "Release Emacs' shutdown inhibitor, if active."
  (when (process-live-p jf/shutdown-inhibitor-process)
    (delete-process jf/shutdown-inhibitor-process)
    (setq jf/shutdown-inhibitor-process nil)))

(add-hook 'first-change-hook #'jf/update-shutdown-inhibitor)
(add-hook 'after-save-hook #'jf/update-shutdown-inhibitor)
(add-hook 'after-revert-hook #'jf/update-shutdown-inhibitor)
(add-hook 'kill-buffer-hook #'jf/update-shutdown-inhibitor)
(add-hook 'kill-emacs-hook #'jf/release-shutdown-inhibitor)
(run-at-time nil 5 #'jf/update-shutdown-inhibitor)

;;; Persistent files

(defvar jf/emacs-cache-directory
  (expand-file-name "emacs/" (or (getenv "XDG_CACHE_HOME")
                                 (expand-file-name ".cache" "~"))))

(defvar jf/emacs-state-directory
  (expand-file-name "emacs/" (or (getenv "XDG_STATE_HOME")
                                 (expand-file-name ".local/state" "~"))))

(dolist (dir '("backups" "auto-save" "auto-save-list" "eln-cache" "locks" "transient" "url"))
  (make-directory (expand-file-name dir jf/emacs-cache-directory) t))

(dolist (dir '("recentf" "savehist" "tramp"))
  (make-directory (expand-file-name dir jf/emacs-state-directory) t))

(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups/" jf/emacs-cache-directory)))
      auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" jf/emacs-cache-directory) t))
      lock-file-name-transforms
      `((".*" ,(expand-file-name "locks/" jf/emacs-cache-directory) t))
      auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" jf/emacs-cache-directory)
      recentf-save-file
      (expand-file-name "recentf/recentf" jf/emacs-state-directory)
      savehist-file
      (expand-file-name "savehist/history" jf/emacs-state-directory)
      tramp-persistency-file-name
      (expand-file-name "tramp/tramp" jf/emacs-state-directory)
      url-cookie-file
      (expand-file-name "url/cookies" jf/emacs-cache-directory)
      transient-history-file
      (expand-file-name "transient/history.el" jf/emacs-cache-directory)
      transient-levels-file
      (expand-file-name "transient/levels.el" jf/emacs-cache-directory)
      transient-values-file
      (expand-file-name "transient/values.el" jf/emacs-cache-directory))

;;; Editing behavior

(setq-default indent-tabs-mode nil
              tab-width 4
              standard-indent 4
              truncate-lines t)

(setq use-short-answers t
      vc-follow-symlinks t
      calendar-week-start-day 1
      large-file-warning-threshold (* 200 1024 1024)
      read-process-output-max (* 1024 1024)
      ring-bell-function 'ignore
      browse-url-browser-function 'eww-browse-url
      browse-url-secondary-browser-function 'browse-url-generic
      browse-url-generic-program "brave"
      eww-search-prefix "https://html.duckduckgo.com/html/?q="
      shr-inhibit-images t
      shr-use-colors nil
      jit-lock-stealth-time 2
      jit-lock-chunk-size 8000
      jit-lock-defer-time 0.1
      fast-but-imprecise-scrolling t
      scroll-conservatively 101
      redisplay-skip-fontification-on-input t
      auto-window-vscroll nil
      bidi-display-reordering nil
      bidi-paragraph-direction 'left-to-right
      inhibit-compacting-font-caches t
      message-log-max 1000)

(setq ispell-alternate-dictionary
      (expand-file-name ".local/share/dict/words" "~"))

;;; Built-in services and performance

(use-package recentf
  :init
  (setq recentf-auto-cleanup 'never)
  :config
  (recentf-mode 1))

(use-package gcmh
  :hook (emacs-startup . gcmh-mode)
  :config
  (setq gcmh-idle-delay 5.0
        gcmh-high-cons-threshold (* 128 1024 1024)
        gcmh-verbose nil))

(use-package so-long
  :config (global-so-long-mode 1))

(provide 'jf-core)
;;; jf-core.el ends here
