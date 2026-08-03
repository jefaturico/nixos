;;; jf-org.el --- Org editing and agenda -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'use-package)

;; Declared by org-agenda.el.  Declare them special before the lexical bindings
;; below are read, even though org-agenda itself is loaded lazily.
(defvar org-agenda-buffer-name "*Org Agenda*")
(defvar org-agenda-skip-function nil)

;;; Presentation helpers

(defface jf/org-agenda-top-padding
  '((t (:inherit default :height 0.25 :extend t :box nil
        :underline nil :overline nil)))
  "Face for the small blank header above agenda buffers.")

(defun jf/org-agenda-add-top-padding ()
  "Add top spacing without inserting a non-agenda buffer line."
  (setq-local header-line-format
              '(:propertize " "
                            display (space :align-to (- right-fringe 0))
                            face jf/org-agenda-top-padding)))

(defun jf/org-disable-prose-completion ()
  "Disable dictionary-word completion while retaining Org completion."
  (setq-local completion-at-point-functions
              (remove #'ispell-completion-at-point
                      completion-at-point-functions)))

(defun jf/apply-org-heading-faces ()
  "Apply a restrained size hierarchy to Org and agenda headings."
  (dolist (face-height '((org-level-1 . 1.30)
                         (org-level-2 . 1.20)
                         (org-level-3 . 1.10)))
    (set-face-attribute (car face-height) nil
                        :height (cdr face-height)
                        :weight 'semi-bold))
  (dolist (face '(org-level-4 org-level-5 org-level-6
                  org-level-7 org-level-8))
    (set-face-attribute face nil :height 1.0 :weight 'semi-bold))
  (set-face-attribute 'org-agenda-structure nil
                      :height 1.15 :weight 'bold)
  (dolist (face '(org-agenda-date org-agenda-date-today
                  org-agenda-date-weekend))
    (set-face-attribute face nil :height 1.15 :weight 'bold)))

(with-eval-after-load 'org
  (jf/apply-org-heading-faces))

;; The initial agenda visits agenda.org before there is an interactive startup
;; buffer in which to answer a local-variable safety prompt.  Trust this exact,
;; non-evaluating archive destination up front so agenda construction cannot be
;; replaced by the *Local Variables* query buffer.
(add-to-list 'safe-local-variable-values
             '(org-archive-location . "archive.org::* Archived Tasks"))

;;; Org editing

(defconst jf/org-drill-directory
  (expand-file-name "~/documents/org/drill/")
  "Directory containing Org-Drill card files.")

(defun jf/org-drill-capture-file ()
  "Return the default flashcard file, creating its directory if needed."
  (make-directory jf/org-drill-directory t)
  (expand-file-name "flashcards.org" jf/org-drill-directory))

(use-package org
  :hook ((org-mode . jf/reading-layout)
         (org-mode . jf/org-disable-prose-completion)
         (org-agenda-mode . jf/org-agenda-add-top-padding))
  :config
  (setq org-directory "~/documents/org/"

        ;; Org 9.8 otherwise eagerly loads eleven legacy/link integrations
        ;; (BBDB, BibTeX, Gnus, IRC, Rmail, W3M, etc.) the first time any Org
        ;; buffer opens.  None is used by this configuration; individual
        ;; integrations can still be required explicitly if needed later.
        org-modules nil

        org-capture-templates
        '(("i" "inbox" entry
           (file "~/documents/org/inbox.org")
           "* [%<%Y-%m-%d %H:%M>] %?"
          :empty-lines 1)
          ("t" "task" entry
           (file+headline "~/documents/org/agenda.org" "Tasks")
           "* TODO %?"
           :empty-lines 1)
          ("e" "event" entry
           (file+headline "~/documents/org/agenda.org" "Events")
           "* %?\n%^T"
           :empty-lines 1)
          ("f" "flashcard" entry
           (file jf/org-drill-capture-file)
           "* %^{Question} :drill:\n** Answer\n%?"
           :empty-lines 1))

        org-agenda-files '("~/documents/org/agenda.org")
        org-todo-keywords '((sequence "TODO(t)" "WAIT(w!)" "|" "CANCELLED(c!)" "DONE(d!)"))
        org-ellipsis " ▾"
        org-hide-emphasis-markers t
        org-startup-truncated nil
        org-return-follows-link t
        org-agenda-window-setup 'current-window
        org-agenda-block-separator nil
        org-agenda-compact-blocks t
        org-M-RET-may-split-line '((default . nil))
        org-insert-heading-respect-content t
        org-log-done 'time
        org-log-into-drawer t
        org-tags-column 0
        org-startup-folded 'content
        org-cycle-separator-lines 1
        org-element-cache-persistent t
        org-fontify-whole-heading-line t
        org-fontify-done-headline nil
        org-fontify-quote-and-verse-blocks t
        org-startup-indented t
        org-startup-with-inline-images t
        org-startup-with-latex-preview t
        org-pretty-entities t
        org-use-sub-superscripts '{}
        org-agenda-inhibit-startup t
        org-agenda-use-tag-inheritance nil
        org-agenda-ignore-properties '(effort appt category)
        org-agenda-dim-blocked-tasks nil
        org-auto-align-tags nil
        org-fold-catch-invisible-edits 'show-and-error
        org-preview-latex-default-process 'dvisvgm
        org-format-latex-options
        (plist-put
         (plist-put org-format-latex-options :background "Transparent")
         :scale 1.5))

  (with-eval-after-load 'ol
    (setf (cdr (assq 'file org-link-frame-setup)) #'find-file)))

(use-package org-timer
  :ensure nil
  :commands (org-timer-set-timer org-timer-pause-or-continue org-timer-stop)
  :init
  (setq org-timer-default-timer "25")
  :config
  (require 'notifications)
  (setq org-show-notification-handler
        (lambda (message)
          (notifications-notify :title "Org timer" :body message))))

;;; Agenda lifecycle and startup

(defun jf/org-agenda-archive-completed ()
  "Archive agenda tasks completed before the current calendar day."
  (interactive)
  (require 'org)
  (require 'org-archive)
  (let* ((now (decode-time))
         (today (encode-time 0 0 0
                             (decoded-time-day now)
                             (decoded-time-month now)
                             (decoded-time-year now)))
         (archived 0))
    (dolist (file (org-agenda-files t))
      (when (file-readable-p file)
        (with-current-buffer (find-file-noselect file)
          (let (completed)
            (org-with-wide-buffer
             (org-map-entries
              (lambda ()
                (let ((state (org-get-todo-state))
                      (closed (org-entry-get nil "CLOSED")))
                  (when (and (member state '("DONE" "CANCELLED"))
                             closed
                             (time-less-p (org-time-string-to-time closed)
                                          today))
                    (push (point-marker) completed))))
              nil 'file)
             ;; Moving subtrees from bottom to top keeps every earlier marker
             ;; stable while the current subtree is removed.
             (dolist (marker (sort completed
                                   (lambda (a b)
                                     (> (marker-position a)
                                        (marker-position b)))))
               (goto-char marker)
               (org-archive-subtree)
               (set-marker marker nil)
               (cl-incf archived)))
            (when (buffer-modified-p)
              (save-buffer))))))
    (message "Archived %d completed task%s"
             archived (if (= archived 1) "" "s"))
    archived))

;; Cancel the legacy automatic job when reloading this file in a session that
;; was started with the old configuration.  Fresh sessions create no archive
;; timer and perform no automatic agenda-file writes.
(when (and (boundp 'jf/org-archive-timer)
           (timerp (symbol-value 'jf/org-archive-timer)))
  (cancel-timer (symbol-value 'jf/org-archive-timer)))

;;; Extensions

(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode))

(defun jf/org-drill ()
  "Review due cards from every Org file in `jf/org-drill-directory'."
  (interactive)
  (require 'org-drill)
  (let ((files (and (file-directory-p jf/org-drill-directory)
                    (directory-files jf/org-drill-directory t
                                     "^[^.].*\\.org\\'"))))
    (unless files
      (user-error "No drill files in %s; capture a flashcard first"
                  jf/org-drill-directory))
    (org-drill files)))

(use-package org-drill
  :commands org-drill)

(provide 'jf-org)
;;; jf-org.el ends here
