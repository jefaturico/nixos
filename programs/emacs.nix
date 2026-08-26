{ ... }:

{
  home-manager.users.jefaturico =
    { pkgs, ... }:

    let
      font = "JetBrainsMono Nerd Font-16";

    in
    {
      # early-init.el must live under $XDG_CONFIG_HOME/emacs AND ~/.emacs.d must not
      # exist -- startup--xdg-or-homedot silently prefers ~/.emacs.d if present.
      xdg.configFile."emacs/early-init.el".text = ''
        ;;; early-init.el --- loaded before the first frame  -*- lexical-binding: t; -*-

        ;;; Startup ------------------------------------------------------------

        ;; NOT set here: `package-enable-at-startup nil'. Under Nix, disabling it
        ;; leaves every package's directory on `load-path' via subdirs.el but skips
        ;; `package-activate-all', so no `*-autoloads.el' get loaded and
        ;; auto-mode-alist entries point at undefined functions.
        (setq load-prefer-newer nil)

        ;; gcmh (enabled in default.el) is what restores this after startup; if
        ;; that ever stops happening, Emacs will eventually freeze or crash.
        (setq gc-cons-threshold most-positive-fixnum
              gc-cons-percentage 1.0)

        (defvar nixos-emacs--file-name-handler-alist file-name-handler-alist)
        (setq file-name-handler-alist nil)

        (add-hook 'emacs-startup-hook
                  (lambda ()
                    (setq file-name-handler-alist
                          (delete-dups (append file-name-handler-alist
                                               nixos-emacs--file-name-handler-alist))
                          gc-cons-percentage 0.1))
                  101)

        (setq auto-mode-case-fold nil)

        ;;; Where Emacs writes ---------------------------------------------------

        ;; `expand-file-name' does not expand env vars, so $XDG_CACHE_HOME must be
        ;; read via `getenv' rather than interpolated as a literal path string.
        (when (fboundp 'startup-redirect-eln-cache)
          (startup-redirect-eln-cache
           (expand-file-name "emacs/eln-cache/"
                             (or (getenv "XDG_CACHE_HOME") "~/.cache"))))

        (setq auto-save-list-file-prefix
              (expand-file-name "emacs/auto-save-list/.saves-"
                                (or (getenv "XDG_STATE_HOME") "~/.local/state")))

        (setq native-comp-async-report-warnings-errors 'silent)

        ;;; Appearance ----------------------------------------------------------

        (setq frame-inhibit-implied-resize t)

        (push '(font . "${font}") default-frame-alist)
        (push '(menu-bar-lines . 0) default-frame-alist)
        (push '(tool-bar-lines . 0) default-frame-alist)
        (push '(vertical-scroll-bars) default-frame-alist)
        (push '(horizontal-scroll-bars) default-frame-alist)
        (push '(left-fringe . 0) default-frame-alist)
        (push '(right-fringe . 0) default-frame-alist)

        (setq menu-bar-mode nil
              tool-bar-mode nil
              scroll-bar-mode nil
              horizontal-scroll-bar-mode nil)

        ;; `inhibit-startup-screen' set later has no effect: startup.el binds it
        ;; to nil around default.el's load. early-init.el runs outside that bind.
        (setq inhibit-startup-screen t)
      '';

      home.packages = [
        (pkgs.texliveSmall.withPackages (ps: [
          ps.capt-of
          ps.dvisvgm
          ps.ulem
          ps.wrapfig
        ]))
        pkgs.wl-clipboard
      ];

      programs.emacs = {
        enable = true;
        package = pkgs.emacs-pgtk;

        # ELPA org 9.8.3 (pulled in by org-srs) precedes the 9.7 bundled with
        # Emacs 30 on load-path, so it is the org that actually runs.
        extraPackages = epkgs: [
          epkgs.gcmh
          epkgs.markdown-mode
          epkgs.nix-ts-mode
          epkgs.orderless
          epkgs.org-download
          epkgs.org-fragtog
          epkgs.org-roam
          epkgs.org-srs
          epkgs.vertico
          (epkgs.treesit-grammars.with-grammars (grammars: [ grammars.tree-sitter-nix ]))
        ];

        extraConfig = ''
          ;;; Garbage collection -------------------------------------------------

          ;; Measured on a fontified 40k-line buffer, 2000 cursor moves: default
          ;; 800KB threshold drops frames (worst move 28.6ms); high threshold +
          ;; collect-on-idle via gcmh gets worst move down to 9.9ms.
          (require 'gcmh)
          (setq gcmh-idle-delay 'auto
                gcmh-auto-idle-delay-factor 10
                gcmh-high-cons-threshold (* 64 1024 1024))
          (gcmh-mode 1)

          ;;; Modes ---------------------------------------------------------------

          ;; nix-ts-mode's autoloads don't wire up the extension, unlike markdown-mode's.
          (add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-ts-mode))

          ;;; Minibuffer completion -----------------------------------------------

          (require 'vertico)
          (vertico-mode 1)

          ;; `basic' stays as fallback: some completion tables (notably TRAMP)
          ;; only behave under it.
          (setq completion-styles '(orderless basic))

          (setq completion-category-overrides
                '((file (styles basic partial-completion))))

          ;;; Redisplay ---------------------------------------------------------

          ;; Measured 4.66ms vs 5.17ms per cursor move on 4000-char lines. Costs
          ;; correct display of RTL text with embedded brackets.
          ;; Not `bidi-display-reordering' -- its own docs call that undefined.
          (setq bidi-inhibit-bpa t)
          (setq-default bidi-paragraph-direction 'left-to-right)

          (setq-default cursor-in-non-selected-windows nil)
          (setq highlight-nonselected-windows nil)

          (setq auto-window-vscroll nil
                fast-but-imprecise-scrolling t
                redisplay-skip-fontification-on-input t)

          ;; pgtk builds wait 0.1s (default) before frame operations.
          (when (boundp 'pgtk-wait-for-event-timeout)
            (setq pgtk-wait-for-event-timeout 0.001))

          ;;; Scrolling ---------------------------------------------------------

          ;; Momentum is synthesised by Emacs: Wayland sends no momentum phase of
          ;; its own (unlike macOS).
          (pixel-scroll-precision-mode 1)
          (setq pixel-scroll-precision-use-momentum t)

          ;; niri's `scroll-factor 0.3' cuts touchpad scroll to about a third;
          ;; programs/kitty.nix compensates for kitty via touch_scroll_multiplier,
          ;; but Emacs has no equivalent knob.
          ;;; Not hanging -------------------------------------------------------

          (global-so-long-mode 1)
          (setq read-process-output-max (* 1024 1024))
          (setq vc-handled-backends '(Git))
          (setq ffap-machine-p-known 'accept)

          ;;; Text area ---------------------------------------------------------

          ;; Window margins, not `internal-border-width': the latter insets the
          ;; mode line and fringes along with the text. 2 columns ~= 26px, close
          ;; to kitty's 24px padding, and scales with the font.
          (setq-default left-margin-width 2
                        right-margin-width 2)

          ;; vertico draws its candidate list in the minibuffer; margins there
          ;; read as a floating box instead of a list at the frame edge.
          (add-hook 'minibuffer-setup-hook
                    (lambda ()
                      (setq-local left-margin-width 0
                                  right-margin-width 0)
                      (set-window-margins (minibuffer-window) 0 0)))

          ;; Echo area buffers also inherit the default margins.
          (dolist (buf '(" *Echo Area 0*" " *Echo Area 1*"))
            (with-current-buffer (get-buffer-create buf)
              (setq-local left-margin-width 0
                          right-margin-width 0)))

          ;; *scratch* is already in a window by the time this runs, so margins
          ;; need to be reapplied by re-setting each window's buffer.
          (add-hook 'emacs-startup-hook
                    (lambda ()
                      (dolist (w (window-list))
                        (set-window-buffer w (window-buffer w)))))

          ;; Top padding via the header line: no other setting pads above the
          ;; text (`internal-border-width' pads the frame, `line-spacing' goes
          ;; between lines). Given nothing to display and the buffer's own
          ;; colour, it reads as space. Modes with real header-line content
          ;; (tabulated-list-mode etc.) set it buffer-locally and still win.
          (setq-default header-line-format " ")

          (set-face-attribute 'header-line nil
                              :inherit 'default
                              :background 'unspecified
                              :foreground 'unspecified
                              :box nil
                              :underline nil
                              :overline nil)

          ;;; Wrapping ----------------------------------------------------------

          (setq-default word-wrap t
                        truncate-lines t)

          ;; Otherwise Emacs force-truncates any window under 50 columns.
          (setq truncate-partial-width-windows nil)

          ;; `text-mode' covers org, typst-ts-mode and markdown-mode (all derive
          ;; from it via outline-mode), so one hook covers all three.
          (add-hook 'text-mode-hook #'visual-line-mode)
          (add-hook 'text-mode-hook #'visual-wrap-prefix-mode)

          ;;; Mode line ----------------------------------------------------------

          ;; `mode-line-misc-info' is where eglot puts connection status --
          ;; dropping it would silently lose the Typst server indicator.
          (setq-default mode-line-format
                        '("%e" " " mode-line-modified "  "
                          mode-line-buffer-identification "  "
                          mode-line-misc-info))

          (set-face-attribute 'mode-line nil :box nil)
          (set-face-attribute 'mode-line-inactive nil :box nil)

          ;;; Org -----------------------------------------------------------------

          (setq org-directory "~/documents/org")

          ;; inbox.org deliberately excluded: it's the unsorted pile.
          (setq org-agenda-files (list (expand-file-name "agenda.org" org-directory)))

          (setq org-capture-templates
                '(("i" "Inbox" entry (file "inbox.org")
                   "* %?")
                  ("e" "Event" entry (file+headline "agenda.org" "Events")
                   "* %?")
                  ("t" "Task" entry (file+headline "agenda.org" "Tasks")
                   "* TODO %?")))

          (keymap-global-set "C-c c" #'org-capture)
          (keymap-global-set "C-c a" #'org-agenda)

          ;;; Org: roam -------------------------------------------------------------

          (setq org-roam-directory (expand-file-name "roam" org-directory)
                org-roam-completion-everywhere t)
          (make-directory org-roam-directory t)

          (with-eval-after-load 'org
            (require 'org-roam)
            (org-roam-db-autosync-mode +1))

          (keymap-global-set "C-c n f" #'org-roam-node-find)
          (keymap-global-set "C-c n i" #'org-roam-node-insert)
          (keymap-global-set "C-c n l" #'org-roam-buffer-toggle)

          ;;; Org: rendering ------------------------------------------------------

          ;; TODO(2026-08): org-latex-preview.el (async rewrite) is still
          ;; unmerged upstream. When it ships, drop org-fragtog and the
          ;; centering advice below and enable org-latex-preview-auto-mode.
          (setq org-preview-latex-default-process 'dvisvgm)
          (setq org-startup-with-latex-preview t)

          (setq org-startup-with-link-previews t)
          (setq org-image-align 'center)
          (setq org-image-actual-width '(0.5))

          (with-eval-after-load 'org
            ;; Tuned by eye against the 16pt buffer font, not derived.
            (plist-put org-format-latex-options :scale 1.6)
            (plist-put org-format-latex-options :foreground 'default)
            (plist-put org-format-latex-options :background "Transparent")

            ;; Shipped preview system left-aligns every fragment; this reuses
            ;; org-link-preview-file's centered-image display spec for any
            ;; fragment on its own line.
            ;; Not fixed: inline fragments sit a few px low, because org
            ;; hard-codes :ascent center. The real fix needs per-fragment depth
            ;; below baseline, which org-latex-preview (see TODO above) computes.
            (defun nixos-emacs--org-center-latex-preview (beg end _image &optional _imagetype)
              (when (save-excursion
                      (and (progn (goto-char beg)
                                  (skip-chars-backward " \t")
                                  (bolp))
                           (progn (goto-char end)
                                  (skip-chars-forward " \t")
                                  (eolp))))
                (dolist (ov (overlays-in beg end))
                  (when (eq (overlay-get ov 'org-overlay-type) 'org-latex-overlay)
                    (let ((img (overlay-get ov 'display)))
                      (when img
                        (overlay-put ov 'before-string
                                     (propertize " " 'face 'default 'display
                                                 `(space :align-to (- center (0.5 . ,img)))))))))))
            (advice-add 'org--make-preview-overlay :after #'nixos-emacs--org-center-latex-preview))

          (add-hook 'org-mode-hook #'org-fragtog-mode)

          ;; org-link-preview--get-overlays is private API, but it's the same
          ;; probe org-link-preview-clear itself uses.
          (defvar-local nixos-emacs--org-image-hidden-line nil)
          (defun nixos-emacs--org-image-collapse-update ()
            (ignore-errors
              (pcase nixos-emacs--org-image-hidden-line
                (`(,beg . ,end)
                 (unless (<= beg (point) end)
                   (org-link-preview-region nil nil beg end)
                   (set-marker beg nil)
                   (set-marker end nil)
                   (setq nixos-emacs--org-image-hidden-line nil))))
              (unless nixos-emacs--org-image-hidden-line
                (let ((beg (pos-bol))
                      (end (pos-eol)))
                  (when (org-link-preview--get-overlays beg end)
                    (org-link-preview-clear beg end)
                    (setq nixos-emacs--org-image-hidden-line
                          (cons (copy-marker beg) (copy-marker end t))))))))
          (add-hook 'org-mode-hook
                    (lambda ()
                      (add-hook 'post-command-hook
                                #'nixos-emacs--org-image-collapse-update nil t)))

          (setq org-download-method 'directory
                org-download-image-dir (expand-file-name "images" org-directory))
          (with-eval-after-load 'org
            (require 'org-download)
            (org-download-enable)
            (keymap-set org-mode-map "C-c y" #'org-download-clipboard))

          ;;; Flashcards ----------------------------------------------------------

          (keymap-global-set "C-c s n" #'org-srs-item-create)
          (keymap-global-set "C-c s r" #'org-srs-review-start)
          (keymap-global-set "C-c s q" #'org-srs-review-quit)
          (keymap-global-set "C-c s 1" #'org-srs-review-rate-again)
          (keymap-global-set "C-c s 2" #'org-srs-review-rate-hard)
          (keymap-global-set "C-c s 3" #'org-srs-review-rate-good)
          (keymap-global-set "C-c s 4" #'org-srs-review-rate-easy)

          ;;; Mouse menus -------------------------------------------------------

          (keymap-global-unset "C-<down-mouse-1>")   ; buffer list
          (keymap-global-unset "C-<down-mouse-3>")   ; major-mode menu
          (keymap-global-unset "S-<down-mouse-1>")   ; font and colour menu
        '';
      };
    };
}
