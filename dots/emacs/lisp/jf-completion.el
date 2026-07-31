;;; jf-completion.el --- Minibuffer and in-buffer completion -*- lexical-binding: t; -*-

(require 'use-package)

;;; Minibuffer completion

(use-package savehist
  :config
  (savehist-mode 1))

(use-package vertico
  :config
  (require 'vertico-sort)
  (require 'vertico-multiform)
  (setq vertico-count 20
        vertico-cycle nil
        vertico-multiform-categories
        '((command (vertico-sort-function . vertico-sort-history-alpha))))
  (vertico-mode)
  (vertico-multiform-mode))

(use-package marginalia
  :config
  (marginalia-mode))

(use-package consult
  :demand t
  :bind (("C-x b" . consult-buffer)
         ("M-y"   . consult-yank-pop)
         ("M-g g" . consult-goto-line)
         ("M-g i" . consult-imenu)
         ("M-g r" . consult-grep))
  :custom
  (consult-narrow-key "<")
  :config
  ;; Previewing while moving through recent files and buffers loads too much.
  (consult-customize
   consult-recent-file
   consult-buffer
   :preview-key "M-.")

  ;; A dedicated source lets the Eureka bindings choose explicitly between
  ;; context-local and global buffer lists.
  (defvar jf/consult-source-context-buffer nil
    "Consult source containing buffers in the current Tabspaces context.")
  (setq jf/consult-source-context-buffer
        (list :name "Context buffers"
              :narrow ?w
              :history 'buffer-name-history
              :category 'buffer
              :state #'consult--buffer-state
              :default t
              :items (lambda ()
                       (consult--buffer-query
                        :predicate #'tabspaces--local-buffer-p
                        :sort 'visibility
                        :as #'buffer-name)))))

(defun jf/consult-buffer-contexts ()
  "Select a buffer belonging to the current context."
  (interactive)
  (setf (plist-get jf/consult-source-context-buffer :name)
        (format "Buffers (%s)" (tabspaces--current-tab-name)))
  (consult-buffer (list jf/consult-source-context-buffer)))

(defun jf/consult-buffer-global ()
  "Select a live buffer from every context."
  (interactive)
  (let ((source (copy-tree consult-source-buffer)))
    (plist-put source :name "All buffers")
    (plist-put source :hidden nil)
    (plist-put source :default t)
    (consult-buffer (list source))))

(use-package which-key
  :defer 2
  :config
  (setq which-key-idle-delay 0.0
        which-key-idle-secondary-delay 0.05)
  (which-key-mode))

;;; Completion at point

(defun jf/corfu-prose-setup ()
  "Keep Corfu available on demand without automatic popups in prose."
  (setq-local corfu-auto nil))

(use-package corfu
  :demand t
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-min-width 20)
  (corfu-max-width 100)
  (corfu-count 14)
  (corfu-preselect 'prompt)
  :hook
  (text-mode . jf/corfu-prose-setup)
  :config
  (global-corfu-mode))

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  :config
  (require 'cape-keyword)
  (add-to-list 'completion-at-point-functions #'cape-keyword))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles basic partial-completion)))))

(provide 'jf-completion)
;;; jf-completion.el ends here
