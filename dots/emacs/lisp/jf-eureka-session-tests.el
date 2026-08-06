;;; jf-eureka-session-tests.el --- Tests for Eureka session actions -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Test session policy without loading Eureka's native module.
(defvar eureka-handle nil)
(provide 'eureka)
(require 'jf-eureka-session)

(ert-deftest jf-eureka-lock-runs-locker ()
  (let (command)
    (cl-letf (((symbol-function 'jf-eureka-run)
               (lambda (&rest args) (setq command args))))
      (jf-eureka-lock))
    (should (equal command '("eureka-lock")))))

(ert-deftest jf-eureka-power-menu-includes-lock ()
  (should (eq (alist-get "Lock" jf-eureka-power-menu-actions nil nil #'equal)
              #'jf-eureka-lock)))

(ert-deftest jf-eureka-power-action-does-not-bypass-inhibitors ()
  (let ((jf/shutdown-inhibitor-process nil)
        command)
    (cl-letf (((symbol-function 'jf-eureka-run)
               (lambda (&rest args) (setq command args))))
      (jf-eureka--run-power-action "poweroff"))
    (should (equal command '("systemctl" "poweroff")))))

(ert-deftest jf-eureka-power-action-waits-for-own-inhibitor ()
  (let ((jf/shutdown-inhibitor-process 'inhibitor)
        sentinel
        command
        live)
    (setq live t)
    (cl-letf (((symbol-function 'process-live-p) (lambda (_) live))
              ((symbol-function 'set-process-sentinel)
               (lambda (_process function) (setq sentinel function)))
              ((symbol-function 'process-get) (lambda (&rest _) nil))
              ((symbol-function 'process-put) #'ignore)
              ((symbol-function 'jf/release-shutdown-inhibitor)
               (lambda ()
                 (setq live nil)
                 (funcall sentinel 'inhibitor "finished")))
              ((symbol-function 'jf-eureka-run)
               (lambda (&rest args) (setq command args))))
      (jf-eureka--run-power-action "reboot"))
    (should (equal command '("systemctl" "reboot")))))

(provide 'jf-eureka-session-tests)
;;; jf-eureka-session-tests.el ends here
