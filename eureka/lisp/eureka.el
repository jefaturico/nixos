;;; -*- lexical-binding: t -*-
;;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'libeureka)
(require 'cl-lib)
(require 'seq)

(defgroup eureka nil
  "Eureka - Emacs swimming in the river"
  :group 'environment
  :prefix "eureka-")

(defvar eureka-handle nil
  "Opaque handle for interacting with the WM")

(defvar eureka--event-process nil
  "Pipe process used to receive commands from the native Eureka module.")

(defvar eureka--buffers-by-window-id (make-hash-table :test #'eql)
  "Map stable native window IDs to their Emacs buffers.")

(defvar eureka--layout-generation 0
  "Generation number of the latest layout snapshot sent to native Eureka.")

(defvar eureka--frame-prefix nil
  "Session-unique prefix used to identify Eureka's own Emacs frames.")

(defcustom eureka-enable-hook nil
  "Hook run at the end of `eureka-enable'."
  :type 'hook)

(defcustom eureka-input-repeat-rate 60
  "Keyboard repeat rate configured through River."
  :type 'integer)

(defcustom eureka-input-repeat-delay 200
  "Keyboard repeat delay in milliseconds configured through River."
  :type 'integer)

(defcustom eureka-touchpad-accel-speed 0.3
  "Touchpad acceleration speed configured through River/libinput."
  :type 'number)

(defcustom eureka-mouse-accel-speed 0.0
  "Mouse acceleration speed configured through River/libinput."
  :type 'number)

(defcustom eureka-touchpad-tap t
  "Whether tap-to-click is enabled on touchpads."
  :type 'boolean)

(defcustom eureka-touchpad-natural-scroll t
  "Whether natural scrolling is enabled on touchpads."
  :type 'boolean)

(defcustom eureka-touchpad-disable-while-typing t
  "Whether touchpads are disabled while typing."
  :type 'boolean)

(defcustom eureka-touchpad-disable-while-trackpointing t
  "Whether touchpads are disabled while using a trackpoint."
  :type 'boolean)

(defcustom eureka-touchpad-drag-lock t
  "Whether sticky drag lock is enabled on touchpads."
  :type 'boolean)

(defcustom eureka-touchpad-two-finger-scroll t
  "Whether two-finger scrolling is enabled on touchpads."
  :type 'boolean)

(defcustom eureka-touchpad-accel-profile "adaptive"
  "Acceleration profile used for touchpads."
  :type '(choice (const "adaptive") (const "flat")))

(defcustom eureka-mouse-accel-profile "flat"
  "Acceleration profile used for mice."
  :type '(choice (const "adaptive") (const "flat")))

(defun eureka-apply-input-config ()
  "Apply `eureka-' input settings to River."
  (interactive)
  (unless eureka-handle
    (user-error "Eureka is not enabled"))
  (eureka-configure-input eureka-handle
                        eureka-input-repeat-rate
                        eureka-input-repeat-delay
                        eureka-touchpad-accel-speed
                        eureka-mouse-accel-speed
                        eureka-touchpad-tap
                        eureka-touchpad-natural-scroll
                        eureka-touchpad-disable-while-typing
                        eureka-touchpad-disable-while-trackpointing
                        eureka-touchpad-drag-lock
                        eureka-touchpad-two-finger-scroll
                        eureka-touchpad-accel-profile
                        eureka-mouse-accel-profile))

(defun eureka--set-frame-name (frame)
  (unless (and eureka--frame-prefix
               (string-prefix-p eureka--frame-prefix
                                (frame-parameter frame 'name)))
    (set-frame-parameter frame 'name (make-temp-name eureka--frame-prefix))))

(defun eureka--ensure-frame-names ()
  "Ensure each frame has a unique title that eureka can match to its window."
  (cl-loop for frame being the frames
           do (eureka--set-frame-name frame)))

(defun eureka--find-buffer-for-window (window-id)
  "Return the live buffer registered for WINDOW-ID."
  (let ((buffer (gethash window-id eureka--buffers-by-window-id)))
    (if (buffer-live-p buffer)
        buffer
      (remhash window-id eureka--buffers-by-window-id)
      nil)))

(defvar eureka--layout-dirty t
  "Non-nil when Emacs window geometry must be sent to River.")

(defvar eureka--focus-dirty t
  "Non-nil when keyboard focus must be synchronized with River.")

(defvar eureka--sync-timer nil
  "Pending timer used to coalesce layout and focus synchronization.")

(defvar eureka--command-handler-scheduled nil
  "Non-nil while a native-command drain has already been scheduled.")

(defvar eureka--restore-focus-after-command nil
  "Non-nil when an injected key must restore client focus after it runs.")

(defun eureka--schedule-sync (&rest _)
  "Schedule one synchronization after the current Emacs activity settles."
  (unless (timerp eureka--sync-timer)
    (setq eureka--sync-timer
          (run-at-time 0 nil #'eureka--run-scheduled-sync))))

(defun eureka--run-scheduled-sync ()
  "Publish the latest stable layout and focus state."
  (setq eureka--sync-timer nil)
  (when eureka-handle
    (condition-case err
        (eureka--sync-state)
      (error
       (setq eureka--layout-dirty t
             eureka--focus-dirty t)
       (message "eureka: state synchronization failed: %s" err)))))

(defun eureka--mark-layout-dirty (&rest _)
  "Record that the Emacs window layout changed.

The actual update is deferred until after the current command.  Window
configuration hooks can run while a command is only part-way through changing
the layout; sending geometry from the hook would expose the previous layout to
  River for one input event."
  (setq eureka--layout-dirty t)
  (eureka--schedule-sync))

(defun eureka--mark-focus-dirty (&rest _)
  "Record that Emacs's selected client or input target may have changed."
  (setq eureka--focus-dirty t)
  (eureka--schedule-sync))

(defun eureka--post-command-restore-focus ()
  "Restore client focus after Emacs handles a key over a Eureka buffer.

Normally this completes an explicitly intercepted command.  Reassert focus
even when no intercept is recorded so an unexpected key delivered to Emacs
while a client buffer is selected repairs stale native frame focus instead of
leaving every following key trapped in Emacs."
  (let ((restore-intercept eureka--restore-focus-after-command))
    (setq eureka--restore-focus-after-command nil)
    (when (or restore-intercept
              (eureka--is-eureka-buffer (window-buffer (selected-window))))
      (eureka--mark-focus-dirty))))

(defun eureka--current-focus-target ()
  "Return the selected client ID, or nil when Emacs should receive input."
  (let* ((win (selected-window))
         (buf (window-buffer win))
         (can-focus-window (and (eureka--is-eureka-buffer buf)
                                ;; Keep focus on Emacs only while an intercepted
                                ;; command is actually pending.  Do not infer
                                ;; ownership from `unread-command-events' or
                                ;; `recursion-depth': layout hooks can run while
                                ;; either is transiently nonzero, publish frame
                                ;; focus, then clear the dirty flag without any
                                ;; later event that restores client focus.
                                (not eureka--restore-focus-after-command)
                                (= 0 (minibuffer-depth)))))
    (when can-focus-window
      (buffer-local-value 'eureka-window buf))))

(defun eureka--sync-state ()
  "Publish one coherent update containing changed layout and current focus."
  (when (and eureka-handle (or eureka--layout-dirty eureka--focus-dirty))
    (let ((layout-was-dirty eureka--layout-dirty)
          (focus-was-dirty eureka--focus-dirty))
      (setq eureka--layout-dirty nil
            eureka--focus-dirty nil)
      (condition-case err
          (progn
            (cl-incf eureka--layout-generation)
            (eureka-sync-state
             eureka-handle
             eureka--layout-generation
             (when layout-was-dirty (eureka--all-window-parameters))
             (eureka--current-focus-target)))
        (error
         ;; Retry transient frame/window teardown races on the next relevant
         ;; event instead of leaving River with stale state.
         (setq eureka--layout-dirty
               (or eureka--layout-dirty layout-was-dirty)
               eureka--focus-dirty
               (or eureka--focus-dirty focus-was-dirty))
         (message "eureka: could not synchronize state: %s" err))))))

(defvar-local eureka-app-id nil)
(defvar-local eureka-title nil)
(defvar-local eureka--closed-by-wm nil
  "Non-nil while killing this buffer because River reported its window closed.")

(defvar-local eureka--close-requested nil
  "Non-nil after this buffer asked its client to close.")

(defcustom eureka-window-closed-functions nil
  "Abnormal hook run with a Eureka buffer whose River window closed.
Functions should accept one argument, the buffer being closed.  If a function
kills the buffer, Eureka will not run its default close fallback."
  :type 'hook
  :group 'eureka)

(defcustom eureka-placeholder-buffer-predicate nil
  "Function identifying buffers that a newly created client should replace.
The function receives one buffer argument.  Eureka only considers windows in
the selected frame's current tab, so placeholders in other workspaces remain
untouched."
  :type '(choice (const :tag "No placeholder buffers" nil) function)
  :group 'eureka)

(defun eureka--make-buffer-name (app-id title)
  (let ((title-trunc (if (> (length title) 40)
                         (format "%s…" (substring title 0 40))
                       title)))
    (if app-id (concat title-trunc " - " app-id)
      title-trunc)))

(defun eureka--placeholder-window ()
  "Return a placeholder window in the active workspace, if one exists."
  (when eureka-placeholder-buffer-predicate
    (seq-find
     (lambda (window)
       (funcall eureka-placeholder-buffer-predicate (window-buffer window)))
     (window-list (selected-frame) 'no-minibuffer))))

(defun eureka--display-new-buffer (buffer)
  "Display and select a newly created Eureka BUFFER.
Replace a configured placeholder in the active workspace before falling back
to the user's normal `display-buffer' rules."
  (let ((window (or (when-let ((placeholder (eureka--placeholder-window)))
                      (set-window-buffer placeholder buffer)
                      placeholder)
                    (display-buffer buffer))))
    (when (window-live-p window)
      (select-window window)
      window)))

(defun eureka--handle-commands ()
  (interactive)

  ;; The process filter only schedules this function, and
  ;; `eureka--command-handler-scheduled' coalesces notifications. Emacs executes
  ;; this body serially, so an additional mutex adds no protection.
    (while-let ((cmd (eureka-get-next-command eureka-handle)))
      (pcase cmd
        (`(key-event . ,key)
         (setq eureka--focus-dirty t
               eureka--restore-focus-after-command t)
         (push (cons t key) unread-command-events))

        (`(new-window . ,window)
         (let ((buffer (eureka--create-buffer window)))
           ;; River must not leave the client undisplayed merely because
           ;; an Emacs display rule or advice failed. Activate the native
           ;; window once its backing buffer exists, then attempt placement.
           (eureka-notify-buffer-created eureka-handle window)
           (condition-case err
               (eureka--display-new-buffer buffer)
             (error
              (message "eureka: could not display new window buffer: %s" err)))
           (eureka--mark-layout-dirty)))

        (`(window-closed . ,window)
         (when-let* ((buf (eureka--find-buffer-for-window window)))
           (eureka--kill-closed-buffer buf)))

        (`(minimize-requested . ,window)
         (when-let* ((buf (eureka--find-buffer-for-window window)))
           (with-current-buffer buf
             (bury-buffer))))

        (`(focused . ,window)
         (when-let* ((buf (eureka--find-buffer-for-window window))
                     (win (get-buffer-window buf t)))
           (select-window win 'norecord)))

        (`(fatal-error . ,message)
         (eureka-disable)
         (error "eureka native window manager stopped: %s" message))

        (`(app-id-change ,window ,app-id)
         (when-let* ((buf (eureka--find-buffer-for-window window)))
           (with-current-buffer buf
             (setq eureka-app-id app-id))))

        (`(title-change ,window ,title)
         (when-let* ((buf (eureka--find-buffer-for-window window)))
           (with-current-buffer buf
             (setq eureka-title title)
             (rename-buffer (eureka--make-buffer-name eureka-app-id title) t))))

        ('frame-request (make-frame))

        (`(discard-frame . ,frame-name)
         (when-let* ((frame-names (make-frame-names-alist))
                     (frame (alist-get frame-name frame-names nil nil #'equal)))
           (delete-frame frame)))

        (`(message . ,msg)
         (message "eureka: %s" msg))

        (_ (message "eureka: ignoring unknown native command: %s" cmd))))

    ;; Commands above may display, bury, select, or destroy windows.  Snapshot
    ;; geometry afterwards so the native side never receives the layout from
    ;; immediately before the event it is handling.
  (eureka--sync-state))

(defun eureka--handle-event (&rest _) ;; unused process filter args
  (when (and eureka-handle (not eureka--command-handler-scheduled))
    (setq eureka--command-handler-scheduled t)
    (run-at-time 0 nil #'eureka--run-command-handler)))

(defun eureka--run-command-handler ()
  "Drain native commands once for any number of pipe notifications."
  (setq eureka--command-handler-scheduled nil)
  (when eureka-handle
    (condition-case err
        (eureka--handle-commands)
      (error (message "eureka: command handler failed: %s" err)))))

;; Major mode for eureka-managed buffers
(defvar-local eureka-window nil
  "Window object for this eureka-mode buffer.")

(defun eureka--buffer-killed ()
  (when eureka-window
    (remhash eureka-window eureka--buffers-by-window-id)
    (when (and eureka-handle
               (not eureka--closed-by-wm)
               (not eureka--close-requested))
      (eureka-close-window eureka-handle eureka-window))))

(defun eureka--confirm-client-close ()
  "Request client closure and retain its buffer until River confirms it."
  (cond
   (eureka--closed-by-wm t)
   ((not eureka-handle) t)
   (eureka--close-requested
    (message "eureka: waiting for the client to close")
    nil)
   (t
    (eureka-close-window eureka-handle eureka-window)
    (setq eureka--close-requested t)
    (message "eureka: requested client closure")
    nil)))

(define-derived-mode eureka-mode special-mode "Eureka"
  "Major mode for buffers representing windows managed by eureka."
  :group 'eureka
  (setq-local buffer-read-only t)
  (add-hook 'kill-buffer-query-functions #'eureka--confirm-client-close nil t)
  (add-hook 'kill-buffer-hook #'eureka--buffer-killed nil t)
  (scroll-bar-mode 0)
  (setq-local left-fringe-width 0
              right-fringe-width 0))

(defun eureka--is-eureka-buffer (buf)
  (with-current-buffer buf
    (eq major-mode 'eureka-mode)))

(defun eureka--delete-buffer-windows (buffer)
  "Delete live Emacs windows currently displaying BUFFER."
  (dolist (window (get-buffer-window-list buffer nil t))
    (when (window-live-p window)
      (with-selected-window window
        (unless (one-window-p t)
          (delete-window window))))))

(defun eureka--kill-closed-buffer (buffer)
  "Kill BUFFER after its River window closed, cleaning up visible panes."
  (with-current-buffer buffer
    (setq eureka--closed-by-wm t))
  (condition-case err
      (run-hook-with-args 'eureka-window-closed-functions buffer)
    (error
     (message "eureka: window close hook failed: %s" err)))
  (when (buffer-live-p buffer)
    (eureka--delete-buffer-windows buffer)
    (kill-buffer buffer)))

(defun eureka--window-parameters (frame window)
  (let ((edges (window-inside-absolute-pixel-edges window)))
    (eureka-make-window-parameters
     (buffer-local-value 'eureka-window (window-buffer window))
     frame
     (nth 0 edges)
     (nth 1 edges)
     (- (nth 2 edges) (nth 0 edges))
     (- (nth 3 edges) (nth 1 edges)))))

(defun eureka--all-window-parameters ()
  (let ((windows-by-frame
         (cl-loop for frame being the frames
                  collect (cons (frame-parameter frame 'name)
                                (seq-filter (lambda (window)
                                              (eureka--is-eureka-buffer (window-buffer window)))
                                            (window-list frame))))))
    (apply #'vector
           (seq-map (lambda (elem)
                      (let ((frame-name (car elem))
                            (windows (cdr elem)))
                        (apply #'vector
                               (seq-map (lambda (w) (eureka--window-parameters frame-name w))
                                        windows))))
                    windows-by-frame))))

(defun eureka--create-buffer (window-id)
  (let ((buffer (get-buffer-create (make-temp-name "eureka-window-"))))
    (with-current-buffer buffer
      (eureka-mode)
      (setq-local eureka-window window-id))
    (puthash window-id buffer eureka--buffers-by-window-id)
    buffer))

(defun eureka--focus-frame-now (&rest _)
  "Synchronously route keyboard input to Emacs for the minibuffer."
  (when eureka-handle
    (condition-case err
        (progn
          (setq eureka--layout-dirty t
                eureka--focus-dirty t)
          (eureka--sync-state))
      (error (message "eureka: could not focus Emacs frame: %s" err)))))

(defconst eureka--modifier-bits
  ;; TODO: can we handle this with XKB on the rust side, too?
  '((shift   . 1)
    (control . 4)
    (meta    . 8)
    (super   . 64)
    (hyper   . 128))
  "Modifier bits as per river_seat_v1.modifiers / XKB")

(defconst eureka--xkb-key-name-overrides
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

(defun eureka--event-key-name (event basic)
  "Return an XKB-compatible key name for symbolic EVENT with BASIC type."
  (let* ((name (symbol-name (or basic event)))
         (unmodified-name (replace-regexp-in-string
                           "\\`\\(?:A-\\|C-\\|H-\\|M-\\|S-\\|s-\\)+"
                           ""
                           name)))
    (or (alist-get (downcase unmodified-name)
                   eureka--xkb-key-name-overrides nil nil #'equal)
        unmodified-name)))

(defun eureka--key-to-xkb (key-string)
  "Decomposes an Emacs key-string (e.g. `C-x') into (event key modifiers).
The Rust side resolves the keysyms using xkbcommon."
  (let* ((event (aref (kbd key-string) 0))
         (basic (event-basic-type event))
         (mods (seq-map (lambda (mod) (alist-get mod eureka--modifier-bits))
                        (event-modifiers event)))
         (key (if (characterp basic) basic (eureka--event-key-name event basic))))
    (list event key (apply #'logior mods))))

(defun eureka-push-intercept-prefix (prefix &optional command)
  "Register PREFIX (in the format as expected by `kbd') as an intercept key
binding, meaning that it is always forwarded to Emacs. Use this in
combination with `global-set-key' to define global key bindings that are
always sent to Emacs.

Can optionally set COMMAND to one of: `toggle-fullscreen'" ;; sic, only one
  (let ((data (eureka--key-to-xkb prefix)))
    (eureka-register-xkb-prefix eureka-handle (if (integerp (car data))
                                              (car data)
                                            (symbol-name (car data)))
                              (cadr data) (caddr data) command)))

(defvar eureka-intercept-prefixes)

(defun eureka-push-intercept-prefixes () ;; TODO: remove, leave only one way?
  "Update the intercept prefixes defined in `eureka-intercept-prefixes'."
  (dolist (prefix eureka-intercept-prefixes)
    (condition-case err
        (eureka-push-intercept-prefix prefix)
      (error
       (message "eureka: could not register intercept %s: %s" prefix err)))))

(defcustom eureka-intercept-prefixes
  '("C-x" "C-u" "C-h" "M-x")
  "Prefix keys that should always go to Emacs."
  :type '(repeat key)
  :set (lambda (sym val)
         (set-default sym val)
         (when eureka-handle (eureka-push-intercept-prefixes))))

(defun eureka--suppress-focus-event (_orig-fn _event)
  "No-op for suppressing certain focus events in advice."
  (interactive "e")
  ;; okay, *almost* no-op ...
  (eureka--mark-focus-dirty))

(defun eureka--buffer-predicate (buffer)
  "Buffer predicate to avoid accidentally showing the same eureka buffer twice."
  (or (not (with-current-buffer buffer (derived-mode-p 'eureka-mode)))
      (not (get-buffer-window buffer t))))

(defun eureka--split-window-advice (new-window)
  "Advice window splits to always display another buffer, if a eureka buffer
was split."
  (with-selected-window new-window
    (with-current-buffer (window-buffer)
      (when (derived-mode-p 'eureka-mode)
        (switch-to-buffer (other-buffer)))))
  new-window)

(defun eureka--set-window-buffer-advice (orig win buf &rest r)
  "Avoid double-display of eureka buffers, by stealing them if they are
visible elsewhere. Note that displaying the same buffer in two different
tabs, for example, is completely valid."
  (with-current-buffer buf
    (when (derived-mode-p 'eureka-mode)
      (dolist (other (get-buffer-window-list buf nil 'visible))
        (unless (equal (or win (selected-window)) other)
          (with-selected-window other
            (switch-to-buffer (other-buffer)))))))

  (let* ((target-window (or win (selected-window)))
         (old-buffer (and eureka-handle
                          (window-live-p target-window)
                          (window-buffer target-window)))
         (old-eureka (and old-buffer (eureka--is-eureka-buffer old-buffer)))
         (new-eureka (and eureka-handle (eureka--is-eureka-buffer buf)))
         (result (apply orig win buf r)))
    (when (and (not (eq old-buffer buf))
               (or old-eureka new-eureka))
      (eureka--mark-layout-dirty))
    result))

(defun eureka-enable ()
  "Enable the eureka window manager for river. Call this function once when
starting Emacs inside of river."
  (if eureka-handle
      (message "Eureka is already enabled")
    (condition-case err
        (progn
          ;; TODO: this is a hack for lack of ability to figure out alignment ...
          (menu-bar-mode 0)
          (tool-bar-mode 0)

          ;; Configure this and all future frames.
          (let ((frame-params '((undecorated . t)
                                (buffer-predicate . eureka--buffer-predicate))))
            (modify-all-frames-parameters frame-params))

          (advice-add 'split-window-below :filter-return #'eureka--split-window-advice)
          (advice-add 'split-window-right :filter-return #'eureka--split-window-advice)
          (advice-add 'set-window-buffer :around #'eureka--set-window-buffer-advice)

          (message "Launching native module ...")
          (setq eureka--frame-prefix
                (format "eureka-frame-%x-%x-"
                        (emacs-pid) (random most-positive-fixnum)))
          (eureka--ensure-frame-names)
          (add-to-list 'after-make-frame-functions #'eureka--set-frame-name)
          (setq eureka--event-process
                (make-pipe-process :name "eureka-events"
                                   :buffer " *eureka-events*"
                                   :filter #'eureka--handle-event
                                   :noquery t))
          (setq eureka-handle
                (eureka-start-wm eureka--event-process eureka--frame-prefix))
          ;; The worker can fail before `eureka-start-wm' returns.  Its pipe
          ;; notification then arrives while `eureka-handle' is still nil, so
          ;; explicitly drain any command that raced with handle installation.
          (eureka--handle-event)
          (eureka-apply-input-config)
          (eureka-push-intercept-prefixes)

          ;; Layout signals
          (add-hook 'window-configuration-change-hook #'eureka--mark-layout-dirty)

          ;; Focus signals
          (add-hook 'window-selection-change-functions #'eureka--mark-focus-dirty)
          (add-hook 'window-buffer-change-functions    #'eureka--mark-layout-dirty)
          (add-hook 'minibuffer-setup-hook             #'eureka--focus-frame-now)
          (add-hook 'minibuffer-exit-hook              #'eureka--mark-focus-dirty)
          (add-hook 'tab-bar-tab-post-select-functions #'eureka--mark-layout-dirty)
          (add-hook 'post-command-hook                 #'eureka--post-command-restore-focus)

          ;; Suppress pgtk focus feedback loop (as does EXWM).
          (advice-add 'handle-focus-in  :around #'eureka--suppress-focus-event)
          (advice-add 'handle-focus-out :around #'eureka--suppress-focus-event)

          (run-hooks 'eureka-enable-hook))
      (error
       ;; Startup is all-or-nothing. In particular, do not leave global advice
       ;; installed if native startup or user configuration fails.
       (eureka-disable)
       (signal (car err) (cdr err))))))

(defun eureka-disable ()
  "Disable Eureka and remove all global hooks and advice it installed."
  (interactive)
  (when eureka-handle
    (ignore-errors (eureka-stop-wm eureka-handle)))
  (setq eureka-handle nil
        eureka--layout-dirty t
        eureka--focus-dirty t
        eureka--restore-focus-after-command nil
        eureka--command-handler-scheduled nil)
  (clrhash eureka--buffers-by-window-id)
  (setq eureka--layout-generation 0)
  (setq eureka--frame-prefix nil)
  (when (timerp eureka--sync-timer)
    (cancel-timer eureka--sync-timer))
  (setq eureka--sync-timer nil)
  (when (process-live-p eureka--event-process)
    (delete-process eureka--event-process))
  (setq eureka--event-process nil)
  (remove-hook 'after-make-frame-functions #'eureka--set-frame-name)
  (remove-hook 'window-configuration-change-hook #'eureka--mark-layout-dirty)
  (remove-hook 'window-selection-change-functions #'eureka--mark-focus-dirty)
  (remove-hook 'window-buffer-change-functions #'eureka--mark-layout-dirty)
  (remove-hook 'minibuffer-setup-hook #'eureka--focus-frame-now)
  (remove-hook 'minibuffer-exit-hook #'eureka--mark-focus-dirty)
  (remove-hook 'tab-bar-tab-post-select-functions #'eureka--mark-layout-dirty)
  (remove-hook 'post-command-hook #'eureka--post-command-restore-focus)
  (advice-remove 'split-window-below #'eureka--split-window-advice)
  (advice-remove 'split-window-right #'eureka--split-window-advice)
  (advice-remove 'set-window-buffer #'eureka--set-window-buffer-advice)
  (advice-remove 'handle-focus-in #'eureka--suppress-focus-event)
  (advice-remove 'handle-focus-out #'eureka--suppress-focus-event)
  (message "Eureka disabled"))

(provide 'eureka)
