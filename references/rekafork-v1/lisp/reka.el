;;; -*- lexical-binding: t -*-
;;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'libreka)
(require 'cl-lib)
(require 'seq)

(defgroup reka nil
  "Reka - Emacs swimming in the river"
  :group 'environment
  :prefix "reka-")

(defvar reka-handle nil
  "Opaque handle for interacting with the WM")

(defvar reka--event-process nil
  "Pipe process used to receive commands from the native Reka module.")

(defcustom reka-enable-hook nil
  "Hook run at the end of `reka-enable'."
  :type 'hook)

(defcustom reka-input-repeat-rate 60
  "Keyboard repeat rate configured through River."
  :type 'integer)

(defcustom reka-input-repeat-delay 200
  "Keyboard repeat delay in milliseconds configured through River."
  :type 'integer)

(defcustom reka-touchpad-accel-speed 0.3
  "Touchpad acceleration speed configured through River/libinput."
  :type 'number)

(defcustom reka-mouse-accel-speed 0.0
  "Mouse acceleration speed configured through River/libinput."
  :type 'number)

(defcustom reka-touchpad-tap t
  "Whether tap-to-click is enabled on touchpads."
  :type 'boolean)

(defcustom reka-touchpad-natural-scroll t
  "Whether natural scrolling is enabled on touchpads."
  :type 'boolean)

(defcustom reka-touchpad-disable-while-typing t
  "Whether touchpads are disabled while typing."
  :type 'boolean)

(defcustom reka-touchpad-disable-while-trackpointing t
  "Whether touchpads are disabled while using a trackpoint."
  :type 'boolean)

(defcustom reka-touchpad-drag-lock t
  "Whether sticky drag lock is enabled on touchpads."
  :type 'boolean)

(defcustom reka-touchpad-two-finger-scroll t
  "Whether two-finger scrolling is enabled on touchpads."
  :type 'boolean)

(defcustom reka-touchpad-accel-profile "adaptive"
  "Acceleration profile used for touchpads."
  :type '(choice (const "adaptive") (const "flat")))

(defcustom reka-mouse-accel-profile "flat"
  "Acceleration profile used for mice."
  :type '(choice (const "adaptive") (const "flat")))

(defun reka-apply-input-config ()
  "Apply `reka-' input settings to River."
  (interactive)
  (unless reka-handle
    (user-error "Reka is not enabled"))
  (reka-configure-input reka-handle
                        reka-input-repeat-rate
                        reka-input-repeat-delay
                        reka-touchpad-accel-speed
                        reka-mouse-accel-speed
                        reka-touchpad-tap
                        reka-touchpad-natural-scroll
                        reka-touchpad-disable-while-typing
                        reka-touchpad-disable-while-trackpointing
                        reka-touchpad-drag-lock
                        reka-touchpad-two-finger-scroll
                        reka-touchpad-accel-profile
                        reka-mouse-accel-profile))

(defun reka--set-frame-name (frame)
  (unless (string-prefix-p "reka-frame-"
                           (frame-parameter frame 'name))
    (set-frame-parameter frame 'name (make-temp-name "reka-frame-"))))

(defun reka--ensure-frame-names ()
  "Ensure each frame has a unique title that reka can match to its window."
  (cl-loop for frame being the frames
           do (reka--set-frame-name frame)))

(defun reka--find-buffer-for-window (window)
  (seq-find (lambda (buf)
              (when-let* ((w (buffer-local-value 'reka-window buf)))
                (reka-window-equal w window)))
            (reka--list-buffers)))

(defvar reka--layout-dirty t
  "Non-nil when Emacs window geometry must be sent to River.")

(defvar reka--sync-timer nil
  "Pending timer used to coalesce layout and focus synchronization.")

(defvar reka--command-handler-scheduled nil
  "Non-nil while a native-command drain has already been scheduled.")

(defvar reka--last-focus-target :unset
  "Last Wayland window reported to the native Reka module.")

(defun reka--schedule-sync (&rest _)
  "Schedule one synchronization after the current Emacs activity settles."
  (unless (timerp reka--sync-timer)
    (setq reka--sync-timer
          (run-at-time 0 nil #'reka--run-scheduled-sync))))

(defun reka--run-scheduled-sync ()
  "Publish the latest stable layout and focus state."
  (setq reka--sync-timer nil)
  (when reka-handle
    (condition-case err
        (progn
          (reka--sync-layout)
          (reka--update-focus-request))
      (error
       (setq reka--layout-dirty t
             reka--last-focus-target :unset)
       (message "reka: state synchronization failed: %s" err)))))

(defun reka--mark-layout-dirty (&rest _)
  "Record that the Emacs window layout changed.

The actual update is deferred until after the current command.  Window
configuration hooks can run while a command is only part-way through changing
the layout; sending geometry from the hook would expose the previous layout to
  River for one input event."
  (setq reka--layout-dirty t)
  (reka--schedule-sync))

(defun reka--sync-layout ()
  "Send the completed Emacs window layout to the native module."
  (when (and reka-handle reka--layout-dirty)
    (setq reka--layout-dirty nil)
    (condition-case err
        (reka-update-window-parameters
         reka-handle (reka--all-window-parameters))
      (error
       ;; Retain the dirty bit so a transient frame/window teardown race is
       ;; retried after the next command instead of leaving River stale.
       (setq reka--layout-dirty t)
       (message "reka: could not update window layout: %s" err)))))

(defun reka--post-command-sync ()
  "Publish completed layout and focus changes after each command."
  (reka--schedule-sync))

(defvar-local reka-app-id nil)
(defvar-local reka-title nil)
(defvar-local reka--closed-by-wm nil
  "Non-nil while killing this buffer because River reported its window closed.")

(defcustom reka-window-closed-functions nil
  "Abnormal hook run with a Reka buffer whose River window closed.
Functions should accept one argument, the buffer being closed.  If a function
kills the buffer, Reka will not run its default close fallback."
  :type 'hook
  :group 'reka)

(defun reka--make-buffer-name (app-id title)
  (let ((title-trunc (if (> (length title) 40)
                         (format "%s…" (substring title 0 40))
                       title)))
    (if app-id (concat title-trunc " - " app-id)
      title-trunc)))

(defun reka--handle-commands ()
  (interactive)

  ;; The process filter only schedules this function, and
  ;; `reka--command-handler-scheduled' coalesces notifications. Emacs executes
  ;; this body serially, so an additional mutex adds no protection.
  (setq reka--last-focus-target :unset)

    (while-let ((cmd (reka-get-next-command reka-handle)))
      (pcase cmd
        (`(key-event . ,key)
         (push (cons t key) unread-command-events))

        (`(new-window . ,window)
         (let ((buffer (reka--create-buffer window)))
           ;; River must not be left in WindowState::Starting merely because
           ;; an Emacs display rule or advice failed. Activate the native
           ;; window once its backing buffer exists, then attempt placement.
           (reka-notify-buffer-created reka-handle window)
           (condition-case err
               (display-buffer buffer)
             (error
              (message "reka: could not display new window buffer: %s" err)))
           (reka--mark-layout-dirty)))

        (`(window-closed . ,window)
         (when-let* ((buf (reka--find-buffer-for-window window)))
           (reka--kill-closed-buffer buf)))

        (`(minimize-requested . ,window)
         (when-let* ((buf (reka--find-buffer-for-window window)))
           (with-current-buffer buf
             (bury-buffer))))

        (`(focused . ,window)
         (when-let* ((buf (reka--find-buffer-for-window window))
                     (win (get-buffer-window buf t)))
           (select-window win 'norecord)))

        (`(fatal-error . ,message)
         (reka-disable)
         (error "reka native window manager stopped: %s" message))

        (`(app-id-change ,window ,app-id)
         (when-let* ((buf (reka--find-buffer-for-window window)))
           (with-current-buffer buf
             (setq reka-app-id app-id))))

        (`(title-change ,window ,title)
         (when-let* ((buf (reka--find-buffer-for-window window)))
           (with-current-buffer buf
             (setq reka-title title)
             (rename-buffer (reka--make-buffer-name reka-app-id title) t))))

        ('frame-request (make-frame))

        (`(discard-frame . ,frame-name)
         (when-let* ((frame-names (make-frame-names-alist))
                     (frame (alist-get frame-name frame-names nil nil #'equal)))
           (delete-frame frame)))

        (`(message . ,msg)
         (message "reka: %s" msg))

        (_ (message "reka: ignoring unknown native command: %s" cmd))))

    ;; Commands above may display, bury, select, or destroy windows.  Snapshot
    ;; geometry afterwards so the native side never receives the layout from
    ;; immediately before the event it is handling.
  (reka--sync-layout)
  (reka--schedule-sync))

(defun reka--handle-event (&rest _) ;; unused process filter args
  (when (and reka-handle (not reka--command-handler-scheduled))
    (setq reka--command-handler-scheduled t)
    (run-at-time 0 nil #'reka--run-command-handler)))

(defun reka--run-command-handler ()
  "Drain native commands once for any number of pipe notifications."
  (setq reka--command-handler-scheduled nil)
  (when reka-handle
    (condition-case err
        (reka--handle-commands)
      (error (message "reka: command handler failed: %s" err)))))

;; Major mode for reka-managed buffers
(defvar-local reka-window nil
  "Window object for this reka-mode buffer.")

(defun reka--buffer-killed ()
  (when (and reka-window
             (not reka--closed-by-wm))
    (reka-close-window reka-handle reka-window)))

(define-derived-mode reka-mode special-mode "Reka"
  "Major mode for buffers representing windows managed by reka."
  :group 'reka
  (setq-local buffer-read-only t)
  (add-hook 'kill-buffer-hook #'reka--buffer-killed nil t)
  (scroll-bar-mode 0)
  (setq-local left-fringe-width 0
              right-fringe-width 0))

(defun reka--is-reka-buffer (buf)
  (with-current-buffer buf
    (eq major-mode 'reka-mode)))

(defun reka--get-window (buffer)
  (buffer-local-value 'reka-window buffer))

(defun reka--list-buffers ()
  (apply #'vector (seq-filter #'reka--is-reka-buffer (buffer-list))))

(defun reka--delete-buffer-windows (buffer)
  "Delete live Emacs windows currently displaying BUFFER."
  (dolist (window (get-buffer-window-list buffer nil t))
    (when (window-live-p window)
      (with-selected-window window
        (unless (one-window-p t)
          (delete-window window))))))

(defun reka--kill-closed-buffer (buffer)
  "Kill BUFFER after its River window closed, cleaning up visible panes."
  (with-current-buffer buffer
    (setq reka--closed-by-wm t))
  (condition-case err
      (run-hook-with-args 'reka-window-closed-functions buffer)
    (error
     (message "reka: window close hook failed: %s" err)))
  (when (buffer-live-p buffer)
    (reka--delete-buffer-windows buffer)
    (kill-buffer buffer)))

(defun reka--window-parameters (frame window)
  (let ((edges (window-inside-absolute-pixel-edges window)))
    (reka-make-window-parameters
     (buffer-local-value 'reka-window (window-buffer window))
     frame
     (nth 0 edges)
     (nth 1 edges)
     (- (nth 2 edges) (nth 0 edges))
     (- (nth 3 edges) (nth 1 edges)))))

(defun reka--all-window-parameters ()
  (let ((windows-by-frame
         (cl-loop for frame being the frames
                  collect (cons (frame-parameter frame 'name)
                                (seq-filter (lambda (window)
                                              (reka--is-reka-buffer (window-buffer window)))
                                            (window-list frame))))))
    (apply #'vector
           (seq-map (lambda (elem)
                      (let ((frame-name (car elem))
                            (windows (cdr elem)))
                        (apply #'vector
                               (seq-map (lambda (w) (reka--window-parameters frame-name w))
                                        windows))))
                    windows-by-frame))))

(defun reka--create-buffer (window)
  (let ((buffer (get-buffer-create (make-temp-name "reka-window-"))))
    (with-current-buffer buffer
      (reka-mode)
      (setq-local reka-window window))
    buffer))

(defun reka--update-focus-request (&rest _) ;; TODO: take & forward frame for active output logic
  "Send a focus request to the WM reflecting the current selected-window."
  (when reka-handle
    (let* ((win (selected-window))
           (buf (window-buffer win))
           ;; Timers invoke this after interactive command state has settled.
           (can-focus-window (and (reka--is-reka-buffer buf) ;; only focus wayland surfaces
                                  (not this-command) ;; not in an interactive command
                                  (= 0 (length unread-command-events)) ;; no pending key injections
                                  (= 0 (minibuffer-depth)) ;; no minibuffer editing active
                                  (= 0 (recursion-depth)))) ;; no recursive edit ongoing
           (target (when can-focus-window
                     (buffer-local-value 'reka-window buf))))
      (unless (if (and target
                       (not (memq reka--last-focus-target '(:frame :unset))))
                  (and reka--last-focus-target
                       (reka-window-equal target reka--last-focus-target))
                ;; Frame focus is intentionally never cached. River can move
                ;; focus back to a surface without an Emacs selection change.
                nil)
        (setq reka--last-focus-target (or target :frame))
        (reka-set-focus-request reka-handle target)))))

(defun reka--focus-frame-now (&rest _)
  "Synchronously route keyboard input to Emacs for the minibuffer."
  (when reka-handle
    (setq reka--last-focus-target :frame)
    (condition-case err
        (reka-set-focus-request reka-handle nil)
      (error (message "reka: could not focus Emacs frame: %s" err)))))

(defconst reka--modifier-bits
  ;; TODO: can we handle this with XKB on the rust side, too?
  '((shift   . 1)
    (control . 4)
    (meta    . 8)
    (super   . 64)
    (hyper   . 128))
  "Modifier bits as per river_seat_v1.modifiers / XKB")

(defconst reka--xkb-key-name-overrides
  '(("backspace" . "BackSpace")
    ("delete" . "Delete")
    ("down" . "Down")
    ("end" . "End")
    ("escape" . "Escape")
    ("home" . "Home")
    ("insert" . "Insert")
    ("left" . "Left")
    ("next" . "Next")
    ("prior" . "Prior")
    ("poweroff" . "XF86PowerOff")
    ("return" . "Return")
    ("right" . "Right")
    ("tab" . "Tab")
    ("up" . "Up"))
  "Map Emacs symbolic event names to canonical XKB keysym names.")

(defun reka--event-key-name (event basic)
  "Return an XKB-compatible key name for symbolic EVENT with BASIC type."
  (let* ((name (symbol-name (or basic event)))
         (unmodified-name (replace-regexp-in-string
                           "\\`\\(?:A-\\|C-\\|H-\\|M-\\|S-\\|s-\\)+"
                           ""
                           name)))
    (or (alist-get (downcase unmodified-name)
                   reka--xkb-key-name-overrides nil nil #'equal)
        unmodified-name)))

(defun reka--key-to-xkb (key-string)
  "Decomposes an Emacs key-string (e.g. `C-x') into (event key modifiers).
The Rust side resolves the keysyms using xkbcommon."
  (let* ((event (aref (kbd key-string) 0))
         (basic (event-basic-type event))
         (mods (seq-map (lambda (mod) (alist-get mod reka--modifier-bits))
                        (event-modifiers event)))
         (key (if (characterp basic) basic (reka--event-key-name event basic))))
    (list event key (apply #'logior mods))))

(defun reka-push-intercept-prefix (prefix &optional command)
  "Register PREFIX (in the format as expected by `kbd') as an intercept key
binding, meaning that it is always forwarded to Emacs. Use this in
combination with `global-set-key' to define global key bindings that are
always sent to Emacs.

Can optionally set COMMAND to one of: `toggle-fullscreen'" ;; sic, only one
  (let ((data (reka--key-to-xkb prefix)))
    (reka-register-xkb-prefix reka-handle (if (integerp (car data))
                                              (car data)
                                            (symbol-name (car data)))
                              (cadr data) (caddr data) command)))

(defun reka-push-intercept-prefixes () ;; TODO: remove, leave only one way?
  "Update the intercept prefixes defined in `reka-intercept-prefixes'."
  (dolist (prefix reka-intercept-prefixes)
    (condition-case err
        (reka-push-intercept-prefix prefix)
      (error
       (message "reka: could not register intercept %s: %s" prefix err)))))

(defcustom reka-intercept-prefixes
  '("C-x" "C-u" "C-h" "M-x")
  "Prefix keys that should always go to Emacs."
  :type '(repeat key)
  :set (lambda (sym val)
         (set-default sym val)
         (when reka-handle (reka-push-intercept-prefixes))))

(defun reka--suppress-focus-event (_orig-fn _event)
  "No-op for suppressing certain focus events in advice."
  (interactive "e")
  ;; okay, *almost* no-op ...
  (setq reka--last-focus-target :unset)
  (reka--schedule-sync))

(defun reka--buffer-predicate (buffer)
  "Buffer predicate to avoid accidentally showing the same reka buffer twice."
  (or (not (with-current-buffer buffer (derived-mode-p 'reka-mode)))
      (not (get-buffer-window buffer t))))

(defun reka--split-window-advice (new-window)
  "Advice window splits to always display another buffer, if a reka buffer
was split."
  (with-selected-window new-window
    (with-current-buffer (window-buffer)
      (when (derived-mode-p 'reka-mode)
        (switch-to-buffer (other-buffer)))))
  new-window)

(defun reka--set-window-buffer-advice (orig win buf &rest r)
  "Avoid double-display of reka buffers, by stealing them if they are
visible elsewhere. Note that displaying the same buffer in two different
tabs, for example, is completely valid."
  (with-current-buffer buf
    (when (derived-mode-p 'reka-mode)
      (dolist (other (get-buffer-window-list buf nil 'visible))
        (unless (equal (or win (selected-window)) other)
          (with-selected-window other
            (switch-to-buffer (other-buffer)))))))

  (apply orig win buf r))

(defun reka-enable ()
  "Enable the reka window manager for river. Call this function once when
starting Emacs inside of river."
  (if reka-handle
      (message "Reka is already enabled")
    (condition-case err
        (progn
          ;; TODO: this is a hack for lack of ability to figure out alignment ...
          (menu-bar-mode 0)
          (tool-bar-mode 0)

          ;; Configure this and all future frames.
          (let ((frame-params '((undecorated . t)
                                (buffer-predicate . reka--buffer-predicate))))
            (modify-all-frames-parameters frame-params))

          (advice-add 'split-window-below :filter-return #'reka--split-window-advice)
          (advice-add 'split-window-right :filter-return #'reka--split-window-advice)
          (advice-add 'set-window-buffer :around #'reka--set-window-buffer-advice)

          (message "Launching native module ...")
          (reka--ensure-frame-names)
          (add-to-list 'after-make-frame-functions #'reka--set-frame-name)
          (setq reka--event-process
                (make-pipe-process :name "reka-events"
                                   :buffer " *reka-events*"
                                   :filter #'reka--handle-event
                                   :noquery t))
          (setq reka-handle (reka-start-wm reka--event-process))
          (reka-apply-input-config)
          (reka-push-intercept-prefixes)

          ;; Layout signals
          (add-hook 'window-configuration-change-hook #'reka--mark-layout-dirty)

          ;; Focus signals
          (add-hook 'window-selection-change-functions #'reka--schedule-sync)
          (add-hook 'window-buffer-change-functions    #'reka--mark-layout-dirty)
          (add-hook 'minibuffer-setup-hook             #'reka--focus-frame-now)
          (add-hook 'minibuffer-exit-hook              #'reka--schedule-sync)
          (add-hook 'tab-bar-tab-post-select-functions #'reka--mark-layout-dirty)
          (add-hook 'post-command-hook                 #'reka--post-command-sync)

          ;; Suppress pgtk focus feedback loop (as does EXWM).
          (advice-add 'handle-focus-in  :around #'reka--suppress-focus-event)
          (advice-add 'handle-focus-out :around #'reka--suppress-focus-event)

          (run-hooks 'reka-enable-hook))
      (error
       ;; Startup is all-or-nothing. In particular, do not leave global advice
       ;; installed if native startup or user configuration fails.
       (reka-disable)
       (signal (car err) (cdr err))))))

(defun reka-disable ()
  "Disable Reka and remove all global hooks and advice it installed."
  (interactive)
  (when reka-handle
    (ignore-errors (reka-stop-wm reka-handle)))
  (setq reka-handle nil
        reka--last-focus-target :unset
        reka--layout-dirty t
        reka--command-handler-scheduled nil)
  (when (timerp reka--sync-timer)
    (cancel-timer reka--sync-timer))
  (setq reka--sync-timer nil)
  (when (process-live-p reka--event-process)
    (delete-process reka--event-process))
  (setq reka--event-process nil)
  (remove-hook 'after-make-frame-functions #'reka--set-frame-name)
  (remove-hook 'window-configuration-change-hook #'reka--mark-layout-dirty)
  (remove-hook 'window-selection-change-functions #'reka--schedule-sync)
  (remove-hook 'window-buffer-change-functions #'reka--mark-layout-dirty)
  (remove-hook 'minibuffer-setup-hook #'reka--focus-frame-now)
  (remove-hook 'minibuffer-exit-hook #'reka--schedule-sync)
  (remove-hook 'tab-bar-tab-post-select-functions #'reka--mark-layout-dirty)
  (remove-hook 'post-command-hook #'reka--post-command-sync)
  (advice-remove 'split-window-below #'reka--split-window-advice)
  (advice-remove 'split-window-right #'reka--split-window-advice)
  (advice-remove 'set-window-buffer #'reka--set-window-buffer-advice)
  (advice-remove 'handle-focus-in #'reka--suppress-focus-event)
  (advice-remove 'handle-focus-out #'reka--suppress-focus-event)
  (message "Reka disabled"))

(provide 'reka)
