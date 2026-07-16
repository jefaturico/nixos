;;; jf-eureka.el --- Local Eureka session setup -*- lexical-binding: t; -*-

(jf/startup-mark "jf-eureka entry")

(require 'eureka)
(require 'seq)
(require 'subr-x)

(defvar-local jf-eureka--initial-placeholder nil
  "Non-nil when this buffer is only the initial workspace placeholder.")

(defun jf-eureka--placeholder-buffer-p (buffer)
  "Return non-nil when BUFFER should be replaced by the first Eureka client."
  (with-current-buffer buffer
    (or jf-eureka--initial-placeholder
        (string= (buffer-name) "*scratch*"))))

(setopt eureka-placeholder-buffer-predicate #'jf-eureka--placeholder-buffer-p)

(setopt eureka-intercept-prefixes
        '("C-x" "C-u" "C-h" "M-x" "s-x" "s-v" "s-<return>"
          "s-q" "s-k" "s-b" "s-o"
          "s-/" "s--" "C-s-f"
          "s-t" "s-w" "C-s-w"
          "s-<escape>"
          "s-d" "s-i"
          "s-u"
          "s-0" "s-1" "s-2" "s-3" "s-4"
          "s-5" "s-6" "s-7" "s-8" "s-9"
          "C-s-0" "C-s-1" "C-s-2" "C-s-3" "C-s-4"
          "C-s-5" "C-s-6" "C-s-7" "C-s-8" "C-s-9"
          "<XF86AudioRaiseVolume>"
          "<XF86AudioLowerVolume>"
          "<XF86AudioMute>"
          "<XF86AudioMicMute>"
          "<XF86MonBrightnessUp>"
          "<XF86MonBrightnessDown>"
          "<PowerOff>"
          "<XF86PowerOff>"))

;; River no longer provides riverctl. Eureka supplies the protocol mechanism;
;; this session file owns the input policy applied to current and hot-plugged
;; devices.
(setopt eureka-input-repeat-rate 60
        eureka-input-repeat-delay 200
        eureka-touchpad-accel-speed 0.3
        eureka-mouse-accel-speed 0.0
        eureka-touchpad-tap t
        eureka-touchpad-natural-scroll t
        eureka-touchpad-disable-while-typing t
        eureka-touchpad-disable-while-trackpointing t
        eureka-touchpad-drag-lock t
        eureka-touchpad-two-finger-scroll t
        eureka-touchpad-accel-profile "adaptive"
        eureka-mouse-accel-profile "flat")

(defun jf-eureka-run (&rest command)
  "Run COMMAND detached from Emacs."
  (apply #'start-process (concat "jf-eureka-" (car command)) nil command))

(defvar jf-eureka--power-key-inhibitor-process nil
  "Process inhibiting logind power-key handling while Eureka is active.")

(defun jf-eureka--inhibit-logind-power-key ()
  "Let Eureka handle the hardware power key instead of logind."
  (unless (process-live-p jf-eureka--power-key-inhibitor-process)
    (when-let ((systemd-inhibit (executable-find "systemd-inhibit")))
      (setq jf-eureka--power-key-inhibitor-process
            (start-process
             "eureka-power-key-inhibitor" nil
             systemd-inhibit
             "--what=handle-power-key"
             "--mode=block"
             "--who=Eureka"
             "--why=Eureka handles the power key."
             "sleep" "infinity")))))

(defun jf-eureka--application-dirs ()
  "Return application directories from XDG data roots."
  (delete-dups
   (delq nil
         (mapcar (lambda (dir)
                   (let ((apps (expand-file-name "applications" dir)))
                     (when (file-directory-p apps) apps)))
                 (append
                  (list (or (getenv "XDG_DATA_HOME")
                            (expand-file-name ".local/share" "~")))
                  (split-string (or (getenv "XDG_DATA_DIRS") "") ":" t)
                  '("/run/current-system/sw/share"
                    "/etc/profiles/per-user/jefaturico/share"
                    "/usr/local/share"
                    "/usr/share"))))))

(defun jf-eureka--desktop-entry-value (key)
  "Return the value for KEY in the current desktop entry buffer."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (concat "^" (regexp-quote key) "=[ \t]*\\(.*\\)$") nil t)
      (string-trim (match-string 1)))))

(defun jf-eureka--desktop-command (exec)
  "Turn a desktop Exec field into a shell command."
  (string-trim
   (replace-regexp-in-string
    "[ \t]*%[fFuUdDnNickvm]" ""
    exec)))

(defun jf-eureka--desktop-entry (file)
  "Return a launcher candidate for desktop FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((type (jf-eureka--desktop-entry-value "Type"))
          (name (jf-eureka--desktop-entry-value "Name"))
          (exec (jf-eureka--desktop-entry-value "Exec"))
          (hidden (jf-eureka--desktop-entry-value "Hidden"))
          (no-display (jf-eureka--desktop-entry-value "NoDisplay"))
          (terminal (jf-eureka--desktop-entry-value "Terminal")))
      (when (and (equal type "Application")
                 name
                 exec
                 (not (member hidden '("true" "True" "1")))
                 (not (member no-display '("true" "True" "1")))
                 (not (member terminal '("true" "True" "1"))))
        (cons name (jf-eureka--desktop-command exec))))))

(defun jf-eureka--applications ()
  "Return application launcher candidates respecting XDG precedence.

Application directories are ordered from highest to lowest priority.  Once a
desktop-file ID is found, ignore copies exported by lower-priority directories.
This is particularly important for local overrides of Flatpak applications."
  (let ((seen (make-hash-table :test #'equal))
        applications)
    (dolist (dir (jf-eureka--application-dirs))
      (dolist (file (directory-files-recursively dir "\\.desktop\\'"))
        (let ((id (file-name-nondirectory file)))
          (unless (gethash id seen)
            (puthash id t seen)
            (when-let ((application (jf-eureka--desktop-entry file)))
              (push application applications))))))
    (sort applications
          (lambda (a b) (string-lessp (car a) (car b))))))

(defun launch-program ()
  "Launch an XDG desktop application using Emacs completion."
  (interactive)
  (let* ((applications (jf-eureka--applications))
         (choice (completing-read "Launch: " applications nil t))
         (command (cdr (assoc choice applications))))
    (unless command
      (user-error "No command for %s" choice))
    (start-process-shell-command (concat "launch-program-" choice) nil command)))

(defun jf-eureka-poweroff ()
  "Power off the system."
  (interactive)
  (when (jf-eureka--confirm-destructive-session-action "power off")
    (when (fboundp 'jf/release-shutdown-inhibitor)
      (jf/release-shutdown-inhibitor))
    (jf-eureka-run "systemctl" "poweroff")))

(defun jf-eureka-reboot ()
  "Reboot the system."
  (interactive)
  (when (jf-eureka--confirm-destructive-session-action "reboot")
    (when (fboundp 'jf/release-shutdown-inhibitor)
      (jf/release-shutdown-inhibitor))
    (jf-eureka-run "systemctl" "reboot")))

(defun jf-eureka-suspend ()
  "Suspend the system."
  (interactive)
  (jf-eureka-run "systemctl" "suspend"))

(defun jf-eureka-exit-session ()
  "Ask River to exit the current Eureka session."
  (interactive)
  (when (jf-eureka--confirm-destructive-session-action "exit the Eureka session")
    (when (fboundp 'jf/release-shutdown-inhibitor)
      (jf/release-shutdown-inhibitor))
    (unless eureka-handle
      (user-error "Eureka is not enabled"))
    (eureka-exit-session eureka-handle)))

(defun jf-eureka--confirm-destructive-session-action (action)
  "Ask before ACTION kills the session or Emacs, saving buffers first."
  (save-some-buffers nil #'jf/save-worthy-buffer-p)
  (y-or-n-p (format "Really %s? " action)))

(defvar jf-eureka-power-menu-actions
  '(("Exit session" . jf-eureka-exit-session)
    ("Suspend" . jf-eureka-suspend)
    ("Reboot" . jf-eureka-reboot)
    ("Power off" . jf-eureka-poweroff))
  "Power/session actions shown by `jf-eureka-power-menu'.")

(defun jf-eureka-power-menu ()
  "Show Eureka power/session actions using completion."
  (interactive)
  (let* ((choice (completing-read "Power: " jf-eureka-power-menu-actions nil t))
         (command (cdr (assoc choice jf-eureka-power-menu-actions))))
    (unless command
      (user-error "No action for %s" choice))
    (call-interactively command)))

(defvar jf-eureka-dark-theme 'ef-dream
  "Emacs theme used for the Eureka dark color mode.")

(defvar jf-eureka-light-theme 'ef-reverie
  "Emacs theme used for the Eureka light color mode.")

(defun jf-eureka--notify (summary &optional body)
  "Show SUMMARY and optional BODY inside Emacs."
  (message "%s%s" summary (if (and body (not (string-empty-p body)))
                              (concat ": " body)
                            "")))

;; Own the standard desktop notification interface in Emacs.  Stop the old
;; registrations first when this file is interactively reloaded.
(when (fboundp 'jf-eureka-notifications-stop)
  (jf-eureka-notifications-stop))

(require 'dbus)

(defconst jf-eureka-notification-service "org.freedesktop.Notifications")
(defconst jf-eureka-notification-path "/org/freedesktop/Notifications")
(defconst jf-eureka-notification-interface "org.freedesktop.Notifications")

(defvar jf-eureka-notification-next-id 0)
(defvar jf-eureka-notification-history nil)
(defvar jf-eureka-notification-registrations nil)
(defvar jf-eureka-notification-current nil)
(defvar jf-eureka-notification-timer nil)

(defun jf-eureka-notification--hint (name hints)
  "Return NAME from the D-Bus dictionary HINTS."
  (let ((entry (seq-find (lambda (item)
                           (and (consp item) (equal (car item) name)))
                         hints)))
    (when entry
      ;; D-Bus variants may add one or more type tags around the value.
      (let ((value (car (last entry))))
        (while (and (listp value) (= (length value) 1))
          (setq value (car value)))
        value))))

(defun jf-eureka-notification--critical-p (hints)
  "Return non-nil when HINTS specify critical urgency."
  (= (or (jf-eureka-notification--hint "urgency" hints) 1) 2))

(defun jf-eureka-notification--clear ()
  "Clear the notification currently displayed in the mode line."
  (setq jf-eureka-notification-current nil)
  (force-mode-line-update t))

(defun jf-eureka-notification-close (&optional id)
  "Close notification ID, or the current notification when called interactively."
  (interactive)
  (setq id (or id 0))
  (when (or (zerop id)
            (and jf-eureka-notification-current
                 (= id (plist-get jf-eureka-notification-current :id))))
    (when (timerp jf-eureka-notification-timer)
      (cancel-timer jf-eureka-notification-timer))
    (setq jf-eureka-notification-timer nil)
    (jf-eureka-notification--clear))
  :ignore)

(defun jf-eureka-notification--show (notification _timeout critical)
  "Show NOTIFICATION in the mode line if CRITICAL, otherwise in the echo area."
  (if critical
      (progn
        (setq jf-eureka-notification-current notification)
        (force-mode-line-update t))
    (jf-eureka--notify (plist-get notification :summary)
                       (plist-get notification :body))))

(defun jf-eureka-notification-notify
    (_app-name replaces-id _app-icon summary body _actions hints timeout)
  "Handle the freedesktop Notify method inside Emacs."
  (let* ((id (if (and (> replaces-id 0)
                      (seq-find (lambda (item)
                                  (= replaces-id (plist-get item :id)))
                                jf-eureka-notification-history))
                 replaces-id
               (setq jf-eureka-notification-next-id
                     (1+ jf-eureka-notification-next-id))))
         (critical (jf-eureka-notification--critical-p hints))
         (notification (list :id id :summary summary :body body
                             :critical critical :time (current-time))))
    (setq jf-eureka-notification-history
          (cons notification
                (seq-take
                 (seq-remove (lambda (item) (= id (plist-get item :id)))
                             jf-eureka-notification-history)
                 49)))
    (when critical
      (eureka-exit-fullscreen eureka-handle))
    ;; Let Eureka commit the fullscreen change before drawing the Emacs UI.
    (run-at-time (if critical 0.05 0) nil
                 #'jf-eureka-notification--show notification timeout critical)
    id))

(defun jf-eureka-notification-capabilities ()
  "Return capabilities of the Emacs notification server."
  '(("body" "persistence")))

(defun jf-eureka-notification-server-information ()
  "Return identifying information for the notification server."
  '("Eureka Emacs" "Eureka" "1.0" "1.2"))

(defun jf-eureka-notifications-stop ()
  "Release all D-Bus registrations owned by the notification server."
  (when (timerp jf-eureka-notification-timer)
    (cancel-timer jf-eureka-notification-timer))
  (setq jf-eureka-notification-timer nil)
  (dolist (registration jf-eureka-notification-registrations)
    (ignore-errors (dbus-unregister-object registration)))
  (setq jf-eureka-notification-registrations nil)
  (ignore-errors
    (dbus-unregister-service :session jf-eureka-notification-service)))

(defun jf-eureka-notifications-start ()
  "Own and serve the freedesktop notification interface in Emacs."
  (dbus-register-service :session jf-eureka-notification-service)
  (setq jf-eureka-notification-registrations
        (mapcar
         (lambda (method)
           (dbus-register-method
            :session jf-eureka-notification-service
            jf-eureka-notification-path jf-eureka-notification-interface
            (car method) (cdr method) t))
         `(("Notify" . ,#'jf-eureka-notification-notify)
           ("CloseNotification" . ,#'jf-eureka-notification-close)
           ("GetCapabilities" . ,#'jf-eureka-notification-capabilities)
           ("GetServerInformation" . ,#'jf-eureka-notification-server-information)))))

(defun jf-eureka--call-process-string (program &rest args)
  "Run PROGRAM with ARGS and return stdout as a trimmed string."
  (with-temp-buffer
    (let ((status (apply #'call-process program nil t nil args)))
      (unless (zerop status)
        (user-error "%s failed with status %s" program status))
      (string-trim (buffer-string)))))

(defun jf-eureka--set-system-color-scheme (mode)
  "Set the desktop color-scheme preference to MODE."
  (let* ((dark (eq mode 'dark))
         (color-scheme (if dark "prefer-dark" "prefer-light"))
         (gtk-theme (if dark "Adwaita-dark" "Adwaita")))
    (cond
     ((executable-find "gsettings")
      (call-process "gsettings" nil nil nil
                    "set" "org.gnome.desktop.interface"
                    "gtk-theme" gtk-theme)
      (call-process "gsettings" nil nil nil
                    "set" "org.gnome.desktop.interface"
                    "color-scheme" color-scheme))
     ((executable-find "dconf")
      (call-process "dconf" nil nil nil
                    "write" "/org/gnome/desktop/interface/gtk-theme"
                    (format "'%s'" gtk-theme))
      (call-process "dconf" nil nil nil
                    "write" "/org/gnome/desktop/interface/color-scheme"
                    (format "'%s'" color-scheme))))))

(defun jf-eureka--current-color-mode ()
  "Return the current desktop color mode."
  (if (and (fboundp 'jf/current-system-color-scheme)
           (string= (jf/current-system-color-scheme) "'prefer-light'"))
      'light
    'dark))

(defun jf-eureka--apply-color-scheme (mode theme)
  "Apply MODE and THEME to Emacs and the desktop preference."
  (jf-eureka--set-system-color-scheme mode)
  (pcase mode
    ('dark (setq jf/emacs-theme-dark theme))
    ('light (setq jf/emacs-theme-light theme)))
  (if (fboundp 'jf/apply-current-theme)
      (jf/apply-current-theme)
    (mapc #'disable-theme (copy-sequence custom-enabled-themes))
    (load-theme theme t))
  (jf-eureka--notify "Theme applied" (format "%s" theme)))

(defun jf-eureka-toggle-color-mode ()
  "Toggle between the configured dark and light Eureka color schemes."
  (interactive)
  (if (eq (jf-eureka--current-color-mode) 'dark)
      (jf-eureka--apply-color-scheme 'light jf-eureka-light-theme)
    (jf-eureka--apply-color-scheme 'dark jf-eureka-dark-theme)))

(defun jf-eureka--volume-text ()
  "Return a compact description of the current default sink volume."
  (let ((info (jf-eureka--call-process-string
               "wpctl" "get-volume" "@DEFAULT_AUDIO_SINK@")))
    (if (string-match-p "MUTED" info)
        "Volume: MUTED"
      (if (string-match "\\([0-9]+\\(?:\\.[0-9]+\\)?\\)" info)
          (format "Volume: %d%%"
                  (round (* 100 (string-to-number (match-string 1 info)))))
        info))))

(defun jf-eureka--set-volume (value)
  "Set default sink volume to VALUE and report the result."
  (unless (executable-find "wpctl")
    (user-error "wpctl not found"))
  (if (string= value "mute")
      (call-process "wpctl" nil nil nil
                    "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle")
    (call-process "wpctl" nil nil nil
                  "set-volume" "@DEFAULT_AUDIO_SINK@" value "-l" "1.5"))
  (jf-eureka--notify (jf-eureka--volume-text)))

(defun jf-eureka-volume-up ()
  (interactive)
  (jf-eureka--set-volume "0.1+"))

(defun jf-eureka-volume-down ()
  (interactive)
  (jf-eureka--set-volume "0.1-"))

(defun jf-eureka-volume-mute ()
  (interactive)
  (jf-eureka--set-volume "mute"))

(defun jf-eureka-mic-mute ()
  (interactive)
  (jf-eureka-run "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"))

(defun jf-eureka--brightness-percent ()
  "Return the current brightness percentage as a number."
  (let* ((info (jf-eureka--call-process-string "brightnessctl" "i" "-m"))
         (fields (split-string info ",")))
    (string-to-number (string-remove-suffix "%" (nth 3 fields)))))

(defun jf-eureka--set-brightness (value)
  "Set brightness to VALUE and report the result."
  (unless (executable-find "brightnessctl")
    (user-error "brightnessctl not found"))
  (when (and (string-suffix-p "-" value)
             (<= (jf-eureka--brightness-percent) 10))
    (setq value "10%"))
  (let* ((output (jf-eureka--call-process-string "brightnessctl" "set" value "-m"))
         (fields (split-string output ","))
         (percent (nth 3 fields)))
    (jf-eureka--notify (format "Brightness: %s" percent))))

(defun jf-eureka-brightness-up ()
  (interactive)
  (jf-eureka--set-brightness "+10%"))

(defun jf-eureka-brightness-down ()
  (interactive)
  (jf-eureka--set-brightness "10%-"))

(defun jf-eureka-workspace-name (digit)
  "Return the workspace name for DIGIT."
  (number-to-string (if (zerop digit) 10 digit)))

(defun jf-eureka-current-workspace-name ()
  "Return the current tab-bar workspace name."
  (alist-get 'name (cdr (tab-bar--current-tab))))

(defun jf-eureka-switch-workspace (digit)
  "Switch to workspace DIGIT, creating it when needed."
  (interactive "nWorkspace digit: ")
  (if (active-minibuffer-window)
      ;; Tab window configurations must not be swapped underneath an active
      ;; minibuffer.  Finish unwinding the recursive edit first, then switch.
      (progn
        (run-at-time 0 nil #'jf-eureka-switch-workspace digit)
        (abort-recursive-edit))
    (let ((name (jf-eureka-workspace-name digit)))
      (tab-bar-switch-to-tab name)
      (jf-eureka--notify "Workspace" name))))

(defun jf-eureka--remove-buffer-from-current-workspace (buffer)
  "Stop showing BUFFER in the selected window without killing it."
  (when (eq (window-buffer (selected-window)) buffer)
    (if (one-window-p t)
        (switch-to-prev-buffer (selected-window) 'bury)
      (delete-window (selected-window)))))

(defun jf-eureka--move-buffer-to-workspace (buffer digit)
  "Move live BUFFER to workspace DIGIT after any minibuffer has unwound."
  (when (buffer-live-p buffer)
    (let ((source-name (jf-eureka-current-workspace-name))
          (target-name (jf-eureka-workspace-name digit)))
      (unless (string= source-name target-name)
        (jf-eureka--remove-buffer-from-current-workspace buffer)
        (tab-bar-switch-to-tab target-name)
        (switch-to-buffer buffer)
        (jf-eureka--notify "Moved to workspace" target-name)))))

(defun jf-eureka-move-buffer-to-workspace (digit)
  "Move the current buffer to workspace DIGIT."
  (interactive "nMove buffer to workspace digit: ")
  (if-let ((minibuffer (active-minibuffer-window)))
      (let ((buffer (and (window-live-p (minibuffer-selected-window))
                         (window-buffer (minibuffer-selected-window)))))
        (run-at-time 0 nil #'jf-eureka--move-buffer-to-workspace buffer digit)
        (abort-recursive-edit))
    (jf-eureka--move-buffer-to-workspace (current-buffer) digit)))

(defun usb-open ()
  "Prompt with a list of mounted USBs ordered by recency and open dired in the selected one."
  (interactive)
  (let* ((user (or (getenv "USER") (user-login-name)))
         (media-root (concat "/run/media/" user))
         (dirs (when (file-directory-p media-root)
                 (directory-files-and-attributes media-root t nil t))))
    (if (null dirs)
        (message "USB: No mounted removable devices")
      (let* ((usb-dirs (seq-filter
                        (lambda (dir-attr)
                          (let ((name (car dir-attr))
                                (attr (cdr dir-attr)))
                            (and (eq (file-attribute-type attr) t)
                                 (not (member (file-name-nondirectory name) '("." ".."))))))
                        dirs))
             (sorted-dirs (sort usb-dirs
                                (lambda (a b)
                                  (time-less-p (file-attribute-modification-time (cdr b))
                                               (file-attribute-modification-time (cdr a))))))
             (candidates (mapcar (lambda (dir-attr)
                                   (let ((path (car dir-attr)))
                                     (cons (file-name-nondirectory path) path)))
                                 sorted-dirs)))
        (if (null candidates)
            (message "USB: No mounted removable devices")
          (let* ((choice (completing-read "USB drive: " candidates nil t))
                 (target (cdr (assoc choice candidates))))
            (when target
              (dired target))))))))

(dotimes (digit 10)
  (let ((key (number-to-string digit))
        (workspace-digit digit))
    (global-set-key (kbd (concat "s-" key))
                    (lambda ()
                      (interactive)
                      (jf-eureka-switch-workspace workspace-digit)))
    (global-set-key (kbd (concat "C-s-" key))
                    (lambda ()
                      (interactive)
                      (jf-eureka-move-buffer-to-workspace workspace-digit)))))

(global-set-key (kbd "s-x") #'launch-program)
(global-set-key (kbd "s-v") #'vterm-other-window)
(global-set-key (kbd "s-q") #'delete-window)
(global-set-key (kbd "s-k") #'kill-current-buffer)
(global-set-key (kbd "s-b") #'consult-buffer)
(global-unset-key (kbd "s-n"))
(global-unset-key (kbd "s-p"))
(global-unset-key (kbd "s-<tab>"))
(global-set-key (kbd "s-o") #'other-window)
(global-unset-key (kbd "C-s-o"))
(global-set-key (kbd "s-/") #'split-window-right)
(global-set-key (kbd "s--") #'split-window-below)
(global-set-key (kbd "s-<return>") #'delete-other-windows)
(global-unset-key (kbd "s-f"))
(global-unset-key (kbd "s-m"))
(global-unset-key (kbd "s-SPC"))
(global-set-key (kbd "C-s-f") #'toggle-frame-fullscreen)
(global-set-key (kbd "s-t") #'jf-eureka-toggle-color-mode)
(global-set-key (kbd "s-w") #'jf/bookmark-open)
(global-unset-key (kbd "s-W"))
(global-set-key (kbd "C-s-w") #'jf/browser-open-or-search)
(global-set-key (kbd "s-u") #'usb-open)
(global-set-key (kbd "s-i") #'jf/systeminfo)
(global-set-key (kbd "s-d") #'jf/pick-pdf)
(global-set-key (kbd "s-<escape>") #'jf-eureka-power-menu)
(global-unset-key (kbd "C-x C-c"))
(global-set-key (kbd "<XF86AudioRaiseVolume>") #'jf-eureka-volume-up)
(global-set-key (kbd "<XF86AudioLowerVolume>") #'jf-eureka-volume-down)
(global-set-key (kbd "<XF86AudioMute>") #'jf-eureka-volume-mute)
(global-set-key (kbd "<XF86AudioMicMute>") #'jf-eureka-mic-mute)
(global-set-key (kbd "<XF86MonBrightnessUp>") #'jf-eureka-brightness-up)
(global-set-key (kbd "<XF86MonBrightnessDown>") #'jf-eureka-brightness-down)
(global-set-key (kbd "<PowerOff>") #'jf-eureka-suspend)
(global-set-key (kbd "<XF86PowerOff>") #'jf-eureka-suspend)

(defun jf-eureka--push-builtin-intercepts ()
  "Register Eureka builtin intercepts for keys handled outside Emacs."
  (eureka-push-intercept-prefix "C-s-f" 'toggle-fullscreen)
  (eureka-push-intercept-prefix "<Print>" 'toggle-fullscreen))

(remove-hook 'eureka-enable-hook #'jf-eureka--push-builtin-intercepts)
(add-hook 'eureka-enable-hook #'jf-eureka--push-builtin-intercepts)

(unless eureka-handle
  (jf/startup-mark "eureka-enable start")
  (eureka-enable)
  (jf/startup-mark "eureka-enable end"))

;; Neither operation is required to claim River's WM role or construct the
;; initial agenda.  Keep them off the login-to-first-buffer critical path.
(run-with-idle-timer 1 nil #'jf-eureka--inhibit-logind-power-key)
(run-with-idle-timer 1 nil #'jf-eureka-notifications-start)

(jf/startup-mark "jf-eureka exit")

(provide 'jf-eureka)
;;; jf-eureka.el ends here
