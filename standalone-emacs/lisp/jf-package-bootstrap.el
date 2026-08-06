;;; jf-package-bootstrap.el --- Conditional package bootstrap -*- lexical-binding: t; -*-

(require 'package)

(defconst jf/required-packages
  '((cape . "cape")
    (consult . "consult")
    (corfu . "corfu")
    (ef-themes . "ef-themes")
    (elfeed . "elfeed")
    (gcmh . "gcmh")
    ;; The copied configuration uses gptel's OAuth backend, not merely its
    ;; core library.  An older system gptel must therefore not suppress the
    ;; package.el fallback.
    (gptel . "gptel-openai-oauth")
    (hledger-mode . "hledger-mode")
    (markdown-mode . "markdown-mode")
    (marginalia . "marginalia")
    (nix-mode . "nix-mode")
    (orderless . "orderless")
    (org-drill . "org-drill")
    (org-fragtog . "org-fragtog")
    (org-roam . "org-roam")
    (org-roam-ui . "org-roam-ui")
    (typst-preview . "typst-preview")
    (typst-ts-mode . "typst-ts-mode")
    (use-package . "use-package")
    (vertico . "vertico")
    (visual-fill-column . "visual-fill-column")
    (vterm . "vterm"))
  "Package names and representative libraries required by this configuration.

The library test is intentional: Nix-installed Emacs packages are normally on
`load-path' even though package.el does not consider them installed.")

(defvar jf/package-archives-refreshed nil)

(defun jf/package-library-available-p (package library)
  "Return non-nil when PACKAGE or LIBRARY is already available."
  (or (package-installed-p package)
      (locate-library library)))

(defun jf/ensure-package (package library)
  "Install PACKAGE only when its representative LIBRARY cannot be found."
  (unless (jf/package-library-available-p package library)
    (unless jf/package-archives-refreshed
      (package-refresh-contents)
      (setq jf/package-archives-refreshed t))
    (package-install package)))

(defun jf/ensure-required-packages ()
  "Initialize package.el and make every configured library available."
  (setq package-archives
        '(("gnu" . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/nongnu/")
          ("melpa" . "https://melpa.org/packages/")))
  (package-initialize)
  (dolist (entry jf/required-packages)
    (jf/ensure-package (car entry) (cdr entry))))

(provide 'jf-package-bootstrap)
;;; jf-package-bootstrap.el ends here
