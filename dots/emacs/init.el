;; init.el -*- lexical-binding: t; -*-

(jf/startup-mark "init entry")

(setq undo-limit (* 10 1024 1024)        ;; 10MB
      undo-strong-limit (* 15 1024 1024) ;; 15MB
      undo-outer-limit (* 50 1024 1024)) ;; 50MB

(setq custom-file null-device)

(blink-cursor-mode -1)

(require 'use-package)
(require 'server)
(require 'seq)
(require 'subr-x)
(require 'url-util)
(setq use-package-always-ensure nil)

(unless (server-running-p)
  (server-start))

(defvar jf/shutdown-inhibitor-process nil
  "Process holding a shutdown inhibitor while Emacs has unsaved buffers.")

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
        (when-let ((systemd-inhibit (executable-find "systemd-inhibit")))
          (setq jf/shutdown-inhibitor-process
                (start-process
                 "emacs-shutdown-inhibitor" nil
                 systemd-inhibit
                 "--what=shutdown:handle-power-key"
                 "--mode=block"
                 "--who=Emacs"
                 "--why=Warning: Unsaved buffers detected in Emacs!"
                 "sleep" "infinity"))))
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
(run-at-time nil 5 #'jf/update-shutdown-inhibitor)

(defvar jf/emacs-theme-light 'ef-reverie)
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
    (jf/apply-org-heading-faces)))

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
      native-comp-eln-load-path
      (let ((cache (expand-file-name "eln-cache/" jf/emacs-cache-directory))
            (default-user-cache
             (expand-file-name "eln-cache/" user-emacs-directory)))
        ;; Prefer immutable native code built by Nix.  Emacs writes new local
        ;; compilations to the first writable entry, so the user cache remains
        ;; a valid fallback even at the end of the search path.
        (append (delete cache
                        (delete default-user-cache
                                (copy-sequence native-comp-eln-load-path)))
                (list cache)))
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

(setq-default indent-tabs-mode nil
              tab-width 4
              standard-indent 4
              electric-indent-inhibit nil
              truncate-lines t)

(setq use-short-answers t
      vc-follow-symlinks t
      calendar-week-start-day 1
      large-file-warning-threshold (* 200 1024 1024)
      read-process-output-max (* 1024 1024)
      ring-bell-function 'ignore
      browse-url-browser-function 'browse-url-generic
      browse-url-generic-program "xdg-open"
      file-name-shadow-mode 1
      jit-lock-stealth-time 2
      jit-lock-chunk-size 8000
      jit-lock-defer-time 0.1
      fast-but-imprecise-scrolling t
      redisplay-skip-fontification-on-input t
      bidi-display-reordering nil
      bidi-paragraph-direction 'left-to-right
      inhibit-compacting-font-caches t
      auto-revert-use-notify nil
      auto-revert-interval 5
      auto-revert-check-vc-info nil
      message-log-max 1000)

(setq ispell-alternate-dictionary
      (expand-file-name ".local/share/dict/words" "~"))

(use-package tab-bar
  :ensure nil
  :config
  (setq tab-bar-show nil
        tab-bar-new-button-show nil
        tab-bar-close-button-show nil
        tab-bar-new-tab-choice "*scratch*")
  (tab-bar-mode 1)
  (tab-bar-rename-tab "1"))

(use-package recentf
  :init
  (setq recentf-auto-cleanup 'never)
  :config
  (recentf-mode 1))

(setq display-line-numbers-type t)

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
                pdf-view-mode-hook
                minibuffer-setup-hook))
  (add-hook hook #'jf/disable-global-hl-line-mode))

(global-hl-line-mode 1)

(use-package gcmh
  :hook (emacs-startup . gcmh-mode)
  :config
  (setq gcmh-idle-delay 5.0
        gcmh-high-cons-threshold (* 128 1024 1024)
        gcmh-verbose nil))

(use-package so-long
  :config (global-so-long-mode 1))

(use-package ef-themes
  :demand t
  :config
  (when (fboundp 'jf/apply-current-theme)
    (jf/apply-current-theme)))

(use-package savehist
  :config
  (add-to-list 'savehist-additional-variables 'extended-command-history)
  (savehist-mode 1))

(use-package vertico
  :config
  (require 'vertico-sort)
  (require 'vertico-multiform)
  (setq vertico-count 20
        vertico-cycle nil
        vertico-multiform-categories
        '((command (vertico-sort-function . vertico-sort-history-alpha))))
  (vertico-mode)
  (vertico-multiform-mode))

(use-package marginalia
  :config
  (marginalia-mode))

(use-package consult
  :demand t
  :bind (("C-x b" . consult-buffer)
         ("M-y"   . consult-yank-pop)
         ("M-g g" . consult-goto-line)
         ("M-g i" . consult-imenu)
         ("M-g r" . consult-grep))
  :config
  ;; Previewing while moving through recent files and buffers loads too much.
  (consult-customize
   consult-recent-file
   consult-buffer
   :preview-key "M-."))

(use-package treesit-auto
  :custom
  (treesit-auto-install nil)
  :config
  (setq treesit-font-lock-level 4)
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(use-package eglot
  :hook ((typst-ts-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)
         (nix-mode . eglot-ensure)
         (rust-ts-mode . eglot-ensure))
  :config
  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-sync-connect nil
        eglot-connect-timeout 10
        eglot-send-changes-idle-time 0.5
        eldoc-idle-delay 0.5
        eglot-autoshutdown t)
  (defun my/eglot-capf ()
    (setq-local completion-at-point-functions
                (list (cape-capf-super
                       #'eglot-completion-at-point
                       #'cape-file))))
  (add-hook 'eglot-managed-mode-hook #'my/eglot-capf)
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) .
                 ("basedpyright-langserver" "--stdio")))
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nil")))
  (cl-defmethod eglot-register-capability
    (_server (_method (eql workspace/didChangeConfiguration)) _id &rest _params)
    nil)
  (defun my/eglot-lsp-booster (orig-fun &rest args)
    (let ((res (apply orig-fun args)))
      (if (and (listp res) (not (string-prefix-p "emacs-lsp-booster" (car res))))
          (cons "emacs-lsp-booster" res)
        res)))

  (when (executable-find "emacs-lsp-booster")
    (advice-add 'eglot--contact :around #'my/eglot-lsp-booster)))

(defun typst-format-buffer ()
  "Format the current Typst buffer with typstyle."
  (interactive)
  (unless (executable-find "typstyle")
    (user-error "typstyle executable not found"))
  (let ((point (point))
        (window-start-pos (window-start))
        (output-buffer (generate-new-buffer " *typstyle output*"))
        (error-file (make-temp-file "typstyle-errors-")))
    (unwind-protect
        (let ((status (call-process-region
                       (point-min) (point-max)
                       "typstyle" nil
                       (list output-buffer error-file)
                       nil)))
          (if (zerop status)
              (let ((formatted (with-current-buffer output-buffer
                                 (buffer-string))))
                (unless (string= formatted (buffer-string))
                  (erase-buffer)
                  (insert formatted))
                (goto-char (min point (point-max)))
                (set-window-start nil (min window-start-pos (point-max)) t)
                (message "Formatted with typstyle"))
            (user-error "typstyle failed: %s"
                        (string-trim
                         (with-temp-buffer
                           (insert-file-contents error-file)
                           (buffer-string))))))
      (kill-buffer output-buffer)
      (ignore-errors
        (delete-file error-file)))))

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  :bind (:map typst-ts-mode-map
              ("C-c C-f" . typst-format-buffer))
  :config
  (setq typst-ts-preview-function #'find-file)
  (add-hook 'typst-ts-compile-before-compilation-hook #'save-buffer)
  (add-hook 'typst-ts-watch-before-watch-hook #'save-buffer)
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist")))))

(use-package typst-preview
  :after typst-ts-mode
  :bind (:map typst-ts-mode-map
              ("C-c C-v" . typst-preview-mode)
              ("C-c C-j" . typst-preview-send-position))
  :config
  (setq typst-preview-ask-if-pin-main nil
        typst-preview-autostart t
        typst-preview-open-browser-automatically t
        typst-preview-executable "tinymist"))

(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-min-width 20)
  (corfu-max-width 100)
  (corfu-count 14)
  (corfu-preselect 'prompt)
  :config
  (global-corfu-mode))

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  :config
  (require 'cape-keyword)
  (add-to-list 'completion-at-point-functions #'cape-keyword))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles basic partial-completion)))))

(use-package which-key
  :defer 2
  :config
  (setq which-key-idle-delay 1.0
        which-key-idle-secondary-delay 0.05)
  (which-key-mode))

(defface jf/mode-line-buffer
  '((t :inherit (mode-line-buffer-id mode-line) :weight bold))
  "Face for the current buffer name in the mode line.")

(defface jf/mode-line-buffer-inactive
  '((t :inherit mode-line-inactive :weight bold))
  "Face for inactive buffer names in the mode line.")

(defface jf/mode-line-muted
  '((t :inherit (shadow mode-line)))
  "Face for low-priority mode line text.")

(defface jf/mode-line-muted-inactive
  '((t :inherit mode-line-inactive))
  "Face for inactive low-priority mode line text.")

(defface jf/mode-line-accent
  '((t :inherit (mode-line-emphasis font-lock-keyword-face mode-line)
       :weight medium))
  "Face for highlighted mode line text.")

(defface jf/mode-line-accent-inactive
  '((t :inherit mode-line-inactive :weight medium))
  "Face for inactive highlighted mode line text.")

(defface jf/mode-line-attention
  '((t :inherit (error mode-line) :weight bold))
  "Face for mode line text that needs attention.")

(defface jf/mode-line-attention-inactive
  '((t :inherit mode-line-inactive :weight bold))
  "Face for inactive mode line text that needs attention.")

(defconst jf/mode-line-min-spacer-width 1
  "Minimum spaces to keep between mode line left and right segments.")

(defun jf/mode-line-active-p ()
  "Return non-nil when formatting the selected window's mode line."
  (if (fboundp 'mode-line-window-selected-p)
      (mode-line-window-selected-p)
    (eq (selected-window) (get-buffer-window (current-buffer)))))

(defun jf/mode-line-face (face)
  "Return the active or inactive mode line variant of FACE."
  (if (jf/mode-line-active-p)
      (pcase face
        ('buffer 'jf/mode-line-buffer)
        ('muted 'jf/mode-line-muted)
        ('accent 'jf/mode-line-accent)
        ('attention 'jf/mode-line-attention))
    (pcase face
      ('buffer 'jf/mode-line-buffer-inactive)
      ('muted 'jf/mode-line-muted-inactive)
      ('accent 'jf/mode-line-accent-inactive)
      ('attention 'jf/mode-line-attention-inactive))))

(defun jf/mode-line--display-width (string)
  "Return the displayed width of STRING without text properties."
  (string-width (substring-no-properties (or string ""))))

(defun jf/mode-line--truncate-middle (string max-width)
  "Return STRING truncated in the middle to MAX-WIDTH columns."
  (let* ((max-width (max 0 max-width))
         (width (jf/mode-line--display-width string))
         (marker "..."))
    (cond
     ((<= width max-width) string)
     ((<= max-width 0) "")
     ((= max-width 1)
      (truncate-string-to-width string max-width nil nil ""))
     ((= max-width 2)
      (concat
       (truncate-string-to-width string 1 nil nil "")
       (truncate-string-to-width string width (1- width) nil "")))
     ((= max-width 3)
      (concat
       (truncate-string-to-width string 1 nil nil "")
       "."
       (truncate-string-to-width string width (1- width) nil "")))
     (t
      (let* ((content-width (- max-width (string-width marker)))
             (left-width (/ (+ content-width 1) 2))
             (right-width (/ content-width 2))
             (right-start (max 0 (- width right-width))))
        (concat
         (truncate-string-to-width string left-width nil nil "")
         (propertize marker 'face (get-text-property 0 'face string))
         (truncate-string-to-width string width right-start nil "")))))))

(defun jf/mode-line--escape-percent (string)
  "Escape percent characters in STRING for literal mode line display."
  (replace-regexp-in-string "%" "%%" string t t))

(defun jf/mode-line-status ()
  "Return a compact buffer status indicator."
  (cond
   (buffer-read-only
    nil)
   ((buffer-modified-p)
    (propertize "*" 'face (jf/mode-line-face 'attention)))
   (t
    (propertize "-" 'face (jf/mode-line-face 'muted)))))

(defun jf/mode-line-vc ()
  "Return the cached VC branch for the current buffer, if available."
  (when vc-mode
    (concat
     " "
     (propertize
      (string-trim
       (replace-regexp-in-string
        "\\`Git[:-]" "" (substring-no-properties vc-mode)))
      'face (jf/mode-line-face 'accent)))))

(defvar jf/mode-line-battery nil
  "Cached battery status for the mode line.")

(defvar jf/mode-line-battery-capacity nil
  "Cached battery capacity percentage as a number.")

(defun jf/mode-line--read-file (file)
  "Return trimmed contents of FILE when it is readable."
  (when (file-readable-p file)
    (string-trim
     (with-temp-buffer
       (insert-file-contents file)
       (buffer-string)))))

(defun jf/mode-line--system-battery-directories ()
  "Return non-device battery power supply directories."
  (when (file-directory-p "/sys/class/power_supply")
    (seq-filter
     (lambda (dir)
       (and (string= (jf/mode-line--read-file (expand-file-name "type" dir))
                     "Battery")
            (not (string= (jf/mode-line--read-file (expand-file-name "scope" dir))
                          "Device"))
            (file-readable-p (expand-file-name "capacity" dir))))
     (directory-files "/sys/class/power_supply" t "\\`[^.]"))))

(defun jf/mode-line-update-battery ()
  "Refresh cached battery status for the mode line."
  (setq jf/mode-line-battery nil
        jf/mode-line-battery-capacity nil)
  (when-let* ((battery (car (jf/mode-line--system-battery-directories)))
              (capacity-text (jf/mode-line--read-file
                              (expand-file-name "capacity" battery)))
              (status (jf/mode-line--read-file
                       (expand-file-name "status" battery))))
    (let ((prefix (if (string= status "Discharging") "-" "+"))
          (capacity (string-to-number capacity-text)))
      (setq jf/mode-line-battery (format "%s%s%%%%" prefix capacity-text)
            jf/mode-line-battery-capacity capacity)))
  (force-mode-line-update t))

(run-with-timer 0 60 #'jf/mode-line-update-battery)

(defun jf/mode-line-buffer-name (max-width)
  "Return the current buffer name for the mode line within MAX-WIDTH."
  (propertize
   (jf/mode-line--escape-percent
    (jf/mode-line--truncate-middle (buffer-name) max-width))
   'face (jf/mode-line-face 'buffer)))

(defun jf/mode-line-mode-name ()
  "Return the current major mode name for the mode line."
  (if (stringp mode-name)
      mode-name
    (format-mode-line mode-name)))

(defun jf/mode-line-battery-face ()
  "Return a theme-aware face for the current low battery level."
  (if (<= jf/mode-line-battery-capacity 10)
      'error
    'warning))

(defun jf/mode-line-right ()
  "Return the right-aligned mode line segment."
  (concat
   (when (and jf/mode-line-battery
              jf/mode-line-battery-capacity
              (<= jf/mode-line-battery-capacity 20))
     (concat
      (propertize jf/mode-line-battery
                  'face (jf/mode-line-battery-face))
      " "))
   (jf/mode-line-mode-name)))

(defun jf/mode-line-notification ()
  "Return the current Eureka desktop notification, if any."
  (when (bound-and-true-p jf-eureka-notification-current)
    (let* ((notification jf-eureka-notification-current)
           (critical (plist-get notification :critical))
           (text (concat (if critical "⚠ " "")
                         (plist-get notification :summary)
                         (if (string-empty-p (plist-get notification :body))
                             ""
                           (concat ": " (plist-get notification :body))))))
      (concat (propertize (truncate-string-to-width text 60 nil nil "…")
                          'face (if critical 'error 'mode-line-emphasis))
              "  "))))

(defvar jf/org-roam-current-profile 'personal
  "The org-roam profile active in this Emacs session.")

(defun jf/systeminfo ()
  "Show the current time and battery level."
  (interactive)
  (jf/mode-line-update-battery)
  (let ((time (downcase (string-trim (format-time-string "%I:%M %p")))))
    (if jf/mode-line-battery-capacity
        (message "It's %s. Battery at %d%%."
                 time jf/mode-line-battery-capacity)
      (message "It's %s. Battery unavailable." time))))

(defun jf/mode-line ()
  "Return the full mode line with a fixed minimum spacer."
  (let* ((window-width (window-total-width))
         (right (concat (jf/mode-line-right) " "))
         (prefix (concat
                  " "
                  (or (jf/mode-line-notification) "")
                  (when-let ((status (jf/mode-line-status)))
                    (concat status " "))))
         (vc (or (jf/mode-line-vc) ""))
         (max-buffer-width
          (- window-width
             (jf/mode-line--display-width prefix)
             (jf/mode-line--display-width vc)
             (jf/mode-line--display-width right)
             jf/mode-line-min-spacer-width))
         (left (concat prefix (jf/mode-line-buffer-name max-buffer-width) vc))
         (spacer-width
          (max jf/mode-line-min-spacer-width
               (- window-width
                  (jf/mode-line--display-width left)
                  (jf/mode-line--display-width right)))))
    (concat left (make-string spacer-width ?\s) right)))

(setq-default mode-line-format
              '("%e"
                (:eval (jf/mode-line))))

(use-package visual-fill-column
  :custom (visual-fill-column-center-text t)
  :commands visual-fill-column-mode)

(defun jf/visual-fill-org ()
  "Center Org buffers in a readable column width."
  (setq visual-fill-column-width 72)
  (visual-fill-column-mode 1))

(defun jf/visual-fill-agenda ()
  "Center agenda buffers in a wider column."
  (setq visual-fill-column-width 100)
  (visual-fill-column-mode 1))

(defface jf/org-agenda-top-padding
  '((t (:inherit default :height 0.25 :extend t :box nil
        :underline nil :overline nil)))
  "Face for the small blank header above agenda buffers.")

(defun jf/org-agenda-add-top-padding ()
  "Add top spacing without inserting a non-agenda buffer line."
  (setq-local header-line-format
              '(:propertize " "
                            display (space :align-to (- right-fringe 0))
                            face jf/org-agenda-top-padding)))

(defun jf/org-disable-prose-completion ()
  "Disable dictionary-word completion while retaining Org completion."
  (setq-local completion-at-point-functions
              (remove #'ispell-completion-at-point
                      completion-at-point-functions)))

(defun jf/apply-fonts (&optional frame)
  (set-face-attribute 'default frame :font "JetBrainsMono Nerd Font" :height 160)
  (set-face-attribute 'fixed-pitch frame :font "JetBrainsMono Nerd Font" :height 160)
  (set-face-attribute 'variable-pitch frame :font "JetBrainsMono Nerd Font" :height 160 :weight 'regular))

(add-hook 'after-make-frame-functions #'jf/apply-fonts)
(jf/apply-fonts)

(defun jf/apply-org-heading-faces ()
  "Apply a restrained size hierarchy to Org and agenda headings."
  (dolist (face-height '((org-level-1 . 1.30)
                         (org-level-2 . 1.20)
                         (org-level-3 . 1.10)))
    (set-face-attribute (car face-height) nil
                        :height (cdr face-height)
                        :weight 'semi-bold))
  (dolist (face '(org-level-4 org-level-5 org-level-6
                  org-level-7 org-level-8))
    (set-face-attribute face nil :height 1.0 :weight 'semi-bold))
  (set-face-attribute 'org-agenda-structure nil
                      :height 1.15 :weight 'bold)
  (dolist (face '(org-agenda-date org-agenda-date-today
                  org-agenda-date-weekend))
    (set-face-attribute face nil :height 1.15 :weight 'bold)))

(with-eval-after-load 'org
  (jf/apply-org-heading-faces))

;; The initial agenda visits agenda.org before there is an interactive startup
;; buffer in which to answer a local-variable safety prompt.  Trust this exact,
;; non-evaluating archive destination up front so agenda construction cannot be
;; replaced by the *Local Variables* query buffer.
(add-to-list 'safe-local-variable-values
             '(org-archive-location . "archive.org::* Archived Tasks"))

(use-package org
  :hook ((org-mode . visual-line-mode)
         (org-mode . jf/visual-fill-org)
         (org-mode . jf/org-disable-prose-completion)
         (org-agenda-mode . jf/visual-fill-agenda)
         (org-agenda-mode . jf/org-agenda-add-top-padding))
  :config
  (setq org-directory "~/documents/org/"

        ;; Org 9.8 otherwise eagerly loads eleven legacy/link integrations
        ;; (BBDB, BibTeX, Gnus, IRC, Rmail, W3M, etc.) the first time any Org
        ;; buffer opens.  None is used by this configuration; individual
        ;; integrations can still be required explicitly if needed later.
        org-modules nil
        
        org-capture-templates
        '(("i" "inbox" entry
           (file "~/documents/org/inbox.org")
           "* [%<%Y-%m-%d %H:%M>] %?"
           :empty-lines 1))
        
        org-hide-leading-stars nil
        org-agenda-files '("~/documents/org/agenda.org")
        org-todo-keywords '((sequence "TODO(t)" "WAIT(w!)" "|" "CANCELLED(c!)" "DONE(d!)"))
        org-ellipsis " ▾"
        org-hide-emphasis-markers t
        org-startup-truncated nil
        org-return-follows-link t
        org-agenda-span 'day
        org-agenda-window-setup 'current-window
        org-agenda-block-separator nil
        org-agenda-compact-blocks t
        org-M-RET-may-split-line '((default . nil))
        org-insert-heading-respect-content t
        org-log-done 'time
        org-log-into-drawer t
        org-tags-column 0
        org-startup-folded 'content
        org-element-use-cache t
        org-element-cache-persistent t
        org-fontify-whole-heading-line t
        org-fontify-done-headline nil
        org-fontify-quote-and-verse-blocks t
        org-startup-indented t
        org-startup-with-inline-images t
        org-startup-with-latex-preview t
        org-pretty-entities t
        org-use-sub-superscripts '{}
        org-agenda-inhibit-startup t
        org-agenda-use-tag-inheritance nil
        org-agenda-ignore-properties '(effort appt category)
        org-agenda-dim-blocked-tasks nil
        org-auto-align-tags nil
        org-fold-catch-invisible-edits 'show-and-error
        org-startup-align-all-tables nil
        org-src-fontify-natively t
        org-link-descriptive t
        org-preview-latex-default-process 'dvisvgm
        org-format-latex-options '(:foreground default :background "Transparent"
                                   :scale 1.5 :html-foreground "Black"
                                   :html-background "Transparent" :html-scale 1.0
                                   :matchers ("begin" "$1" "$" "$$" "\\(" "\\[")))
  
  (plist-put org-format-latex-options :background "Transparent")
  (setq org-preview-latex-process-alist
        (assq-delete-all 'dvisvgm org-preview-latex-process-alist))
  (add-to-list 'org-preview-latex-process-alist
               '(dvisvgm :programs ("latex" "dvisvgm")
                         :description "dvi > svg"
                         :message "you need to install latex and dvisvgm."
                         :image-input-type "dvi"
                         :image-output-type "svg"
                        :image-size-adjust (1.7 . 1.5)
                        :latex-compiler ("latex -interaction nonstopmode -output-directory %o %f")
                        :image-converter ("dvisvgm %f --no-fonts --exact-bbox --scale=%S -o %O")))

  (with-eval-after-load 'ol
    (setf (cdr (assq 'file org-link-frame-setup)) #'find-file)))

(defun jf/org-archive-completed-before-today ()
  "Archive completed agenda entries closed before the current calendar day."
  (require 'org-archive)
  (let* ((now (decode-time))
         (today (encode-time 0 0 0
                             (decoded-time-day now)
                             (decoded-time-month now)
                             (decoded-time-year now)))
         (archived 0))
    (dolist (file (org-agenda-files t))
      (when (file-readable-p file)
        (with-current-buffer (find-file-noselect file)
          (let (completed)
            (org-with-wide-buffer
             (org-map-entries
              (lambda ()
                (let ((state (org-get-todo-state))
                      (closed (org-entry-get nil "CLOSED")))
                  (when (and (member state '("DONE" "CANCELLED"))
                             closed
                             (time-less-p (org-time-string-to-time closed)
                                          today))
                    (push (point-marker) completed))))
              nil 'file)
             ;; Moving subtrees from bottom to top keeps every earlier marker
             ;; stable while the current subtree is removed.
             (dolist (marker (sort completed
                                   (lambda (a b)
                                     (> (marker-position a)
                                        (marker-position b)))))
               (goto-char marker)
               (org-archive-subtree)
               (set-marker marker nil)
               (cl-incf archived)))
            (when (buffer-modified-p)
              (save-buffer))))))
    archived))

(defun jf/initial-agenda-buffer ()
  "Build and return the agenda used as the initial buffer."
  (jf/startup-mark "initial agenda start")
  (jf/startup-mark "require org-agenda start")
  (require 'org-agenda)
  (jf/startup-mark "require org-agenda end")
  (let ((count (jf/org-archive-completed-before-today)))
    (when (> count 0)
      (message "Archived %d completed task%s from previous days"
               count (if (= count 1) "" "s"))))
  (let ((this-command 'jf/org-agenda-dashboard)
        ;; Restoring an on-disk element cache costs far more than parsing the
        ;; 1.8 KB agenda source.  Keep persistent caching for normal Org files.
        (org-element-cache-persistent nil))
    (jf/startup-mark "agenda dashboard start")
    (jf/org-agenda-dashboard)
    (jf/startup-mark "agenda dashboard end")
    ;; The graphical Eureka session treats this startup dashboard as an empty
    ;; workspace: its first Wayland client replaces it instead of opening an
    ;; additional Emacs window.
    (setq-local jf-eureka--initial-placeholder t)
    ;; Measure the point at which the requested initial buffer has actually
    ;; been painted, rather than merely constructed in Lisp.
    (redisplay t)
    (jf/startup-mark "initial agenda first redisplay")
    (current-buffer)))

(defun jf/org-agenda--has-entries-p (match &optional undated)
  "Return non-nil when an agenda entry matches MATCH.
When UNDATED is non-nil, also require no schedule or deadline."
  (catch 'found
    (org-map-entries
     (lambda ()
       (when (or (not undated)
                 (and (not (org-entry-get nil "SCHEDULED"))
                      (not (org-entry-get nil "DEADLINE"))))
         (throw 'found t)))
     match 'agenda)
    nil))

(defun jf/org-agenda--compare-explicit-priority (a b)
  "Order agenda lines A and B by explicit priority, with none last."
  (let ((priority-a (if (string-match "\\[#[A-Z]\\]" a)
                        (aref (match-string 0 a) 2)
                      256))
        (priority-b (if (string-match "\\[#[A-Z]\\]" b)
                        (aref (match-string 0 b) 2)
                      256)))
    (cond ((< priority-a priority-b) -1)
          ((> priority-a priority-b) 1))))

(defun jf/org-agenda--separate-dashboard-sections ()
  "Put exactly one blank line before secondary dashboard sections."
  (let ((inhibit-read-only t))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "^\\(?:Upcoming Deadlines\\|Tasks Without a Deadline\\)$"
              nil t)
        (goto-char (line-beginning-position))
        (let ((header-start (point)))
          (skip-chars-backward "\n")
          (delete-region (point) header-start)
          (insert "\n\n")
          (forward-line 1)))))
  (unless (org-get-at-bol 'org-marker)
    (goto-char (point-min))
    (while (and (not (eobp))
                (not (org-get-at-bol 'org-marker)))
      (forward-line 1))))

(defun jf/org-agenda-dashboard ()
  "Show today's schedule and non-empty deadline and undated task blocks."
  (interactive)
  (require 'org-agenda)
  (let* ((deadline-match "DEADLINE>=\"<+1d>\"+DEADLINE<=\"<+14d>\"")
         (blocks
          `((agenda ""
                    ((org-agenda-overriding-header "")
                     (org-agenda-span 1)))
            ,@(when (jf/org-agenda--has-entries-p deadline-match)
                `((tags-todo
                   ,deadline-match
                   ((org-agenda-overriding-header "Upcoming Deadlines")
                    (org-agenda-sorting-strategy '(deadline-up))))))
            ,@(when (jf/org-agenda--has-entries-p "/TODO" t)
                '((todo
                   "TODO"
                   ((org-agenda-overriding-header "Tasks Without a Deadline")
                    (org-agenda-skip-function
                     '(org-agenda-skip-entry-if 'scheduled 'deadline))
                    (org-agenda-cmp-user-defined
                     #'jf/org-agenda--compare-explicit-priority)
                    (org-agenda-sorting-strategy '(user-defined-up))))))))
         (settings
          '((org-agenda-finalize-hook
             '(jf/org-agenda--separate-dashboard-sections))))
         (org-agenda-custom-commands
          `(("d" "Dashboard" ,blocks ,settings))))
    (org-agenda nil "d")))

(setq initial-buffer-choice #'jf/initial-agenda-buffer)

(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode))

(use-package org-roam
  :defer t
  :bind (("C-c r f" . org-roam-node-find)
         ("C-c r c" . org-roam-capture)
         ("C-c r i" . org-roam-node-insert)
         ("C-c r I" . jf/org-roam-node-insert-immediate)
         ("C-c r b" . org-roam-buffer-toggle)
         ("C-c r u" . org-roam-ui-open)
         ("C-c r d" . jf/org-roam-dailies-goto-date)
         ("C-c r p" . jf/org-roam-switch-profile)
         ("C-c r t" . org-roam-tag-add))
  :config
  (cl-defmethod org-roam-node-slug ((node org-roam-node))
    (let* ((title (downcase (org-roam-node-title node)))
           ;; `[:alnum:]' is Unicode-aware, so Spanish letters are retained.
           (slug (replace-regexp-in-string "[^[:alnum:]]+" "-" title)))
      (string-trim slug "-+" "-+")))

  (defconst jf/org-roam-profiles
    `((personal
       :directory "~/documents/roam/personal/"
       :database ,(locate-user-emacs-file "org-roam/personal.db")
       :dailies "journal/"
       :templates
       (("p" "[PERSONAL] note" plain "%?"
         :target (file+head "${slug}.org"
                            "#+title: ${title}\n")
         :unnarrowed t)))
      (diving
       :directory "~/documents/roam/diving/"
       :database ,(locate-user-emacs-file "org-roam/diving.db")
       :dailies nil
       :templates
       (("d" "[DIVING] nota" plain "%?"
         :target (file+head "${slug}.org"
                            ":PROPERTIES:\n:ID: ${id}\n:END:\n#+title: ${title}\n#+hugo_section: notas\n#+hugo_draft: true\n")
         :unnarrowed t))))
    "Configuration for each isolated org-roam profile.")

  (defun jf/org-roam--profile-plist (profile)
    "Return the configuration plist for PROFILE."
    (or (alist-get profile jf/org-roam-profiles)
        (user-error "Unknown org-roam profile: %s" profile)))

  (defun jf/org-roam--confirm-public-capture (original &rest args)
    "Guard diving note creation before calling ORIGINAL with ARGS."
    (when (and (eq jf/org-roam-current-profile 'diving)
               (not (yes-or-no-p
                     "DIVING: create this note in the public repository? ")))
      (user-error "Capture cancelled"))
    (apply original args))

  ;; Both ordinary capture and insertion of a missing node pass through this
  ;; internal capture entry point, so the public guard cannot be bypassed by
  ;; choosing a different note-creation command.
  (unless (advice-member-p #'jf/org-roam--confirm-public-capture
                           'org-roam-capture-)
    (advice-add 'org-roam-capture- :around
                #'jf/org-roam--confirm-public-capture))

  (defun jf/org-roam-activate-profile (profile &optional quiet)
    "Activate PROFILE, rebuilding org-roam state in isolation.
When QUIET is non-nil, suppress the profile-change message."
    (let* ((settings (jf/org-roam--profile-plist profile))
           (directory (file-truename
                       (expand-file-name (plist-get settings :directory))))
           (database (expand-file-name (plist-get settings :database))))
      (org-roam-db-autosync-mode -1)
      (when (bound-and-true-p org-roam-ui-mode)
        (org-roam-ui-mode -1))
      (when (fboundp 'org-roam-db--close-all)
        (org-roam-db--close-all))
      (make-directory directory t)
      (make-directory (file-name-directory database) t)
      (setq jf/org-roam-current-profile profile
            org-roam-directory directory
            org-roam-db-location database
            org-roam-dailies-directory (plist-get settings :dailies)
            org-roam-capture-templates (plist-get settings :templates))
      (org-roam-db-sync)
      (org-roam-db-autosync-mode 1)
      (force-mode-line-update t)
      (unless quiet
        (message "%s"
                 (if (eq profile 'diving)
                     "ORG-ROAM: DIVING — captures require confirmation"
                   "ORG-ROAM: PERSONAL")))))

  (defun jf/org-roam-switch-profile (profile)
    "Interactively switch to an isolated org-roam PROFILE."
    (interactive
     (list (intern
            (completing-read
             (format "Switch org-roam profile (currently %s): "
                     jf/org-roam-current-profile)
             (mapcar (lambda (entry) (symbol-name (car entry)))
                     jf/org-roam-profiles)
             nil t))))
    (jf/org-roam-activate-profile profile))

  (defun jf/org-roam-dailies-goto-date ()
    "Visit a personal daily note, rejecting dailies in public profiles."
    (interactive)
    (unless (eq jf/org-roam-current-profile 'personal)
      (user-error "Dailies are private; switch to the personal profile first"))
    (call-interactively #'org-roam-dailies-goto-date))

  (defun jf/org-roam-node-insert-immediate (arg &rest args)
    "Insert a node and finish capture immediately."
    (interactive "P")
    (let ((args (cons arg args))
          (org-roam-capture-templates
           (list (append (car org-roam-capture-templates)
                         '(:immediate-finish t)))))
      (apply #'org-roam-node-insert args)))

  (setq org-roam-completion-everywhere nil
        org-roam-db-update-on-save t)
  ;; Never restore the last profile: every Emacs session starts private.
  (jf/org-roam-activate-profile 'personal t))

(use-package org-roam-ui
  :after org-roam
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start nil))

(use-package pdf-tools
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :magic ("%PDF" . pdf-view-mode)
  :config
  (setq pdf-view-use-scaling t
        pdf-view-continuous t
        pdf-view-display-size 'fit-width
        pdf-view-resize-factor 1.1
        pdf-cache-image-limit 64
        pdf-cache-prefetch-delay 0.15
        pdf-view-max-image-width 2048)
  (setq-default pdf-view-use-unicode-lighter nil)
  (add-hook 'pdf-view-mode-hook
            (lambda ()
              (pdf-cache-prefetch-minor-mode 1)
              (display-line-numbers-mode -1)
              (auto-revert-mode -1)
              (cursor-sensor-mode -1))))

(use-package vterm
  :commands (vterm vterm-other-window)
  :config
  (defun jf/vterm-sync-default-directory ()
    "Sync the current vterm buffer's `default-directory' from its shell."
    (when (derived-mode-p 'vterm-mode)
      (when-let* ((process (get-buffer-process (current-buffer)))
                  (pid (process-id process))
                  (cwd-link (format "/proc/%d/cwd" pid))
                  ((file-exists-p cwd-link))
                  (directory (file-truename cwd-link))
                  ((file-directory-p directory)))
        (setq-local default-directory (file-name-as-directory directory)))))

  (setq vterm-timer-delay nil
        vterm-shell "/run/current-system/sw/bin/bash"))

(defun jf/buffer-default-directory ()
  "Return the directory that file prompts should use for the current buffer."
  (cond
   ((derived-mode-p 'vterm-mode)
    (when (fboundp 'jf/vterm-sync-default-directory)
      (jf/vterm-sync-default-directory))
    default-directory)
   (buffer-file-name
    (file-name-directory buffer-file-name))
   ((and (boundp 'dired-directory) dired-directory)
    (if (consp dired-directory)
        (car dired-directory)
      dired-directory))
   ((and (boundp 'eureka-window) eureka-window)
    "~/")
   ((file-directory-p default-directory)
    default-directory)
   (t
    "~/")))

(defun jf/sync-default-directory-before-file-prompt (&rest _)
  "Make file prompts start in the current buffer's relevant directory."
  (setq-local default-directory
              (file-name-as-directory
               (expand-file-name (jf/buffer-default-directory)))))

(advice-add 'find-file-read-args
            :before #'jf/sync-default-directory-before-file-prompt)
(advice-add 'dired-read-dir-and-switches
            :before #'jf/sync-default-directory-before-file-prompt)

(use-package alert
  :commands (alert)
  :config
  (setq alert-default-style 'libnotify))

(use-package hledger-mode
  :mode ("\\.journal\\'" . hledger-mode)
  :bind (:map hledger-mode-map
              ("C-c h b" . jf/hledger-balance)
              ("C-c h r" . jf/hledger-register)
              ("C-c h h" . jf/hledger-run))
  :config
  (setq hledger-jfile (expand-file-name
                       "~/documents/personal/finance/main.journal")))

(defun jf/hledger-command (arguments)
  "Run hledger with ARGUMENTS against `hledger-jfile'."
  (unless (executable-find "hledger")
    (user-error "hledger executable not found"))
  (let ((command (mapconcat #'shell-quote-argument
                            (append (list "hledger" "--file" hledger-jfile)
                                    arguments)
                            " ")))
    (compilation-start command 'compilation-mode
                       (lambda (_) "*hledger*"))))

(defun jf/hledger-balance ()
  "Show the hledger balance report."
  (interactive)
  (jf/hledger-command '("balance")))

(defun jf/hledger-register ()
  "Show the hledger register report."
  (interactive)
  (jf/hledger-command '("register")))

(defun jf/hledger-run (arguments)
  "Prompt for hledger ARGUMENTS and run them."
  (interactive (list (split-string-and-unquote
                      (read-string "hledger arguments: "))))
  (jf/hledger-command arguments))

(defvar jf/pomodoro-timer nil
  "Active Pomodoro timer, or nil when no Pomodoro is running.")

(defun jf/pomodoro-finished ()
  "Finish the active Pomodoro and notify the user."
  (setq jf/pomodoro-timer nil)
  (alert "Time for a break." :title "Pomodoro finished")
  (message "Pomodoro finished — time for a break."))

(defun jf/pomodoro (&optional minutes)
  "Start a Pomodoro for MINUTES, defaulting to 25.
When a Pomodoro is already running, offer to cancel it instead."
  (interactive "P")
  (if (timerp jf/pomodoro-timer)
      (when (y-or-n-p "Cancel the current Pomodoro? ")
        (cancel-timer jf/pomodoro-timer)
        (setq jf/pomodoro-timer nil)
        (message "Pomodoro cancelled"))
    (let ((minutes (if minutes
                       (prefix-numeric-value minutes)
                     25)))
      (unless (> minutes 0)
        (user-error "Pomodoro length must be positive"))
      (setq jf/pomodoro-timer
            (run-at-time (* minutes 60) nil #'jf/pomodoro-finished))
      (message "Pomodoro started for %d minutes" minutes))))

(defvar jf/pdf-document-roots
  '("~/documents" "~/downloads" "~/projects")
  "Directories searched by `jf/pick-pdf'.")

(defvar jf/pdf-document-cache nil
  "Cached PDF candidates for `jf/pick-pdf'.")

(defun jf/pdf-document--mtime (file)
  "Return FILE modification time as a float."
  (float-time (file-attribute-modification-time (file-attributes file))))

(defun jf/pdf-document--display-name (file)
  "Return display name for PDF FILE."
  (abbreviate-file-name file))

(defun jf/pdf-document-refresh-cache ()
  "Refresh cached PDF candidates."
  (interactive)
  (setq jf/pdf-document-cache
        (mapcar
         (lambda (file)
           (cons (jf/pdf-document--display-name file) file))
         (sort
          (delete-dups
           (delq nil
                 (mapcan
                  (lambda (root)
                    (let ((dir (expand-file-name root)))
                      (when (file-directory-p dir)
                        (directory-files-recursively dir "\\.pdf\\'" nil))))
                  jf/pdf-document-roots)))
          (lambda (a b)
            (> (jf/pdf-document--mtime a)
               (jf/pdf-document--mtime b))))))
  jf/pdf-document-cache)

(defun jf/pick-pdf (&optional refresh)
  "Select a PDF and open it in Zathura.
With prefix argument REFRESH, rebuild the PDF cache first."
  (interactive "P")
  (when (or refresh (null jf/pdf-document-cache))
    (jf/pdf-document-refresh-cache))
  (let* ((candidates jf/pdf-document-cache)
         (choice (when candidates
                   (completing-read "Select PDF: " candidates nil t))))
    (if-let ((path (cdr (assoc choice candidates))))
        (start-process "jf-pick-pdf-zathura" nil "zathura" path)
      (user-error "No PDFs found"))))

(defvar jf/bookmarks-file
  (expand-file-name "nixos/common/bookmarks.txt" (getenv "HOME"))
  "Plain text bookmark file.  Each line is NAME URL.")

(defun jf/bookmark--canonical-url (url)
  "Return a stable comparison key for URL."
  (let ((url (string-trim url)))
    (if (and (> (length url) 1) (string-suffix-p "/" url))
        (substring url 0 -1)
      url)))

(defun jf/bookmark--read-bookmarks ()
  "Return bookmarks from `jf/bookmarks-file' as plists."
  (unless (file-readable-p jf/bookmarks-file)
    (user-error "Bookmark file is not readable: %s" jf/bookmarks-file))
  (with-temp-buffer
    (insert-file-contents jf/bookmarks-file)
    (let (bookmarks)
      (dolist (line (split-string (buffer-string) "\n" t))
        (unless (string-match-p "\\`[ \t]*\\(?:#.*\\)?\\'" line)
          (if (string-match "\\`[ \t]*\\(.+?\\)[ \t]+\\(https?://.+\\)[ \t]*\\'" line)
              (push (list :name (string-trim (match-string 1 line))
                          :url (string-trim (match-string 2 line)))
                    bookmarks)
            (message "Skipping malformed bookmark line: %s" line))))
      (nreverse bookmarks))))

(defun jf/bookmark--eureka-browser-buffer (url)
  "Return a Eureka browser buffer already showing URL, if one is visible to Emacs."
  (let ((url (jf/bookmark--canonical-url url)))
    (seq-find
     (lambda (buffer)
       (with-current-buffer buffer
         (when (eq major-mode 'eureka-mode)
           (let ((app-id (and (boundp 'eureka-app-id)
                              (buffer-local-value 'eureka-app-id buffer)))
                 (title (if (and (boundp 'eureka-title)
                                 (buffer-local-value 'eureka-title buffer))
                            (buffer-local-value 'eureka-title buffer)
                          (buffer-name buffer))))
             (and (member app-id '("brave"
                                    "brave-browser"
                                    "Brave-browser"
                                    "com.brave.Browser"
                                    "librewolf"
                                    "LibreWolf"))
                  (or (string-match-p (regexp-quote (concat "[" url "]")) title)
                      (string-match-p (regexp-quote url) title)))))))
     (buffer-list))))

(defun jf/bookmark--open-url (url)
  "Open URL in the default browser."
  (browse-url url))

(defun jf/browser--url-or-search (text)
  "Return TEXT as a URL or a search URL."
  (if (string-match-p "\\`\\(?:[[:alpha:]][[:alnum:]+.-]*://\\|about:\\)" text)
      text
    (format "https://duckduckgo.com/?q=%s" (url-hexify-string text))))

(defun jf/browser-open-or-search ()
  "Open a URL or search arbitrary text in the default browser."
  (interactive)
  (let ((text (string-trim (read-string "Open/search: "))))
    (when (string-empty-p text)
      (user-error "Empty browser input"))
    (jf/bookmark--open-url (jf/browser--url-or-search text))))

(defun jf/bookmark-open ()
  "Pick a bookmark from `jf/bookmarks-file' and open it in the browser."
  (interactive)
  (let* ((bookmarks (jf/bookmark--read-bookmarks))
         (candidates
          (mapcar
           (lambda (bookmark)
             (let* ((url (plist-get bookmark :url))
                    (buffer (jf/bookmark--eureka-browser-buffer url))
                    (label (format "%-10s %s  %s"
                                   (if buffer "[open]" "")
                                   (plist-get bookmark :name)
                                   url)))
               (cons label bookmark)))
           bookmarks))
         (choice (consult--read candidates
                                :prompt "Bookmark: "
                                :lookup #'consult--lookup-cdr
                                :require-match t
                                :sort nil))
         (url (plist-get choice :url))
         (buffer (jf/bookmark--eureka-browser-buffer url)))
    (cond
     ((not buffer)
      (jf/bookmark--open-url url))
     ((eq (car (read-multiple-choice
                "Bookmark is already open"
                '((?s "switch" "switch to bookmark buffer")
                  (?n "new tab" "open another tab"))))
          ?s)
      (switch-to-buffer buffer))
     (t
      (jf/bookmark--open-url url)))))

(keymap-global-set "C-x C-r" #'consult-recent-file)
(keymap-global-set "C-x C-b" #'ibuffer)
(keymap-global-set "C-x k" #'kill-current-buffer)
(keymap-global-unset "C-c p")
(keymap-global-unset "C-c b")
(keymap-global-set "C-c a" #'jf/org-agenda-dashboard)
(keymap-global-set "C-c c" #'org-capture)
(keymap-global-set "C-c t" #'jf/pomodoro)
(keymap-global-set "C-M-<return>" #'org-insert-subheading)

(add-hook 'emacs-startup-hook
          (lambda () (jf/startup-mark "emacs-startup-hook")))
(run-with-idle-timer
 0 nil
 (lambda ()
   (jf/startup-mark "first idle callback")
   (jf/startup-log-flush)))

(jf/startup-mark "init exit")
