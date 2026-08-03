;;; jf-eureka-desktop.el --- Eureka desktop controls and workspaces -*- lexical-binding: t; -*-

(require 'eureka)
(require 'seq)
(require 'subr-x)
(require 'jf-eureka-session)

(defvar jf/emacs-theme-dark)
(defvar jf/emacs-theme-light)

;;; Command helpers

(defun jf-eureka--call-process-string (program &rest args)
  "Run PROGRAM with ARGS and return stdout as a trimmed string."
  (with-temp-buffer
    (let ((status (apply #'call-process program nil t nil args)))
      (unless (zerop status)
        (user-error "%s failed with status %s" program status))
      (string-trim (buffer-string)))))

;;; Color scheme

(defvaralias 'jf-eureka-dark-theme 'jf/emacs-theme-dark
  "Emacs theme used for the Eureka dark color mode.")

(defvaralias 'jf-eureka-light-theme 'jf/emacs-theme-light
  "Emacs theme used for the Eureka light color mode.")

(defun jf-eureka--set-system-color-scheme (mode)
  "Set the desktop color-scheme preference to MODE."
  (let* ((dark (eq mode 'dark))
         (color-scheme (if dark "prefer-dark" "prefer-light"))
         (gtk-theme (if dark "Adwaita-dark" "Adwaita")))
    (cond
     ((executable-find "gsettings")
      (jf-eureka--call-process-string
       "gsettings" "set" "org.gnome.desktop.interface"
       "color-scheme" color-scheme)
      (jf-eureka--call-process-string
       "gsettings" "set" "org.gnome.desktop.interface"
       "gtk-theme" gtk-theme))
     ((executable-find "dconf")
      (jf-eureka--call-process-string
       "dconf" "write" "/org/gnome/desktop/interface/color-scheme"
       (format "'%s'" color-scheme))
      (jf-eureka--call-process-string
       "dconf" "write" "/org/gnome/desktop/interface/gtk-theme"
       (format "'%s'" gtk-theme)))
     (t
      (user-error "Neither gsettings nor dconf is available")))))

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

;;; Audio

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
      (jf-eureka--call-process-string
       "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle")
    (jf-eureka--call-process-string
     "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" value "-l" "1.5"))
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

;;; Display brightness

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

;;; Lid action

(defconst jf-eureka--lid-monitor-service "lid-monitor-only.service"
  "User service implementing the runtime monitor-only lid action.")

(defun jf-eureka--lid-monitor-only-p ()
  "Return non-nil when the monitor-only lid action is active."
  (zerop
   (call-process
    "systemctl" nil nil nil "--user" "is-active" "--quiet"
    jf-eureka--lid-monitor-service)))

(defun jf-eureka-toggle-lid-action ()
  "Toggle lid close between suspend and turning off the monitor.

Suspend is the default.  The monitor-only action lasts for the current
graphical session.  It still suspends when the lid is closed at 10% battery
or less, or when the battery falls to 10% while the lid remains closed."
  (interactive)
  (unless (executable-find "systemctl")
    (user-error "systemctl not found"))
  (let* ((monitor-only (jf-eureka--lid-monitor-only-p))
         (verb (if monitor-only "stop" "start")))
    (jf-eureka--call-process-string
     "systemctl" "--user" verb jf-eureka--lid-monitor-service)
    (jf-eureka--notify
     "Lid action"
     (if monitor-only "suspend" "turn off monitor"))))

;;; Removable media

(defun jf-eureka-usb-open ()
  "Choose a recently mounted USB and open the selected one in Dired."
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

(provide 'jf-eureka-desktop)
;;; jf-eureka-desktop.el ends here
