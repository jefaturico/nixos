;;; -*- lexical-binding: t -*-
;;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'ert)
(require 'cl-lib)

;; The tests exercise Lisp policy without loading the native module.
(provide 'libeureka)
(load (expand-file-name "eureka.el" (file-name-directory load-file-name)) nil t)

(ert-deftest eureka-post-command-work-is-limited-to-injected-keys ()
  (let ((eureka--restore-focus-after-command nil)
        (scheduled 0))
    (cl-letf (((symbol-function 'eureka--mark-focus-dirty)
               (lambda (&rest _) (cl-incf scheduled))))
      (eureka--post-command-restore-focus)
      (should (= scheduled 0))
      (setq eureka--restore-focus-after-command t)
      (eureka--post-command-restore-focus)
      (should (= scheduled 1))
      (should-not eureka--restore-focus-after-command))))

(ert-deftest eureka-post-command-repairs-unexpected-frame-focus ()
  (let ((eureka--restore-focus-after-command nil)
        (scheduled 0))
    (with-temp-buffer
      (eureka-mode)
      (set-window-buffer (selected-window) (current-buffer))
      (cl-letf (((symbol-function 'eureka--mark-focus-dirty)
                 (lambda (&rest _) (cl-incf scheduled))))
        (eureka--post-command-restore-focus)
        (should (= scheduled 1))))))

(ert-deftest eureka-client-close-is-requested-once-and-keeps-buffer ()
  (let ((eureka-handle t)
        (eureka-window 7)
        (eureka--closed-by-wm nil)
        (eureka--close-requested nil)
        (requests 0))
    (cl-letf (((symbol-function 'eureka-close-window)
               (lambda (_handle id)
                 (should (= id 7))
                 (cl-incf requests)))
              ((symbol-function 'message) #'ignore))
      (should-not (eureka--confirm-client-close))
      (should eureka--close-requested)
      (should-not (eureka--confirm-client-close))
      (should (= requests 1))
      (setq eureka--closed-by-wm t)
      (should (eureka--confirm-client-close)))))

(ert-deftest eureka-focus-only-sync-omits-layout-recalculation ()
  (let ((eureka-handle t)
        (eureka--layout-generation 4)
        (eureka--layout-dirty nil)
        (eureka--focus-dirty t)
        captured)
    (cl-letf (((symbol-function 'eureka-sync-state)
               (lambda (&rest args) (setq captured args)))
              ((symbol-function 'eureka--current-focus-target) (lambda () 9))
              ((symbol-function 'eureka--all-window-parameters)
               (lambda () (ert-fail "focus-only sync recalculated layout"))))
      (eureka--sync-state)
      (should (equal captured '(t 5 nil 9)))
      (should-not eureka--focus-dirty))))

(ert-deftest eureka-new-buffer-replaces-workspace-placeholder ()
  (save-window-excursion
    (let* ((placeholder (generate-new-buffer " eureka-placeholder"))
           (client (generate-new-buffer " eureka-client"))
           (eureka-placeholder-buffer-predicate
            (lambda (buffer) (eq buffer placeholder))))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) placeholder)
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _)
                         (ert-fail "placeholder did not get replaced"))))
              (should (eq (eureka--display-new-buffer client)
                          (selected-window)))
              (should (eq (window-buffer) client))))
        (kill-buffer placeholder)
        (kill-buffer client)))))

(ert-deftest eureka-new-buffer-selects-displayed-window ()
  (let ((eureka-placeholder-buffer-predicate nil)
        (client (generate-new-buffer " eureka-client"))
        selected)
    (unwind-protect
        (cl-letf (((symbol-function 'display-buffer)
                   (lambda (_buffer) (selected-window)))
                  ((symbol-function 'select-window)
                   (lambda (window &optional _norecord)
                     (setq selected window))))
          (eureka--display-new-buffer client)
          (should (eq selected (selected-window))))
      (kill-buffer client))))

(ert-deftest eureka-intercepted-prefix-keeps-focus-on-emacs ()
  (let ((eureka--restore-focus-after-command t)
        (this-command nil)
        (unread-command-events nil))
    (with-temp-buffer
      (eureka-mode)
      (setq-local eureka-window 7)
      (set-window-buffer (selected-window) (current-buffer))
      (should-not (eureka--current-focus-target)))))

(ert-deftest eureka-completed-intercept-restores-client-during-post-command ()
  ;; Zero-delay timers scheduled from `post-command-hook' may run before Emacs
  ;; clears `this-command'.  A completed intercepted command must nevertheless
  ;; return keyboard focus to the selected client.
  (let ((eureka--restore-focus-after-command nil)
        (this-command 'ignore)
        (unread-command-events nil))
    (with-temp-buffer
      (eureka-mode)
      (setq-local eureka-window 7)
      (set-window-buffer (selected-window) (current-buffer))
      (should (= 7 (eureka--current-focus-target))))))

(ert-deftest eureka-layout-sync-with-typeahead-keeps-client-focus ()
  ;; Splitting windows and changing displayed buffers schedules layout syncs.
  ;; User type-ahead queued at that instant belongs to the focused client and
  ;; must not make the layout update redirect the keyboard to Emacs.
  (let ((eureka--restore-focus-after-command nil)
        (unread-command-events '(?a ?b)))
    (with-temp-buffer
      (eureka-mode)
      (setq-local eureka-window 7)
      (set-window-buffer (selected-window) (current-buffer))
      (should (= 7 (eureka--current-focus-target))))))

(ert-deftest eureka-layout-sync-in-recursive-command-keeps-client-focus ()
  ;; A recursive edit can likewise be sampled by a layout timer.  The selected
  ;; Eureka buffer remains the authoritative focus target unless a minibuffer
  ;; or injected command explicitly requires Emacs input.
  (let ((eureka--restore-focus-after-command nil))
    (with-temp-buffer
      (eureka-mode)
      (setq-local eureka-window 7)
      (set-window-buffer (selected-window) (current-buffer))
      (cl-letf (((symbol-function 'recursion-depth) (lambda () 1)))
        (should (= 7 (eureka--current-focus-target)))))))

(provide 'eureka-tests)
