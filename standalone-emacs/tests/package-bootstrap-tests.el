;;; package-bootstrap-tests.el --- Bootstrap tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(add-to-list 'load-path
             (expand-file-name "../lisp"
                               (file-name-directory load-file-name)))
(require 'jf-package-bootstrap)

(ert-deftest jf/bootstrap-keeps-load-path-packages ()
  "A Nix/system library on `load-path' must never reach package.el."
  (let ((jf/required-packages '((subr-x . "subr-x")))
        (jf/package-archives-refreshed nil))
    (cl-letf (((symbol-function 'package-refresh-contents)
               (lambda () (ert-fail "refreshed package metadata")))
              ((symbol-function 'package-install)
               (lambda (_package) (ert-fail "installed an available package"))))
      (jf/ensure-required-packages))))

(ert-deftest jf/bootstrap-refreshes-once-for-missing-packages ()
  "Several absent libraries cause one refresh and one install apiece."
  (let ((jf/required-packages
         '((jf-test-one . "jf-library-that-does-not-exist-one")
           (jf-test-two . "jf-library-that-does-not-exist-two")))
        (jf/package-archives-refreshed nil)
        (refreshes 0)
        installed)
    (cl-letf (((symbol-function 'package-initialize) #'ignore)
              ((symbol-function 'package-installed-p)
               (lambda (_package) nil))
              ((symbol-function 'locate-library)
               (lambda (_library) nil))
              ((symbol-function 'package-refresh-contents)
               (lambda () (cl-incf refreshes)))
              ((symbol-function 'package-install)
               (lambda (package) (push package installed))))
      (jf/ensure-required-packages))
    (should (= refreshes 1))
    (should (equal (nreverse installed) '(jf-test-one jf-test-two)))))

(provide 'package-bootstrap-tests)
;;; package-bootstrap-tests.el ends here
