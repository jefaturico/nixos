;;; jf-eureka-notifications.el --- Eureka presentation for EDNC -*- lexical-binding: t; -*-

(require 'ednc)
(require 'eureka)
(require 'subr-x)
(require 'jf-eureka-session)

;; Release the D-Bus service and hooks owned by an older copy when reloading.
(when (fboundp 'jf-eureka-notifications-stop)
  (jf-eureka-notifications-stop))

(defconst jf-eureka-notification-default-timeout 5
  "Seconds before a notification without a timeout is dismissed by EDNC.")

(defconst jf-eureka-critical-notifications-buffer
  "*Critical Notifications*")

(defvar jf-eureka-notification--presentation-timers nil
  "Pending timers that will display critical notifications.")

(defun jf-eureka-notification--hint (notification name)
  "Return hint NAME from EDNC NOTIFICATION."
  (when-let ((entry (assoc name (ednc-notification-hints notification))))
    (let ((value (cadr entry)))
      (while (and (listp value) (= (length value) 1))
        (setq value (car value)))
      value)))

(defun jf-eureka-notification--critical-p (notification)
  "Return non-nil when EDNC NOTIFICATION has critical urgency."
  (= (or (jf-eureka-notification--hint notification "urgency") 1) 2))

(defun jf-eureka-notification--dismiss-if-active (notification)
  "Dismiss EDNC NOTIFICATION when it is still active."
  (when (and notification (ednc-notification-parent notification))
    (ednc-dismiss-notification notification)))

(defun jf-eureka-notification--ensure-expiry (notification)
  "Give EDNC NOTIFICATION a finite default lifetime."
  (unless (timerp (ednc-notification-timer notification))
    (setf (ednc-notification-timer notification)
          (run-at-time jf-eureka-notification-default-timeout nil
                       #'jf-eureka-notification--dismiss-if-active
                       notification))))

(defun jf-eureka-notification--message (notification)
  "Return EDNC NOTIFICATION as plain display text."
  (let ((summary (ednc-notification-summary notification))
        (body (ednc-notification-body notification)))
    (if (string-empty-p body)
        summary
      (format "%s: %s" summary body))))

(defun jf-eureka-critical-notifications-clear ()
  "Clear the persistent critical-notification warning buffer."
  (interactive)
  (when-let ((buffer (get-buffer jf-eureka-critical-notifications-buffer)))
    (kill-buffer buffer)))

(defun jf-eureka-notification--show-critical (notification)
  "Append critical NOTIFICATION to a persistent, compact warning buffer."
  (display-warning 'desktop-notification
                   (jf-eureka-notification--message notification)
                   :warning jf-eureka-critical-notifications-buffer)
  (when-let ((buffer (get-buffer jf-eureka-critical-notifications-buffer)))
    (with-current-buffer buffer
      (setq-local header-line-format
                  " Critical notifications — q: clear ")
      (local-set-key (kbd "q") #'jf-eureka-critical-notifications-clear))
    (when-let ((window
                (display-buffer
                 buffer
                 '((display-buffer-in-side-window)
                   (side . bottom)
                   (slot . 0)
                   (window-height . 8)))))
      (fit-window-to-buffer window 10 4))))

(defun jf-eureka-notification--schedule-critical (notification)
  "Show critical NOTIFICATION after Eureka leaves fullscreen."
  (let (timer)
    (setq timer
          (run-at-time
           0.05 nil
           (lambda ()
             (setq jf-eureka-notification--presentation-timers
                   (delq timer jf-eureka-notification--presentation-timers))
             (when (bound-and-true-p ednc-mode)
               (jf-eureka-notification--show-critical notification)))))
    (push timer jf-eureka-notification--presentation-timers)))

(defun jf-eureka-notification-present (_old new)
  "Present NEW EDNC notification inside Eureka."
  (when new
    (jf-eureka-notification--ensure-expiry new)
    (if (jf-eureka-notification--critical-p new)
        (progn
          (when eureka-handle
            (eureka-exit-fullscreen eureka-handle))
          ;; Let Eureka finish leaving fullscreen before displaying the
          ;; persistent warning side window.
          (jf-eureka-notification--schedule-critical new))
      (jf-eureka--notify (ednc-notification-summary new)
                         (ednc-notification-body new)))))

(defun jf-notifications ()
  "Open EDNC's notification history."
  (interactive)
  (unless ednc-mode
    (jf-eureka-notifications-start))
  (pop-to-buffer (get-buffer-create ednc-log-name)))

(defun jf-eureka-notifications-start ()
  "Start EDNC as Eureka's freedesktop notification server."
  (add-hook 'ednc-notification-presentation-functions
            #'jf-eureka-notification-present)
  (ednc-mode 1))

(defun jf-eureka-notifications-stop ()
  "Stop EDNC and remove Eureka's presentation integration."
  (dolist (timer jf-eureka-notification--presentation-timers)
    (when (timerp timer)
      (cancel-timer timer)))
  (setq jf-eureka-notification--presentation-timers nil)
  (when (bound-and-true-p ednc-mode)
    (ednc-mode -1))
  (when (boundp 'ednc-notification-presentation-functions)
    (remove-hook 'ednc-notification-presentation-functions
                 #'jf-eureka-notification-present))
  (jf-eureka-critical-notifications-clear))

(provide 'jf-eureka-notifications)
;;; jf-eureka-notifications.el ends here
