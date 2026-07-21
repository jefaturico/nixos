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

(provide 'jf-eureka-launcher-tests)
;;; jf-eureka-launcher-tests.el ends here
