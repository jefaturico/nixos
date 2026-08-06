;;; example.el --- Portable Eureka session policy -*- lexical-binding: t; -*-

;; This file is deliberately independent of the author's personal Emacs
;; configuration.  Load it after the `eureka' package, customize the variables
;; below, and call `eureka-example-start' from River's init command.

(require 'eureka)
(require 'seq)
(require 'subr-x)
(require 'xdg)

(defgroup eureka-example nil
  "A small, self-contained desktop policy for Eureka."
  :group 'eureka
  :prefix "eureka-example-")

(defcustom eureka-example-terminal-command '("foot")
  "Command used by `eureka-example-terminal'."
  :type '(repeat string))

(defcustom eureka-example-lock-command '("waylock")
  "Command used by `eureka-example-lock'."
  :type '(repeat string))

(defvar eureka-example--application-cache nil)

(defun eureka-example--run (&rest command)
  "Run COMMAND asynchronously and report a non-zero exit."
  (unless (and command (executable-find (car command)))
    (user-error "Executable not found: %s" (car command)))
  (let* ((name (format "eureka-example-%s" (car command)))
         (buffer (generate-new-buffer (format " *%s*" name)))
         process)
    (setq process
          (make-process
           :name name :buffer buffer :command command :noquery t
           :sentinel
           (lambda (finished _event)
             (when (memq (process-status finished) '(exit signal))
               (let ((output (when (buffer-live-p (process-buffer finished))
                               (with-current-buffer (process-buffer finished)
                                 (string-trim (buffer-string))))))
                 (unless (zerop (process-exit-status finished))
                   (display-warning
                    'eureka
                    (format "%s failed%s"
                            (string-join (process-command finished) " ")
                            (if (string-empty-p (or output ""))
                                "" (concat ": " output)))
                    :error))
                 (when (buffer-live-p (process-buffer finished))
                   (kill-buffer (process-buffer finished))))))))
    process))

;;; Application launcher

(defun eureka-example--application-dirs ()
  "Return existing XDG application directories in precedence order."
  (delete-dups
   (seq-filter
    #'file-directory-p
    (mapcar (lambda (directory)
              (expand-file-name "applications" directory))
            (cons (xdg-data-home) (xdg-data-dirs))))))

(defun eureka-example--desktop-true-p (value)
  (and value (member (downcase value) '("true" "1"))))

(defun eureka-example--desktop-entry (file)
  "Return a (DISPLAY-NAME . FILE) candidate for desktop FILE."
  (condition-case nil
      (let* ((entry (xdg-desktop-read-file file))
             (name (gethash "Name" entry)))
        (when (and (equal (gethash "Type" entry) "Application")
                   (not (string-empty-p (or name "")))
                   (gethash "Exec" entry)
                   (not (eureka-example--desktop-true-p
                         (gethash "Hidden" entry)))
                   (not (eureka-example--desktop-true-p
                         (gethash "NoDisplay" entry)))
                   (not (eureka-example--desktop-true-p
                         (gethash "Terminal" entry))))
          (cons name file)))
    (error nil)))

(defun eureka-example--applications (&optional refresh)
  "Return cached graphical application candidates, or rescan on REFRESH."
  (when (or refresh (null eureka-example--application-cache))
    (let ((seen (make-hash-table :test #'equal))
          applications)
      (dolist (directory (eureka-example--application-dirs))
        (dolist (file (directory-files-recursively directory "\\.desktop\\'"))
          (let ((id (replace-regexp-in-string
                     "/" "-" (file-relative-name file directory) t t)))
            (unless (gethash id seen)
              (puthash id t seen)
              (when-let ((application
                          (eureka-example--desktop-entry file)))
                (push application applications)))))
      (setq eureka-example--application-cache
            (sort applications
                  (lambda (left right)
                    (string-lessp (car left) (car right)))))))
  eureka-example--application-cache))

(defun eureka-example-launch-program (&optional refresh)
  "Select and launch an XDG desktop application.
With prefix argument REFRESH, rebuild the application cache first."
  (interactive "P")
  (unless (executable-find "gio")
    (user-error "gio is required to launch desktop files"))
  (let* ((applications (eureka-example--applications refresh))
         (choice (completing-read "Launch: " applications nil t))
         (desktop-file (cdr (assoc choice applications))))
    (unless desktop-file
      (user-error "No desktop file for %s" choice))
    (eureka-example--run "gio" "launch" desktop-file)))

;;; Window and process commands

(defun eureka-example-terminal ()
  "Launch `eureka-example-terminal-command'."
  (interactive)
  (apply #'eureka-example--run eureka-example-terminal-command))

(defun eureka-example-close-view ()
  "Close the selected client view without killing ordinary Emacs buffers."
  (interactive)
  (let ((buffer (current-buffer))
        (window (selected-window)))
    (if (derived-mode-p 'eureka-mode)
        (progn
          ;; Killing a Eureka buffer requests that the corresponding client
          ;; close.  Native closure is asynchronous, so remove the view now.
          (kill-buffer buffer)
          (if (one-window-p t)
              (switch-to-buffer (other-buffer buffer t))
            (delete-window window)))
      (if (one-window-p t)
          (bury-buffer buffer)
        (delete-window window)))))

(defun eureka-example-lock ()
  (interactive)
  (apply #'eureka-example--run eureka-example-lock-command))

(defun eureka-example-suspend ()
  (interactive)
  (eureka-example--run "systemctl" "suspend"))

(defun eureka-example--confirmed-system-action (action)
  (save-some-buffers)
  (when (y-or-n-p (format "Really %s? " action))
    (eureka-example--run "systemctl" action)))

(defun eureka-example-reboot ()
  (interactive)
  (eureka-example--confirmed-system-action "reboot"))

(defun eureka-example-poweroff ()
  (interactive)
  (eureka-example--confirmed-system-action "poweroff"))

(defun eureka-example-exit-session ()
  (interactive)
  (save-some-buffers)
  (when (and (y-or-n-p "Exit the Eureka session? ") eureka-handle)
    (eureka-exit-session eureka-handle)))

(defconst eureka-example-power-actions
  '(("Lock" . eureka-example-lock)
    ("Suspend" . eureka-example-suspend)
    ("Exit session" . eureka-example-exit-session)
    ("Reboot" . eureka-example-reboot)
    ("Power off" . eureka-example-poweroff)))

(defun eureka-example-power-menu ()
  (interactive)
  (let* ((choice (completing-read
                  "Session: " eureka-example-power-actions nil t))
         (command (cdr (assoc choice eureka-example-power-actions))))
    (call-interactively command)))

;;; Hardware keys

(defun eureka-example--call-process (program &rest arguments)
  (unless (executable-find program)
    (user-error "%s is not installed" program))
  (unless (zerop (apply #'call-process program nil nil nil arguments))
    (user-error "%s failed" program)))

(defun eureka-example-volume-up ()
  (interactive)
  (eureka-example--call-process
   "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05+" "-l" "1.5"))

(defun eureka-example-volume-down ()
  (interactive)
  (eureka-example--call-process
   "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05-"))

(defun eureka-example-volume-mute ()
  (interactive)
  (eureka-example--call-process
   "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"))

(defun eureka-example-microphone-mute ()
  (interactive)
  (eureka-example--call-process
   "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"))

(defun eureka-example-brightness-up ()
  (interactive)
  (eureka-example--call-process "brightnessctl" "set" "+10%"))

(defun eureka-example-brightness-down ()
  (interactive)
  (eureka-example--call-process "brightnessctl" "set" "10%-"))

;;; Key policy and lifecycle

(defvar eureka-example-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s-x") #'eureka-example-launch-program)
    (define-key map (kbd "s-<return>") #'eureka-example-terminal)
    (define-key map (kbd "s-q") #'eureka-example-close-view)
    (define-key map (kbd "s-SPC") #'switch-to-buffer)
    (define-key map (kbd "s-o") #'other-window)
    (define-key map (kbd "s-/") #'split-window-right)
    (define-key map (kbd "s--") #'split-window-below)
    (define-key map (kbd "C-s-f") #'toggle-frame-fullscreen)
    (define-key map (kbd "s-<escape>") #'eureka-example-power-menu)
    (define-key map (kbd "<XF86AudioRaiseVolume>")
                #'eureka-example-volume-up)
    (define-key map (kbd "<XF86AudioLowerVolume>")
                #'eureka-example-volume-down)
    (define-key map (kbd "<XF86AudioMute>")
                #'eureka-example-volume-mute)
    (define-key map (kbd "<XF86AudioMicMute>")
                #'eureka-example-microphone-mute)
    (define-key map (kbd "<XF86MonBrightnessUp>")
                #'eureka-example-brightness-up)
    (define-key map (kbd "<XF86MonBrightnessDown>")
                #'eureka-example-brightness-down)
    map))

(define-minor-mode eureka-example-mode
  "Install the example Eureka desktop key policy."
  :global t
  :keymap eureka-example-mode-map)

(defconst eureka-example-intercept-prefixes
  '("s-x" "s-<return>" "s-q" "s-SPC" "s-o" "s-/" "s--"
    "C-s-f" "s-<escape>"
    "<XF86AudioRaiseVolume>" "<XF86AudioLowerVolume>"
    "<XF86AudioMute>" "<XF86AudioMicMute>"
    "<XF86MonBrightnessUp>" "<XF86MonBrightnessDown>"))

(defun eureka-example--push-native-bindings ()
  "Register bindings implemented directly by Eureka's native worker."
  (eureka-push-intercept-prefix "C-s-f" 'toggle-fullscreen))

(defun eureka-example-start ()
  "Enable the portable example policy and start Eureka.
Call this after River starts Emacs as its window manager."
  (interactive)
  (setq eureka-intercept-prefixes eureka-example-intercept-prefixes)
  (eureka-example-mode 1)
  (add-hook 'eureka-enable-hook #'eureka-example--push-native-bindings)
  (condition-case error-data
      (eureka-enable)
    (error
     (eureka-example-mode -1)
     (signal (car error-data) (cdr error-data)))))

(defun eureka-example-stop ()
  "Stop Eureka and remove the example key policy."
  (interactive)
  (eureka-disable)
  (eureka-example-mode -1))

(provide 'eureka-example)
;;; example.el ends here
