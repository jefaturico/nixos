;;; jf-eureka-session.el --- Eureka session and power management -*- lexical-binding: t; -*-

(require 'eureka)
(require 'subr-x)

(declare-function eureka-exit-session "eureka" (handle))
(declare-function jf/start-inhibitor "jf-core" (name what who why))
(declare-function jf/release-shutdown-inhibitor "jf-core" ())
(declare-function jf/save-worthy-buffer-p "jf-core" (&optional buffer))
(defvar jf/shutdown-inhibitor-process)

;;; Process and logind integration

(defun jf-eureka-run (&rest command)
  "Run COMMAND detached from Emacs and report failures."
  (let* ((name (concat "jf-eureka-" (car command)))
         (buffer (generate-new-buffer (format " *%s*" name)))
         (process (make-process :name name
                                :buffer buffer
                                :command command
                                :noquery t
                                :sentinel #'jf-eureka--command-sentinel)))
    (set-process-query-on-exit-flag process nil)
    process))

(defun jf-eureka--command-sentinel (process _event)
  "Report a failed detached PROCESS and clean up its output buffer."
  (when (memq (process-status process) '(exit signal))
    (let ((buffer (process-buffer process)))
      (unwind-protect
          (unless (zerop (process-exit-status process))
            (let ((output
                   (when (buffer-live-p buffer)
                     (with-current-buffer buffer
                       (string-trim (buffer-string))))))
              (display-warning
               'eureka
               (format "%s failed%s"
                       (string-join (process-command process) " ")
                       (if (string-empty-p (or output ""))
                           ""
                         (concat ": " output)))
               :error)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(defvar jf-eureka--power-key-inhibitor-process nil
  "Process inhibiting logind power-key handling while Eureka is active.")

(defun jf-eureka--inhibit-logind-power-key ()
  "Let Eureka handle the hardware power key instead of logind."
  (unless (process-live-p jf-eureka--power-key-inhibitor-process)
    (when-let ((process
                (if (fboundp 'jf/start-inhibitor)
                    (jf/start-inhibitor
                     "eureka-power-key-inhibitor"
                     "handle-power-key"
                     "Eureka"
                     "Eureka handles the power key.")
                  nil)))
      (setq jf-eureka--power-key-inhibitor-process
            process)
      (set-process-query-on-exit-flag
       jf-eureka--power-key-inhibitor-process nil))))

(defun jf-eureka--release-logind-power-key ()
  "Release Eureka's logind power-key inhibitor."
  (when (process-live-p jf-eureka--power-key-inhibitor-process)
    (delete-process jf-eureka--power-key-inhibitor-process))
  (setq jf-eureka--power-key-inhibitor-process nil))

(add-hook 'eureka-disable-hook #'jf-eureka--release-logind-power-key)
(add-hook 'kill-emacs-hook #'jf-eureka--release-logind-power-key)

;;; Power and session actions

(defun jf-eureka--run-power-action (action)
  "Run systemctl power ACTION after releasing Emacs' inhibitor.

Wait for the inhibitor process to exit instead of asking logind to bypass all
inhibitors, which would require administrator authentication and could discard
unsaved work belonging to another Emacs instance."
  (let ((inhibitor
         (and (boundp 'jf/shutdown-inhibitor-process)
              (process-live-p jf/shutdown-inhibitor-process)
              jf/shutdown-inhibitor-process)))
    (if (and inhibitor (fboundp 'jf/release-shutdown-inhibitor))
        (progn
          (set-process-sentinel
           inhibitor
           (lambda (process _event)
             (when (and (not (process-live-p process))
                        (not (process-get process 'jf-eureka-power-action-started)))
               (process-put process 'jf-eureka-power-action-started t)
               (jf-eureka-run "systemctl" action))))
          (jf/release-shutdown-inhibitor))
      (jf-eureka-run "systemctl" action))))

(defun jf-eureka-poweroff ()
  "Power off the system."
  (interactive)
  (when (jf-eureka--confirm-destructive-session-action "power off")
    (jf-eureka--run-power-action "poweroff")))

(defun jf-eureka-reboot ()
  "Reboot the system."
  (interactive)
  (when (jf-eureka--confirm-destructive-session-action "reboot")
    (jf-eureka--run-power-action "reboot")))

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
  '(("NetworkManager" . jf/network-manager)
    ("NixOS rebuild" . jf/nixos-rebuild)
    ("Suspend" . jf-eureka-suspend)
    ("Exit session" . jf-eureka-exit-session)
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
