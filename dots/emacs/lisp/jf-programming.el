;;; jf-programming.el --- Programming modes and language tooling -*- lexical-binding: t; -*-

(require 'subr-x)
(require 'use-package)

;;; Language servers

(use-package eglot
  :hook ((typst-ts-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)
         (nix-mode . eglot-ensure))
  :config
  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-sync-connect nil
        eglot-connect-timeout 10
        eglot-send-changes-idle-time 0.5
        eldoc-idle-delay 0.5
        eglot-autoshutdown t)
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) .
                 ("basedpyright-langserver" "--stdio")))
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nil"))))

(when (and (treesit-available-p)
           (treesit-language-available-p 'python))
  (add-to-list 'major-mode-remap-alist '(python-mode . python-ts-mode)))

;;; Typst

(defun jf/typst-format-buffer ()
  "Format the current Typst buffer with typstyle."
  (interactive)
  (unless (executable-find "typstyle")
    (user-error "typstyle executable not found"))
  (let ((point (point))
        (window-start-pos (window-start))
        (output-buffer (generate-new-buffer " *typstyle output*"))
        (error-file (make-temp-file "typstyle-errors-")))
    (unwind-protect
        (let ((status (call-process-region
                       (point-min) (point-max)
                       "typstyle" nil
                       (list output-buffer error-file)
                       nil)))
          (if (zerop status)
              (let ((formatted (with-current-buffer output-buffer
                                 (buffer-string))))
                (unless (string= formatted (buffer-string))
                  (erase-buffer)
                  (insert formatted))
                (goto-char (min point (point-max)))
                (set-window-start nil (min window-start-pos (point-max)) t)
                (message "Formatted with typstyle"))
            (user-error "typstyle failed: %s"
                        (string-trim
                         (with-temp-buffer
                           (insert-file-contents error-file)
                           (buffer-string))))))
      (kill-buffer output-buffer)
      (ignore-errors
        (delete-file error-file)))))

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  :bind (:map typst-ts-mode-map
              ("C-c C-f" . jf/typst-format-buffer))
  :config
  (setq treesit-font-lock-level 4
        typst-ts-preview-function #'find-file)
  (add-hook 'typst-ts-compile-before-compilation-hook #'save-buffer)
  (add-hook 'typst-ts-watch-before-watch-hook #'save-buffer)
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(typst-ts-mode . ("tinymist")))))

(use-package typst-preview
  :after typst-ts-mode
  :bind (:map typst-ts-mode-map
              ("C-c C-v" . typst-preview-mode)
              ("C-c C-j" . typst-preview-send-position))
  :config
  (setq typst-preview-ask-if-pin-main nil
        typst-preview-autostart t
        typst-preview-open-browser-automatically t
        typst-preview-executable "tinymist"))

(provide 'jf-programming)
;;; jf-programming.el ends here
