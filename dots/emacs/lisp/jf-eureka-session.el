;;; jf-eureka-session.el --- Eureka session and power management -*- lexical-binding: t; -*-

(require 'eureka)
(require 'subr-x)

;;; Process and logind integration

(defun jf-eureka-run (&rest command)
  "Run COMMAND detached from Emacs."
  (let ((process
         (apply #'start-process
                (concat "jf-eureka-" (car command)) nil command)))
    (set-process-query-on-exit-flag process nil)
    process))

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
             "sleep" "infinity"))
      (set-process-query-on-exit-flag
       jf-eureka--power-key-inhibitor-process nil))))

(defun jf-eureka--release-logind-power-key ()
  "Release Eureka's logind power-key inhibitor."
  (when (process-live-p jf-eureka--power-key-inhibitor-process)
    (delete-process jf-eureka--power-key-inhibitor-process))
  (setq jf-eureka--power-key-inhibitor-process nil))

(add-hook 'eureka-disable-hook #'jf-eureka--release-logind-power-key)

;;; Power and session actions

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

;;; Session feedback

(defun jf-eureka--notify (summary &optional body)
  "Show SUMMARY and optional BODY inside Emacs."
  (message "%s%s" summary (if (and body (not (string-empty-p body)))
                              (concat ": " body)
                            "")))

(provide 'jf-eureka-session)
;;; jf-eureka-session.el ends here
