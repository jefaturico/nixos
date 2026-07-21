;;; jf-org-roam.el --- Org-roam profiles and navigation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'use-package)

(defvar jf/emacs-state-directory)

;;; Session profile

(defvar jf/org-roam-current-profile 'personal
  "The org-roam profile active in this Emacs session.")

;;; Org-roam

(use-package org-roam
  :defer t
  :bind (("C-c r f" . org-roam-node-find)
         ("C-c r c" . org-roam-capture)
         ("C-c r i" . org-roam-node-insert)
         ("C-c r I" . jf/org-roam-node-insert-immediate)
         ("C-c r b" . org-roam-buffer-toggle)
         ("C-c r u" . org-roam-ui-open)
         ("C-c r d" . jf/org-roam-dailies-goto-date)
         ("C-c r p" . jf/org-roam-switch-profile)
         ("C-c r t" . org-roam-tag-add))
  :config
  (cl-defmethod org-roam-node-slug ((node org-roam-node))
    (let* ((title (downcase (org-roam-node-title node)))
           ;; `[:alnum:]' is Unicode-aware, so Spanish letters are retained.
           (slug (replace-regexp-in-string "[^[:alnum:]]+" "-" title)))
      (string-trim slug "-+" "-+")))

  (defconst jf/org-roam-profiles
    `((personal
       :directory "~/documents/roam/personal/"
       :database ,(expand-file-name "org-roam/personal.db"
                                    jf/emacs-state-directory)
       :dailies "journal/"
       :templates
       (("p" "[PERSONAL] note" plain "%?"
         :target (file+head "${slug}.org"
                            "#+title: ${title}\n")
         :unnarrowed t)))
      (diving
       :directory "~/documents/roam/diving/"
       :database ,(expand-file-name "org-roam/diving.db"
                                    jf/emacs-state-directory)
       :dailies nil
       :templates
       (("d" "[DIVING] nota" plain "%?"
         :target (file+head "${slug}.org"
                            ":PROPERTIES:\n:ID: ${id}\n:END:\n#+title: ${title}\n#+hugo_section: notas\n#+hugo_draft: true\n")
         :unnarrowed t))))
    "Configuration for each isolated org-roam profile.")

  (defun jf/org-roam--profile-plist (profile)
    "Return the configuration plist for PROFILE."
    (or (alist-get profile jf/org-roam-profiles)
        (user-error "Unknown org-roam profile: %s" profile)))

  (defun jf/org-roam-confirm-public-capture ()
    "Confirm creation of any note in the public diving profile."
    (when (and (eq jf/org-roam-current-profile 'diving)
               (not (yes-or-no-p
                     "DIVING: create this note in the public repository? ")))
      (user-error "Capture cancelled")))

  ;; This public hook runs after template selection but before Org-roam creates
  ;; or changes the target, covering captures and missing-node insertion.
  (add-hook 'org-roam-capture-preface-hook
            #'jf/org-roam-confirm-public-capture)

  (defun jf/org-roam-activate-profile (profile &optional quiet)
    "Activate PROFILE, rebuilding org-roam state in isolation.
When QUIET is non-nil, suppress the profile-change message."
    (let* ((settings (jf/org-roam--profile-plist profile))
           (directory (file-truename
                       (expand-file-name (plist-get settings :directory))))
           (database (expand-file-name (plist-get settings :database))))
      (org-roam-db-autosync-mode -1)
      (when (bound-and-true-p org-roam-ui-mode)
        (org-roam-ui-mode -1))
      (make-directory directory t)
      (make-directory (file-name-directory database) t)
      (setq jf/org-roam-current-profile profile
            org-roam-directory directory
            org-roam-db-location database
            org-roam-dailies-directory (plist-get settings :dailies)
            org-roam-capture-templates (plist-get settings :templates))
      (org-roam-db-autosync-mode 1)
      (force-mode-line-update t)
      (unless quiet
        (message "%s"
                 (if (eq profile 'diving)
                     "ORG-ROAM: DIVING — captures require confirmation"
                   "ORG-ROAM: PERSONAL")))))

  (defun jf/org-roam-switch-profile (profile)
    "Interactively switch to an isolated org-roam PROFILE."
    (interactive
     (list (intern
            (completing-read
             (format "Switch org-roam profile (currently %s): "
                     jf/org-roam-current-profile)
             (mapcar (lambda (entry) (symbol-name (car entry)))
                     jf/org-roam-profiles)
             nil t))))
    (jf/org-roam-activate-profile profile))

  (defun jf/org-roam-dailies-goto-date ()
    "Visit a personal daily note, rejecting dailies in public profiles."
    (interactive)
    (unless (eq jf/org-roam-current-profile 'personal)
      (user-error "Dailies are private; switch to the personal profile first"))
    (call-interactively #'org-roam-dailies-goto-date))

  (defun jf/org-roam-node-insert-immediate (arg &rest args)
    "Insert a node and finish capture immediately."
    (interactive "P")
    (let ((args (cons arg args))
          (org-roam-capture-templates
           (list (append (car org-roam-capture-templates)
                         '(:immediate-finish t)))))
      (apply #'org-roam-node-insert args)))

  ;; Never restore the last profile: every Emacs session starts private.
  (jf/org-roam-activate-profile 'personal t))

(use-package org-roam-ui
  :after org-roam
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start nil))

(provide 'jf-org-roam)
;;; jf-org-roam.el ends here
