;;; jf-eureka-launcher-tests.el --- Tests for Eureka launcher -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'jf-eureka-launcher)

(ert-deftest jf-eureka-applications-returns-cached-candidates ()
  (let ((jf-eureka--application-cache nil)
        (candidate '("Example" . "/tmp/example.desktop")))
    (cl-letf (((symbol-function 'jf-eureka--application-dirs)
               (lambda () '("/tmp/applications")))
              ((symbol-function 'directory-files-recursively)
               (lambda (&rest _) '("/tmp/applications/example.desktop")))
              ((symbol-function 'jf-eureka--desktop-entry)
               (lambda (_) candidate)))
      (should (equal (jf-eureka--applications) (list candidate)))
      (should (equal (jf-eureka--applications) (list candidate))))))

(ert-deftest jf-eureka-applications-disambiguates-duplicate-names ()
  (let ((jf-eureka--application-cache nil))
    (cl-letf (((symbol-function 'jf-eureka--application-dirs)
               (lambda () '("/tmp/applications")))
              ((symbol-function 'directory-files-recursively)
               (lambda (&rest _)
                 '("/tmp/applications/one.desktop"
                   "/tmp/applications/two.desktop")))
              ((symbol-function 'jf-eureka--desktop-entry)
               (lambda (file) (cons "Example" file))))
      (should
       (equal
        (jf-eureka--applications)
        '(("Example — one.desktop" . "/tmp/applications/one.desktop")
          ("Example — two.desktop" . "/tmp/applications/two.desktop")))))))

(ert-deftest jf-eureka-desktop-app-id-uses-xdg-desktop-id ()
  (let ((jf-eureka--desktop-ids (make-hash-table :test #'equal)))
    (puthash "/tmp/applications/vendor/example.desktop"
             "vendor-example.desktop"
             jf-eureka--desktop-ids)
    (should
     (equal (jf-eureka--desktop-app-id
             "/tmp/applications/vendor/example.desktop")
            "vendor-example"))))

(ert-deftest jf-eureka-launch-or-focus-launches-absent-application ()
  (let (launched)
    (cl-letf (((symbol-function 'jf-eureka--buffer-for-app-ids)
               (lambda (_) nil)))
      (jf-eureka-launch-or-focus
       "Example" '("org.example.App") (lambda () (setq launched t))))
    (should launched)))

(ert-deftest jf-eureka-launch-or-focus-selects-existing-application ()
  (let ((buffer (generate-new-buffer " *jf-eureka-existing*"))
        selected
        launched)
    (unwind-protect
        (cl-letf (((symbol-function 'jf-eureka--buffer-for-app-ids)
                   (lambda (_) buffer))
                  ((symbol-function 'switch-to-buffer)
                   (lambda (candidate) (setq selected candidate)))
                  ((symbol-function 'y-or-n-p)
                   (lambda (_) nil)))
          (jf-eureka-launch-or-focus
           "Example" '("org.example.App") (lambda () (setq launched t)))
          (should (eq selected buffer))
          (should-not launched))
      (kill-buffer buffer))))

(ert-deftest jf-eureka-launch-or-focus-can-launch-another-instance ()
  (let ((buffer (generate-new-buffer " *jf-eureka-existing*"))
        launched)
    (unwind-protect
        (cl-letf (((symbol-function 'jf-eureka--buffer-for-app-ids)
                   (lambda (_) buffer))
                  ((symbol-function 'switch-to-buffer) #'ignore)
                  ((symbol-function 'y-or-n-p) (lambda (_) t)))
          (jf-eureka-launch-or-focus
           "Example" '("org.example.App") (lambda () (setq launched t)))
          (should launched))
      (kill-buffer buffer))))

(ert-deftest jf-eureka-launch-program-routes-through-launch-or-focus ()
  (let (received-name received-app-ids)
    (cl-letf (((symbol-function 'executable-find) (lambda (_) "/bin/gio"))
              ((symbol-function 'jf-eureka--applications)
               (lambda (_) '(("Example" . "/tmp/org.example.App.desktop"))))
              ((symbol-function 'completing-read)
               (lambda (&rest _) "Example"))
              ((symbol-function 'jf-eureka-launch-or-focus)
               (lambda (name app-ids _launch-function)
                 (setq received-name name
                       received-app-ids app-ids))))
      (jf-eureka-launch-program)
      (should (equal received-name "Example"))
      (should (equal received-app-ids '("org.example.App"))))))

(ert-deftest jf-eureka-buffer-for-app-ids-ignores-other-buffers ()
  (let ((ordinary (generate-new-buffer " *jf-ordinary*"))
        (wrong-app (generate-new-buffer " *jf-eureka-wrong*"))
        (matching-app (generate-new-buffer " *jf-eureka-match*")))
    (unwind-protect
        (progn
          (with-current-buffer wrong-app
            (setq major-mode 'eureka-mode)
            (setq-local eureka-app-id "org.example.Other"))
          (with-current-buffer matching-app
            (setq major-mode 'eureka-mode)
            (setq-local eureka-app-id "org.example.App"))
          (cl-letf (((symbol-function 'buffer-list)
                     (lambda () (list ordinary wrong-app matching-app))))
            (should
             (eq (jf-eureka--buffer-for-app-ids '("org.example.App"))
                 matching-app))))
      (mapc (lambda (buffer)
              (when (buffer-live-p buffer)
                (kill-buffer buffer)))
            (list ordinary wrong-app matching-app)))))

(provide 'jf-eureka-launcher-tests)
;;; jf-eureka-launcher-tests.el ends here
