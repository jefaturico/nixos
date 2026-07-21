;;; jf-org.el --- Org editing and agenda dashboard -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'savehist)
(require 'use-package)

(declare-function jf/startup-mark "early-init" (event))

(defvar org-agenda-custom-commands)

;;; Presentation helpers

(use-package visual-fill-column
  :custom (visual-fill-column-center-text t)
  :commands visual-fill-column-mode)

(defun jf/visual-fill-org ()
  "Center Org buffers in a readable column width."
  (setq visual-fill-column-width 72)
  (visual-fill-column-mode 1))

(defun jf/visual-fill-agenda ()
  "Center agenda buffers in a wider column."
  (setq visual-fill-column-width 100)
  (visual-fill-column-mode 1))

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

(use-package org
  :hook ((org-mode . visual-line-mode)
         (org-mode . jf/visual-fill-org)
         (org-mode . jf/org-disable-prose-completion)
         (org-agenda-mode . jf/visual-fill-agenda)
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
          ("a" "agenda task" entry
           (file+headline "~/documents/org/agenda.org" "Tasks")
           "* TODO %? %^g"
           :empty-lines 1))

        org-agenda-files '("~/documents/org/agenda.org")
        org-todo-keywords '((sequence "TODO(t)" "WAIT(w!)" "|" "CANCELLED(c!)" "DONE(d!)"))
        org-ellipsis " ▾"
        org-hide-emphasis-markers t
        org-startup-truncated nil
        org-return-follows-link t
        org-agenda-span 'day
        org-agenda-window-setup 'current-window
        org-agenda-block-separator nil
        org-agenda-compact-blocks t
        org-M-RET-may-split-line '((default . nil))
        org-insert-heading-respect-content t
        org-log-done 'time
        org-log-into-drawer t
        org-tags-column 0
        org-startup-folded 'content
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

;;; Agenda lifecycle and dashboard

(defun jf/org-archive-completed-before-today ()
  "Archive completed agenda entries closed before the current calendar day."
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
    archived))

(defvar jf/org-archive-last-run-date nil
  "Calendar date when automatic Org archival last completed.")

(defvar jf/org-archive-timer nil
  "Idle timer responsible for once-daily Org archival.")

(add-to-list 'savehist-additional-variables 'jf/org-archive-last-run-date)

(defun jf/org-archive-daily-maintenance ()
  "Archive old completed tasks once per calendar day while Emacs is idle."
  (let ((today (format-time-string "%Y-%m-%d")))
    (unless (equal today jf/org-archive-last-run-date)
      (let ((count (jf/org-archive-completed-before-today)))
        (setq jf/org-archive-last-run-date today)
        (when (> count 0)
          (message "Archived %d completed task%s from previous days"
                   count (if (= count 1) "" "s")))))))

(when (timerp jf/org-archive-timer)
  (cancel-timer jf/org-archive-timer))
(setq jf/org-archive-timer
      (run-with-idle-timer 60 3600 #'jf/org-archive-daily-maintenance))

(defun jf/initial-agenda-buffer ()
  "Build and return the agenda used as the initial buffer."
  (jf/startup-mark "initial agenda start")
  (jf/startup-mark "require org-agenda start")
  (require 'org-agenda)
  (jf/startup-mark "require org-agenda end")
  (let ((this-command 'jf/org-agenda-dashboard)
        ;; Restoring an on-disk element cache costs far more than parsing the
        ;; 1.8 KB agenda source.  Keep persistent caching for normal Org files.
        (org-element-cache-persistent nil))
    (jf/startup-mark "agenda dashboard start")
    (jf/org-agenda-dashboard)
    (jf/startup-mark "agenda dashboard end")
    ;; The graphical Eureka session treats this startup dashboard as an empty
    ;; workspace: its first Wayland client replaces it instead of opening an
    ;; additional Emacs window.
    (setq-local jf-eureka--initial-placeholder t)
    ;; Measure the point at which the requested initial buffer has actually
    ;; been painted, rather than merely constructed in Lisp.
    (redisplay t)
    (jf/startup-mark "initial agenda first redisplay")
    (current-buffer)))

(defun jf/org-agenda--has-entries-p (match &optional undated)
  "Return non-nil when an agenda entry matches MATCH.
When UNDATED is non-nil, also require no schedule or deadline."
  (catch 'found
    (org-map-entries
     (lambda ()
       (when (or (not undated)
                 (and (not (org-entry-get nil "SCHEDULED"))
                      (not (org-entry-get nil "DEADLINE"))))
         (throw 'found t)))
     match 'agenda)
    nil))

(defun jf/org-agenda--compare-explicit-priority (a b)
  "Order agenda lines A and B by explicit priority, with none last."
  (let ((priority-a (if (string-match "\\[#[A-Z]\\]" a)
                        (aref (match-string 0 a) 2)
                      256))
        (priority-b (if (string-match "\\[#[A-Z]\\]" b)
                        (aref (match-string 0 b) 2)
                      256)))
    (cond ((< priority-a priority-b) -1)
          ((> priority-a priority-b) 1))))

(defun jf/org-agenda--separate-dashboard-sections ()
  "Put exactly one blank line before secondary dashboard sections."
  (let ((inhibit-read-only t))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "^\\(?:Upcoming Deadlines\\|Tasks Without a Date\\)$"
              nil t)
        (goto-char (line-beginning-position))
        (let ((header-start (point)))
          (skip-chars-backward "\n")
          (delete-region (point) header-start)
          (insert "\n\n")
          (forward-line 1)))))
  (unless (org-get-at-bol 'org-marker)
    (goto-char (point-min))
    (while (and (not (eobp))
                (not (org-get-at-bol 'org-marker)))
      (forward-line 1))))

(defun jf/org-agenda-later (arg)
  "Move the calendar component forward by ARG spans.
This also works when point is in another component of a composite agenda."
  (interactive "p")
  (let ((agenda-position
         (text-property-any (point-min) (point-max)
                            'org-agenda-type 'agenda)))
    (unless agenda-position
      (user-error "This agenda has no calendar component"))
    (goto-char agenda-position)
    (setq org-agenda-type 'agenda)
    (org-agenda-later arg)))

(defun jf/org-agenda-earlier (arg)
  "Move the calendar component backward by ARG spans."
  (interactive "p")
  (jf/org-agenda-later (- arg)))

(with-eval-after-load 'org-agenda
  (keymap-set org-agenda-mode-map "b" #'jf/org-agenda-earlier)
  (keymap-set org-agenda-mode-map "f" #'jf/org-agenda-later))

(defun jf/org-agenda-dashboard ()
  "Show today's schedule and non-empty deadline and undated task blocks."
  (interactive)
  (require 'org-agenda)
  (let* ((deadline-match "DEADLINE>=\"<+1d>\"+DEADLINE<=\"<+14d>\"")
         (blocks
          `((agenda ""
                    ((org-agenda-overriding-header "")
                     (org-agenda-span 1)))
            ,@(when (jf/org-agenda--has-entries-p deadline-match)
                `((tags-todo
                   ,deadline-match
                   ((org-agenda-overriding-header "Upcoming Deadlines")
                    (org-agenda-sorting-strategy '(deadline-up))))))
            ,@(when (jf/org-agenda--has-entries-p "/TODO" t)
                '((todo
                   "TODO"
                   ((org-agenda-overriding-header "Tasks Without a Date")
                    (org-agenda-skip-function
                     '(org-agenda-skip-entry-if 'scheduled 'deadline))
                    (org-agenda-cmp-user-defined
                     #'jf/org-agenda--compare-explicit-priority)
                    (org-agenda-sorting-strategy '(user-defined-up))))))))
         (settings
          '((org-agenda-finalize-hook
             '(jf/org-agenda--separate-dashboard-sections))))
         (org-agenda-custom-commands
          `(("d" "Dashboard" ,blocks ,settings))))
    (org-agenda nil "d")))

(setq initial-buffer-choice #'jf/initial-agenda-buffer)

;;; Extensions

(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode))

(provide 'jf-org)
;;; jf-org.el ends here
