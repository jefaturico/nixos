;;; jf-eureka-notifications-tests.el --- Tests for EDNC presentation -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Test presentation policy without loading Eureka's native module.
(defvar eureka-handle nil)
(provide 'eureka)
(require 'jf-eureka-notifications)

(defun jf-eureka-notifications-test--notification (&optional urgency)
  "Return an EDNC notification with optional URGENCY."
  (ednc--notification-create
   :id 1
   :summary "Battery Critical"
   :body "Level: 5%"
   :hints (when urgency `(("urgency" (,urgency))))))

(ert-deftest jf-eureka-ordinary-notification-uses-echo-area ()
  (let ((notification (jf-eureka-notifications-test--notification 1))
        shown)
    (cl-letf (((symbol-function 'jf-eureka--notify)
               (lambda (summary body) (setq shown (list summary body))))
              ((symbol-function 'jf-eureka-notification--ensure-expiry)
               #'ignore))
      (jf-eureka-notification-present nil notification))
    (should (equal shown '("Battery Critical" "Level: 5%")))))

(ert-deftest jf-eureka-critical-notification-exits-fullscreen-and-shows-warning ()
  (let ((notification (jf-eureka-notifications-test--notification 2))
        (eureka-handle 'test-handle)
        (ednc-mode t)
        exited
        scheduled
        shown)
    (cl-letf (((symbol-function 'eureka-exit-fullscreen)
               (lambda (handle) (setq exited handle)))
              ((symbol-function 'jf-eureka-notification--ensure-expiry)
               #'ignore)
              ((symbol-function 'run-at-time)
               (lambda (_time _repeat function &rest args)
                 (setq scheduled (cons function args))))
              ((symbol-function 'jf-eureka-notification--show-critical)
               (lambda (value) (setq shown value)))
              ((symbol-function 'jf-eureka--notify)
               (lambda (&rest _) (ert-fail "Critical alert used echo area"))))
      (jf-eureka-notification-present nil notification)
      (apply (car scheduled) (cdr scheduled)))
    (should (eq exited 'test-handle))
    (should (eq shown notification))))

(ert-deftest jf-eureka-notifications-stop-cancels-presentation-timers ()
  (let ((jf-eureka-notification--presentation-timers '(first second))
        cancelled)
    (cl-letf (((symbol-function 'timerp) (lambda (_) t))
              ((symbol-function 'cancel-timer)
               (lambda (timer) (push timer cancelled))))
      (jf-eureka-notifications-stop))
    (should (equal cancelled '(second first)))
    (should-not jf-eureka-notification--presentation-timers)))

(ert-deftest jf-eureka-critical-notification-uses-dedicated-warning-buffer ()
  (let ((notification (jf-eureka-notifications-test--notification 2))
        warning)
    (cl-letf (((symbol-function 'display-warning)
               (lambda (type message level buffer-name)
                 (setq warning (list type message level buffer-name)))))
      (jf-eureka-notification--show-critical notification))
    (should
     (equal warning
            '(desktop-notification
              "Battery Critical: Level: 5%"
              :warning
              "*Critical Notifications*")))))

(provide 'jf-eureka-notifications-tests)
;;; jf-eureka-notifications-tests.el ends here
