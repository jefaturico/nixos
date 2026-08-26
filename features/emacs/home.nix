{ pkgs, ... }:

# Emacs, kept close to stock: the only things configured are the ones that
# were measured to matter, plus the font and the two bars.
#
# The pgtk build is a build choice rather than a configuration one: the
# default Emacs speaks X11 and would need Xwayland to draw at all, at the
# wrong scale and with the wrong input handling. pgtk talks to the
# compositor directly.
#
# No daemon. Mod+E starts a whole Emacs, which is the slow way and also the
# way that makes the cost of each thing added here visible.
let
  font = "JetBrainsMono Nerd Font-16"; # features/terminal's font, same size

in
{
  # early-init.el is read before the first frame is created and before
  # package.el runs, which is the only reason this file exists separately:
  # anything about frame appearance set afterwards is drawn and then undone,
  # and anything about load speed set afterwards has already missed most of
  # the loading.
  #
  # It must be under $XDG_CONFIG_HOME/emacs *and* ~/.emacs.d must not exist,
  # because `startup--xdg-or-homedot' prefers ~/.emacs.d whenever it is
  # present -- silently, with no warning that the XDG file went unread.
  xdg.configFile."emacs/early-init.el".text = ''
    ;;; early-init.el --- loaded before the first frame  -*- lexical-binding: t; -*-

    ;;; Startup ------------------------------------------------------------

    ;; NOT set here: `package-enable-at-startup nil'. Doom sets it and it
    ;; looks right under Nix -- EMACSLOADPATH already supplies the load path,
    ;; so why let package.el run? -- but it breaks this setup. Nix puts each
    ;; package's directory on `load-path' via subdirs.el and never loads its
    ;; `*-autoloads.el'; `package-activate-all' is what does that. Disable it
    ;; and every package is present but has no autoloads, so `auto-mode-alist'
    ;; entries point at functions that do not exist yet and files open in
    ;; `fundamental-mode'. Doom gets away with it because it generates its own
    ;; autoloads.

    ;; Every `load' otherwise stats the .el to see whether it is newer than
    ;; the .elc. In the store they are built together and never drift.
    (setq load-prefer-newer nil)

    ;; Garbage collection is the single measured cause of input stutter
    ;; here, so it is disabled outright for the duration of startup. It is
    ;; gcmh, enabled in default.el, that puts it back to a real value -- if
    ;; that ever stops happening this line alone will eventually freeze or
    ;; crash Emacs, which is why the two are commented as a pair.
    (setq gc-cons-threshold most-positive-fixnum
          gc-cons-percentage 1.0)

    ;; `file-name-handler-alist' is consulted on every `require' and every
    ;; file-name operation. Nothing during startup needs TRAMP or archive
    ;; handlers, so the list is emptied and put back with anything that was
    ;; added while it was empty.
    (defvar nixos-emacs--file-name-handler-alist file-name-handler-alist)
    (setq file-name-handler-alist nil)

    (add-hook 'emacs-startup-hook
              (lambda ()
                (setq file-name-handler-alist
                      (delete-dups (append file-name-handler-alist
                                           nixos-emacs--file-name-handler-alist))
                      ;; `gc-cons-threshold' is deliberately not restored
                      ;; here -- gcmh takes ownership of it from default.el,
                      ;; which has already run by this point.
                      gc-cons-percentage 0.1))
              ;; Depth 101, so this runs after anything else on the hook and
              ;; the raised threshold covers all of them.
              101)

    ;; A second, case-insensitive pass over `auto-mode-alist' for every file
    ;; opened. The rules in this configuration are correctly cased.
    (setq auto-mode-case-fold nil)

    ;;; Where Emacs writes ---------------------------------------------------

    ;; Both of these default to inside `user-emacs-directory'. They are set
    ;; here rather than in default.el because eln-cache in particular is
    ;; created early, and because ~/.emacs.d reappearing would take the whole
    ;; config directory with it.
    ;; Resolved in elisp, not interpolated by Nix: `expand-file-name' does
    ;; not expand environment variables, so a literal "$XDG_CACHE_HOME/..."
    ;; would be taken as a directory with a dollar sign in its name.
    (when (fboundp 'startup-redirect-eln-cache)
      (startup-redirect-eln-cache
       (expand-file-name "emacs/eln-cache/"
                         (or (getenv "XDG_CACHE_HOME") "~/.cache"))))

    (setq auto-save-list-file-prefix
          (expand-file-name "emacs/auto-save-list/.saves-"
                            (or (getenv "XDG_STATE_HOME") "~/.local/state")))

    ;; Warnings from byte-compiling third-party lisp are not actionable.
    (setq native-comp-async-report-warnings-errors 'silent)

    ;;; Appearance ----------------------------------------------------------

    ;; Resizing the frame to fit a font that is not the system default costs
    ;; a round trip per change at startup.
    (setq frame-inhibit-implied-resize t)

    ;; Set as frame parameters rather than by calling `menu-bar-mode' and
    ;; friends later: this way the bars are never drawn, instead of drawn and
    ;; then taken away with a frame resize in between. Same for the font --
    ;; applied at frame creation, so the frame is sized right the first time.
    (push '(font . "${font}") default-frame-alist)
    (push '(menu-bar-lines . 0) default-frame-alist)
    (push '(tool-bar-lines . 0) default-frame-alist)
    (push '(vertical-scroll-bars) default-frame-alist)
    (push '(horizontal-scroll-bars) default-frame-alist)

    ;; No fringes. Note what goes with them: the fringe is where Emacs draws
    ;; the arrow marking a wrapped line, so without one a wrapped line and a
    ;; real newline look alike. Emacs falls back to a `\' in the last column
    ;; for that, which is the old terminal convention and costs a column.
    (push '(left-fringe . 0) default-frame-alist)
    (push '(right-fringe . 0) default-frame-alist)

    (setq menu-bar-mode nil
          tool-bar-mode nil
          scroll-bar-mode nil
          horizontal-scroll-bar-mode nil)

    ;; Open on *scratch*. Note that the obvious `inhibit-startup-screen' is
    ;; deliberately useless from default.el -- startup.el binds it to nil
    ;; around that load, commented "Prevent default.el from changing the
    ;; value of `inhibit-startup-screen'" -- but early-init.el is read
    ;; outside that binding, so it works here.
    (setq inhibit-startup-screen t)
  '';

  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;

    # The one package. Everything else here is a variable Emacs already has.
    # markdown-mode, because Emacs ships no markdown mode and .md would
    # otherwise open in `fundamental-mode' -- unhighlighted, and on the code
    # side of the wrapping rule below since it derives from nothing. It lives
    # here rather than in a workflow feature because markdown is not a
    # workflow: it is the format README.md, CLAUDE.md and everything Claude
    # Code writes already happen to be in.
    extraPackages = epkgs: [
      epkgs.gcmh
      epkgs.markdown-mode
    ];

    # Runtime settings. These are the ones from Doom that survived being
    # measured on this machine, and no more: on an ordinary buffer they are
    # worth about 5% of a cursor move that already costs 0.8ms, which is
    # nothing. They are kept because they cost nothing either, and because
    # the cases they do help -- very long lines, scrolling through
    # unfontified text -- are the cases that hurt.
    #
    # Deliberately not carried from Doom: `scroll-conservatively', which
    # measured 3.7x *slower* on sustained cursor movement here because it
    # scrolls a line at a time instead of recentering; and
    # `inhibit-compacting-font-caches', which Doom's own comment admits is a
    # Windows font-rendering workaround of unproven value on Linux that
    # trades memory for it.
    extraConfig = ''
      ;;; Garbage collection -------------------------------------------------

      ;; The measured cause of input stutter. On a fontified 40k-line buffer,
      ;; 2000 cursor moves:
      ;;   800KB (the Emacs default): 14 collections, twelve moves over 16ms,
      ;;     worst 28.6ms. At a 40/s key repeat -- one repeat per 25ms --
      ;;     those are dropped frames, and they are why a held key feels
      ;;     slower here than in the terminal.
      ;;   16MB: no collections during the run, but the one that does
      ;;     eventually fire still costs 28ms.
      ;;   High threshold + collect on idle: zero collections while typing,
      ;;     worst move 9.9ms.
      ;;
      ;; gcmh rather than a hand-rolled timer, because the part that is easy
      ;; to get wrong is not raising the threshold, it is lowering it again:
      ;; gcmh drops back to 800KB *while idle* and re-raises on
      ;; `pre-command-hook', so a background process running while nobody is
      ;; typing does not get to accumulate the full high threshold in
      ;; garbage first. Settings are Doom's.
      ;;
      ;; This pairs with `gc-cons-threshold' being set to
      ;; `most-positive-fixnum' in early-init.el: that is what actually
      ;; re-enables collection after startup.
      (require 'gcmh)
      (setq gcmh-idle-delay 'auto
            gcmh-auto-idle-delay-factor 10
            gcmh-high-cons-threshold (* 64 1024 1024))
      (gcmh-mode 1)

      ;;; Redisplay ---------------------------------------------------------

      ;; Bidirectional reordering is scanned for on every line. Inhibiting
      ;; bracket-pair resolution and declaring the paragraph direction
      ;; measured 4.66ms vs 5.17ms per cursor move on 4000-character lines.
      ;; The cost is incorrect display of right-to-left text with embedded
      ;; brackets, which is not text that gets edited here.
      ;;
      ;; Note this is *not* `bidi-display-reordering', which Doom also sets
      ;; and whose own documentation calls setting it an undefined state.
      (setq bidi-inhibit-bpa t)
      (setq-default bidi-paragraph-direction 'left-to-right)

      ;; Don't draw cursors or region highlights in windows that are not
      ;; being typed in.
      (setq-default cursor-in-non-selected-windows nil)
      (setq highlight-nonselected-windows nil)

      ;; Don't adjust `window-vscroll' for tall lines, and don't fontify
      ;; while input is pending -- both trade a moment of imprecision during
      ;; fast movement for not doing the work at all.
      (setq auto-window-vscroll nil
            fast-but-imprecise-scrolling t
            redisplay-skip-fontification-on-input t)

      ;; pgtk builds wait on this before frame operations, and 0.1s is the
      ;; default. Emacs calls them without a guard because they are cheap
      ;; everywhere else.
      (when (boundp 'pgtk-wait-for-event-timeout)
        (setq pgtk-wait-for-event-timeout 0.001))

      ;;; Scrolling ---------------------------------------------------------

      ;; Pixel-precise scrolling that follows the touchpad, plus inertia
      ;; after the fingers lift. The momentum is synthesised by Emacs:
      ;; Wayland, unlike macOS, sends no momentum phase of its own, which is
      ;; also why `ultra-scroll' -- otherwise the better package -- has no
      ;; inertia here and switches this very flag off when it loads.
      ;;
      ;; Not compensated for here: niri's `scroll-factor 0.3', which Emacs
      ;; inherits like every other client, so this scrolls about a third as
      ;; far as the touchpad suggests. features/terminal multiplies it back
      ;; out for kitty with `touch_scroll_multiplier'; Emacs has no
      ;; equivalent knob, so it would take advice on the scroll handler.
      (pixel-scroll-precision-mode 1)
      (setq pixel-scroll-precision-use-momentum t)

      ;;; Not hanging -------------------------------------------------------

      ;; Insurance, not tuning: a minified file or a one-line JSON dump will
      ;; otherwise lock Emacs up hard. Built in since 27.
      (global-so-long-mode 1)

      ;; The default reads 4KB from a subprocess at a time.
      (setq read-process-output-max (* 1024 1024))

      ;; Only git is used here, and the alternative is stat'ing every opened
      ;; file against every backend Emacs knows.
      (setq vc-handled-backends '(Git))

      ;; Stops `find-file' pinging a hostname when what was typed looks like
      ;; one.
      (setq ffap-machine-p-known 'accept)

      ;;; Text area ---------------------------------------------------------

      ;; Padding around the buffer text and nothing else. Window margins are
      ;; the only thing in Emacs that sits where this is wanted: inside the
      ;; window but outside the text area, so the mode line still spans the
      ;; full width and the fringes stay out at the window edge. The obvious
      ;; alternative, an `internal-border-width' frame parameter, pads the
      ;; frame instead -- which insets the mode line and the fringes along
      ;; with the text, and is the wrong shape for the same reason a border
      ;; is not a margin.
      ;;
      ;; Two columns rather than a pixel count, because that is the only unit
      ;; margins have: 2 x 13px = 26, near enough the 24 kitty pads by. This
      ;; also means the padding scales with the font, which a fixed pixel
      ;; count would not.
      ;;
      ;; Margins are horizontal only, so the top is done below.

      (setq-default left-margin-width 2
                    right-margin-width 2)

      ;; Both of those are read when a buffer is put into a window, and
      ;; *scratch* is already sitting in one by the time this file is read.
      (add-hook 'emacs-startup-hook
                (lambda ()
                  (dolist (w (window-list))
                    (set-window-buffer w (window-buffer w)))))

      ;; Top padding, by the only route Emacs offers. There is no setting for
      ;; space above the text: `internal-border-width' pads the frame and
      ;; takes the mode line and fringes with it, and `line-spacing' goes
      ;; between lines rather than before the first one. What is left is the
      ;; header line, which is a real window element sitting exactly where
      ;; the padding is wanted -- so it is given nothing to display and made
      ;; the same colour as the buffer, and it reads as space.
      ;;
      ;; It is a default rather than a hook, so it covers every buffer; the
      ;; modes that put real content in the header line, tabulated-list-mode
      ;; and its derivatives above all, set it buffer-locally and still win.
      (setq-default header-line-format " ")

      ;; Stock `header-line' is a grey bar with a box around it, which is the
      ;; opposite of invisible. Inheriting `default' makes it the buffer's
      ;; own background, and the three explicit nils are because a box or a
      ;; rule would otherwise survive the inherit and draw a line across the
      ;; top of every window.
      (set-face-attribute 'header-line nil
                          :inherit 'default
                          :background 'unspecified
                          :foreground 'unspecified
                          :box nil
                          :underline nil
                          :overline nil)

      ;;; Wrapping ----------------------------------------------------------

      ;; Doom's defaults, and its reasoning: don't wrap by default because it
      ;; is expensive, but when something does wrap, break at a space rather
      ;; than mid-word. Code is read by scrolling; prose is read by wrapping.
      (setq-default word-wrap t
                    truncate-lines t)

      ;; Otherwise Emacs force-truncates any window under 50 columns, which
      ;; would undo the line below in a split.
      (setq truncate-partial-width-windows nil)

      ;; Prose wraps. `text-mode' is the right hook rather than `org-mode':
      ;; org derives from it through `outline-mode', and so does
      ;; `typst-ts-mode' and markdown-mode, so one line covers all three.
      (add-hook 'text-mode-hook #'visual-line-mode)

      ;; Wrapped lines carry the indentation of the line they came from, so a
      ;; continued list item stays under its own text instead of falling back
      ;; to the left edge and reading like a new item. Built in since Emacs
      ;; 30, so this costs nothing.
      (add-hook 'text-mode-hook #'visual-wrap-prefix-mode)

      ;;; Mode line ----------------------------------------------------------

      ;; The write indicator and the file name. Stock Emacs also carries the
      ;; encoding, the client, the remote and dedicated-window flags, the
      ;; frame name, the position, the project, the VC branch, the major mode
      ;; and every active minor mode -- which is how it ends up reading
      ;; "-:--- README.md All L1 Git:simplify (Markdown GCMH ElDoc Wrap)".
      ;;
      ;; No package. Every mode line package in this space -- mood-line,
      ;; simple-modeline, nano-modeline -- works by replacing this same
      ;; variable, so anything they can express is expressible here, and the
      ;; short list below is cheaper per redisplay than any of them.
      ;;
      ;; `mode-line-modified' is the write indicator: "--" saved, "**"
      ;; modified, "%%" read-only. `%e' warns when memory is nearly full and
      ;; is invisible otherwise. `mode-line-misc-info' is empty in an
      ;; ordinary buffer but is where eglot puts its connection status, so it
      ;; is kept -- dropping it would silently lose the Typst server
      ;; indicator. Add `mode-name' if the major mode turns out to be missed.
      (setq-default mode-line-format
                    '("%e" " " mode-line-modified "  "
                      mode-line-buffer-identification "  "
                      mode-line-misc-info))

      ;; Stock `mode-line' carries a `released-button' box: a 1px light edge
      ;; along the top and left and a dark one along the bottom and right,
      ;; faking a raised 3D button. It is also what shows as a stray pixel
      ;; between the mode line and the window edge, since the bevel wraps all
      ;; four sides rather than only the top and bottom.
      ;;
      ;; Only the box is touched here. The colours are stock light-theme
      ;; greys and are left alone deliberately, because they are about to be
      ;; a theme's business rather than this file's.
      (set-face-attribute 'mode-line nil :box nil)
      (set-face-attribute 'mode-line-inactive nil :box nil)

      ;;; Mouse menus -------------------------------------------------------

      ;; Right-click on its own is `mouse-save-then-kill', not a menu, and
      ;; `context-menu-mode' is off in stock Emacs already. These three are
      ;; the pop-up menus that do exist -- and with the menu bar gone,
      ;; C-mouse-3 grows into a copy of the whole thing.
      (keymap-global-unset "C-<down-mouse-1>")   ; buffer list
      (keymap-global-unset "C-<down-mouse-3>")   ; major-mode menu
      (keymap-global-unset "S-<down-mouse-1>")   ; font and colour menu
    '';
  };
}
