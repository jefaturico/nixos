;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(initial-buffer-choice t)
 '(menu-bar-mode nil)
 '(scroll-bar-mode nil)
 '(tool-bar-mode nil))

;; Every package comes from nix (home/editors.nix); MELPA is there for
;; trying one out by hand.
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

;; The colours and the font are not set here. They come from stylix, see
;; ~/nixos/home/editors.nix and ~/nixos/home/theme-switch.nix.

;; ---- Windows ---------------------------------------------------------------
;; Emacs does not split its frame. A buffer that would pop up in a split
;; (help, compile output, a list of errors, a mail) opens in a frame of its
;; own, which Hyprland tiles like any other window: Super+O reaches it,
;; and q or Super+K closes it. A buffer already shown in some frame is
;; reused there.
;; Left alone, inside the current frame: anything that asks for the current
;; window or the whole frame (mu4e's main view does, when mu4e starts), and
;; the short-lived helpers named here.
(defvar my-in-frame-buffers
  (rx bos (or " "                       ; internal buffers
              "*Completions*"
              "*Calendar*"              ; the calendar of a date prompt
              "CAPTURE-"                ; the capture buffer
              "*Capture*"               ; shown while a template asks its prompts
              ;; org's own menus and note buffers, gone after one key
              (seq "*Org " (or "Select" "todo" "Note" "Links" "Attach"
                               "Export Dispatcher")
                   "*"))))

(defun my-popup-frame-p (buffer action)
  "Non-nil if BUFFER, displayed with ACTION, should get a frame of its own."
  (not (or (string-match-p my-in-frame-buffers
                           (if (stringp buffer) buffer (buffer-name buffer)))
           ;; It asks for the window or the frame it is called from.
           (seq-intersection '(display-buffer-same-window display-buffer-full-frame)
                             (ensure-list (car-safe action))))))

(setq display-buffer-alist
      '((my-popup-frame-p
         (display-buffer-reuse-window display-buffer-pop-up-frame)
         (reusable-frames . t))))

;; q closes a frame that was opened for the buffer instead of minimising it,
;; and so does killing the buffer.
(setq frame-auto-hide-function #'delete-frame)
(setq kill-buffer-quit-windows t)

;; Emacs runs as a daemon, so C-x C-c would take every frame down with it.
;; Super+K closes a frame.
(keymap-unset global-map "C-x C-c")

;; Super+K is how frames get closed, so closing one must leave nothing
;; behind, whatever the frame was in the middle of:
;;   a question in the minibuffer   cancelled, as by C-g
;;   one of org's key menus         left, as by C-g
;;   a capture being written        abandoned, as by C-c C-k
;;   a flashcard review             ended and saved, as by q
;; A buffer still shown in another frame is left alone.
;; The first two are done once the frame is gone: interrupting a question
;; while the frame is being deleted leaves the frame behind.
(defvar my-frame-orphan nil
  "What the frame just closed left waiting: `prompt', `menu' or nil.")

(defvar my-menu-frame nil
  "The frame showing one of org's key menus while it waits for the key.")

(define-advice org-mks (:around (menu &rest args) my-menu-frame)
  (let ((my-menu-frame (selected-frame)))
    (apply menu args)))

(defun my-buffer-shown-elsewhere-p (buffer frame)
  (seq-some (lambda (window) (not (eq (window-frame window) frame)))
            (get-buffer-window-list buffer nil t)))

(defun my-frame-closed (frame)
  "Wind up what FRAME was doing, before it is deleted."
  ;; A frame that would delete itself when its capture ends: not any more.
  (set-frame-parameter frame 'my-capture nil)
  (setq my-frame-orphan
        (cond ((and (active-minibuffer-window)
                    (eq (window-frame (active-minibuffer-window)) frame))
               'prompt)
              ((eq my-menu-frame frame) 'menu)))
  (dolist (window (window-list frame))
    (let ((buffer (window-buffer window)))
      (unless (my-buffer-shown-elsewhere-p buffer frame)
        (with-current-buffer buffer
          (cond ((bound-and-true-p org-capture-mode)
                 ;; Done while the frame still exists: afterwards org would
                 ;; put back the windows of a frame that is gone, which
                 ;; crashes Emacs.
                 (with-selected-window window (org-capture-kill)))
                ((and (derived-mode-p 'org-mode)
                      (fboundp 'org-srs-reviewing-p)
                      (org-srs-reviewing-p))
                 (my-srs-quit))))))))

(defun my-frame-gone (_frame)
  "Cancel the question the frame just closed left waiting."
  (pcase (prog1 my-frame-orphan (setq my-frame-orphan nil))
    ('prompt (run-at-time 0 nil (lambda ()
                                  (when (> (minibuffer-depth) 0)
                                    (abort-recursive-edit)))))
    ;; The menu reads single keys; C-g is its way out.
    ('menu (push ?\C-g unread-command-events))))

(add-hook 'delete-frame-functions #'my-frame-closed)
(add-hook 'after-delete-frame-functions #'my-frame-gone)

;; ---- Completion ------------------------------------------------------------
;; Prompts (M-x, files, buffers, flashcard subjects) list their candidates
;; as you type, fuzzy matched. RET takes the highlighted one, C-n / C-p move,
;; M-j takes exactly what was typed.
(fido-vertical-mode 1)
;; By default a long list (M-x) is held back 0.15 s before it is shown.
(setq icomplete-compute-delay 0)

;; In a buffer, TAB indents first; if the line is already indented it
;; completes. Nothing pops up by itself.
(setq tab-always-indent 'complete)
;; File names complete too, in any buffer, after what the language offers.
(autoload 'comint-filename-completion "comint")
(add-hook 'completion-at-point-functions #'comint-filename-completion t)

;; ---- Mail ------------------------------------------------------------------
(use-package mu4e
  :ensure nil
  :bind ("C-c e" . mu4e)

  :custom
  ;; mbsync -a, plus a sign-in window when the university login has expired.
  ;; Defined in home/mail.nix.
  (mu4e-get-mail-command "mail-sync")
  (mu4e-update-interval 300)

  (message-send-mail-function #'message-send-mail-with-sendmail)
  (sendmail-program "msmtp")
  (message-sendmail-extra-arguments '("--read-envelope-from"))
  (message-sendmail-f-is-evil t)
  (user-full-name "Emilio Hurtado")
  (mu4e-context-policy 'pick-first)
  (mu4e-compose-context-policy 'ask-if-none)
  ;; mbsync keeps UIDs in filenames; moved files must be renamed or sync breaks.
  (mu4e-change-filenames-when-moving t)

  :config
  ;; Trashing is a plain move to Trash; otherwise mbsync expunges it for good.
  ;; (A defvar, not a defcustom, so :custom would silently ignore it.)
  (setq mu4e-trash-without-flag t)

  (defun my-mu4e-context (name address sent-behavior)
    (let ((dir (concat "/" name)))
      (make-mu4e-context
       :name name
       :match-func (lambda (msg)
                     (when msg
                       (string-prefix-p (concat dir "/") (mu4e-message-field msg :maildir))))
       :vars `((user-mail-address . ,address)
               (mu4e-sent-folder . ,(concat dir "/Sent"))
               (mu4e-drafts-folder . ,(concat dir "/Drafts"))
               (mu4e-trash-folder . ,(concat dir "/Trash"))
               (mu4e-refile-folder . ,(concat dir "/Archive"))
               (mu4e-sent-messages-behavior . ,sent-behavior)))))

  ;; msmtp picks its account from the From: address (--read-envelope-from).
  ;; Microsoft and Gmail store sent mail themselves, so don't save a second copy.
  (setq mu4e-contexts
        (list (my-mu4e-context "personal" "emilio@hurtadosanchez.com" 'sent)
              (my-mu4e-context "university" "emiliohurtado@mail.ucv.es" 'delete)
              (my-mu4e-context "google" "emiliohurtadosr@gmail.com" 'delete))))

;; ---- Org: agenda and capture ----------------------------------------------
;; Tasks and events are two files in ~/documents/org, both in the agenda:
;;   tasks.org    TODO entries, with or without a scheduled date or deadline.
;;   events.org   plain dated entries. Never TODO, never archived.
;;   archive.org  where a task is moved the moment it is marked DONE.
;; C-c c captures: t task, e event, f flashcard (see Flashcards below).
;; C-c a opens the agenda: the week with everything, followed by the tasks
;; without a date. C-c t lists all tasks. M-x org-agenda is the full menu.
;; From Hyprland (home/hyprland.nix): Super+Shift+C capture, Super+C capture
;; another of the last kind, Super+A agenda, Super+E mail.
(defvar my-org-tasks-file "~/documents/org/tasks.org")
(defvar my-org-events-file "~/documents/org/events.org")

;; Declared, so that binding it below works before org is loaded.
(defvar org-agenda-window-setup)

(defun my-org-agenda (&optional here)
  "Open the agenda view straight away, without the menu.
It gets a frame of its own, which q closes. With HERE non-nil it takes the
current frame instead: that is how Hyprland opens it, in a frame made for it."
  (interactive)
  (let ((org-agenda-window-setup (if here 'current-window 'other-frame)))
    (org-agenda nil "a")))

(use-package org
  :ensure nil
  :bind (("C-c a" . my-org-agenda)
         ("C-c t" . org-todo-list)
         ("C-c c" . org-capture))

  :custom
  ;; The agenda is a frame of its own, like every other popup (see Windows).
  (org-agenda-window-setup 'other-frame)
  (org-directory "~/documents/org")
  (org-agenda-files (list my-org-tasks-file my-org-events-file))
  ;; DONE records when, so the archive says when each task was finished.
  (org-log-done 'time)
  ;; One archive next to the files, filed under the date of archiving, and
  ;; written to disk at once so an archived task is never only in memory.
  (org-archive-location "archive.org::datetree/")
  (org-archive-subtree-save-file-p t)

  ;; The event date is asked first. A date alone makes an all-day event,
  ;; "fri 14:00-15:30" a timed one.
  (org-capture-templates
   `(("t" "Task" entry (file ,my-org-tasks-file) "* TODO %?")
     ("e" "Event" entry (file ,my-org-events-file) "* %?\n%^t")
     ;; Asks for the subject first. Heading: the front. Body: the back.
     ("f" "Flashcard" entry (file my-srs-capture-file)
      (function my-srs-capture-template)
      :before-finalize my-srs-make-card)))

  (org-agenda-custom-commands
   '(("a" "Agenda"
      ((agenda "")
       (todo "TODO" ((org-agenda-overriding-header "Tasks without a date")
                     (org-agenda-todo-ignore-with-date t)))))))

  :config
  ;; A task is archived by the same command that marks it DONE, in the file
  ;; or from the agenda. Nothing else ever moves entries: no timer, no hook on
  ;; startup or save. A repeating task goes back to TODO and so stays.
  ;; A subtask stays under its task when it is marked DONE, and is archived
  ;; with it when the task itself is. A heading that is not a task (a plain
  ;; grouping heading) does not count as a parent.
  (defun my-org-subtask-p ()
    "Non-nil if a heading above the entry at point is itself a task."
    (save-excursion
      (let (found)
        (while (and (not found) (org-up-heading-safe))
          (setq found (org-get-todo-state)))
        found)))

  (defun my-org-task-done-p ()
    "Non-nil if the entry at point is a completed task in the tasks file."
    (and (derived-mode-p 'org-mode)
         buffer-file-name
         (file-equal-p buffer-file-name my-org-tasks-file)
         (not (org-before-first-heading-p))
         (org-entry-is-done-p)
         (not (my-org-subtask-p))))

  ;; From the agenda the archiving is done by the agenda's own command, so
  ;; the line is removed from the view as well.
  (defvar my-org-in-agenda-todo nil)

  (defun my-org-archive-after-todo (&rest _)
    (when (and (not my-org-in-agenda-todo) (my-org-task-done-p))
      (org-archive-subtree-default)))
  (advice-add 'org-todo :after #'my-org-archive-after-todo)

  (defun my-org-agenda-archive-after-todo (fn &rest args)
    (let ((my-org-in-agenda-todo t))
      (apply fn args))
    (when-let* ((marker (org-get-at-bol 'org-hd-marker))
                ((marker-buffer marker))
                ((org-with-point-at marker (my-org-task-done-p))))
      (org-agenda-archive-default)))
  (advice-add 'org-agenda-todo :around #'my-org-agenda-archive-after-todo))

;; Super+Shift+C: the same capture as C-c c, from anywhere, in a frame that
;; lasts as long as the capture does. Filing it, abandoning it and C-g end
;; it (closing the frame does too, see Windows).
;; Super+C: another of whatever was captured last (the same template, and
;; for a flashcard the same subject), with no question asked. The menu when
;; nothing has been captured yet.
(defun my-capture-frame (&optional keys repeat)
  "Start a capture in the selected frame, which is deleted when it ends.
KEYS picks the template without the menu; with REPEAT it is a repeat of the
last capture (see `my-capture-frame-again').
Called by emacsclient. The capture itself is started from a timer: while
emacsclient's request is still being served Emacs answers no other one, so
a question asked from inside it would lock every later Super+C out."
  (let ((frame (selected-frame)))
    (set-frame-parameter frame 'my-capture t)
    (run-at-time 0 nil #'my-capture-frame-run frame keys repeat)
    nil))

(defvar my-capture-last-key nil)
(defvar my-capture-repeating nil)

(defun my-capture-frame-again ()
  "Like `my-capture-frame', for the template used last."
  (my-capture-frame my-capture-last-key t))

(defun my-capture-remember-key ()
  (setq my-capture-last-key (org-capture-get :key)))

(defun my-capture-frame-run (frame keys repeat)
  (when (frame-live-p frame)
    (select-frame-set-input-focus frame)
    (condition-case err
        (let ((my-capture-repeating (and keys repeat)))
          (org-capture nil keys))
      (quit (my-capture-frame-close frame))
      (error (my-capture-frame-close frame)
             (message "Capture failed: %s" (error-message-string err))))))

(defun my-capture-frame-close (&optional frame)
  "Delete FRAME, or the selected one, if it was made for a capture."
  (let ((frame (or frame (selected-frame))))
    (when (and (frame-live-p frame) (frame-parameter frame 'my-capture))
      (set-frame-parameter frame 'my-capture nil)
      (delete-frame frame t))))

(defun my-capture-frame-fill ()
  "Give the capture buffer the whole frame."
  (when (frame-parameter nil 'my-capture)
    (delete-other-windows)))

(add-hook 'org-capture-mode-hook #'my-capture-frame-fill)
(add-hook 'org-capture-mode-hook #'my-capture-remember-key)
(add-hook 'org-capture-after-finalize-hook #'my-capture-frame-close)

;; ---- Flashcards -----------------------------------------------------------
;; One org file per subject, one entry per card: the heading is the front,
;; the body the back. org-srs schedules the reviews (FSRS, the algorithm Anki
;; uses now) and keeps its data in a drawer inside each entry.
;;   C-c c f   add a card: asks for the subject, then a buffer with the
;;             heading started. Heading: the front. Below it: the back.
;;   C-c f     review what is due in a subject. SPC shows the answer, then
;;             rate it: 1 again, 2 hard, 3 good, 4 easy. q stops.
;;             e edits the card shown, C-c C-c returns to the review.
;;             o plays the moment the card came from, O shows the video,
;;             [ and ] move that moment earlier or later.
;; The file is saved when a review ends or is stopped.

;; The subjects. Each is: name, file, what the front is called, what the back
;; is called, and the kind of card: `card-reversible' is asked in both
;; directions, `card' only front to back. A new subject is a new line here.
;; What depends on the deck beyond that (new cards per day, holding back the
;; other direction of a card, ...) goes at the top of its file, as
;; phrases.org does:
;;   #+PROPERTY: SRS_SCHEDULE_BURY_SIBLING_ITEMS_P t
(defvar my-srs-decks
  '(("German phrases" "~/documents/german/phrases.org"
     "German" "English" card-reversible)))

(defun my-srs-read-deck ()
  "Ask for a subject and return its line of `my-srs-decks'."
  (assoc (completing-read "Subject: " my-srs-decks nil t nil nil
                          (caar my-srs-decks))
         my-srs-decks))

;; Where a card came from: the video playing at the moment of the capture,
;; as a link that opens it a few seconds before that moment. Read over MPRIS
;; (playerctl), which gives the title, the channel and the position but not
;; the address; that is looked up by title in Brave's history. Kept in the
;; entry's SOURCE property, out of the way of the card. Nothing playing, or
;; anything failing, and the card simply has no source.
(defvar my-srs-source-lead 3
  "Seconds before the moment of capture at which o starts the video.
The link itself keeps the exact moment.")

(defun my-srs-playing ()
  "The player making sound, or any player, as (name . title), or nil."
  (let* ((players (ignore-errors (process-lines "playerctl" "-l")))
         (player (or (seq-find (lambda (p)
                                 (equal (ignore-errors (car (process-lines "playerctl" "-p" p "status")))
                                        "Playing"))
                               players)
                     (car players))))
    (when player
      (let ((title (ignore-errors (car (process-lines "playerctl" "-p" player "metadata" "xesam:title")))))
        (when (and title (not (string-empty-p title)))
          (cons player title))))))

(defun my-srs-brave-url (title)
  "The address last visited in Brave whose page title starts with TITLE."
  (let ((history (expand-file-name "~/.config/BraveSoftware/Brave-Origin/Default/History"))
        (copy (make-temp-file "brave-history")))
    ;; Brave keeps the file locked; a copy can be read.
    (unwind-protect
        (progn
          (copy-file history copy t)
          (let ((db (sqlite-open copy)))
            (unwind-protect
                (caar (sqlite-select
                       db "select url from urls where title like ? order by last_visit_time desc limit 1"
                       (list (concat (string-replace "%" "" title) "%"))))
              (sqlite-close db))))
      (delete-file copy))))

(defun my-srs-source ()
  "What is playing right now: (PLAYER TITLE ARTIST POSITION), or nil.
POSITION is the moment, in whole seconds."
  (ignore-errors
    (pcase-let ((`(,player . ,title) (my-srs-playing)))
      (when player
        (list player title
              (car (process-lines "playerctl" "-p" player "metadata" "xesam:artist"))
              (floor (string-to-number (car (process-lines "playerctl" "-p" player "position")))))))))

(defun my-srs-source-link (source)
  "An org link for SOURCE, from `my-srs-source', or nil.
The address is looked up now and not when SOURCE was read: Brave writes its
history with a delay of up to half a minute, so a video opened just before
the capture is often only there by the time the card is filed. When it is
still missing, the link is a YouTube search for the title."
  (ignore-errors
    (pcase-let* ((`(,player ,title ,artist ,position) source)
                 (url (if (string-prefix-p "brave" player)
                          (my-srs-brave-url title)
                        (car (process-lines "playerctl" "-p" player "metadata" "xesam:url")))))
      ;; org's own link builder, so brackets in a title cannot break the
      ;; link.
      (org-link-make-string
       (cond
        ((or (null url) (string-empty-p url))
         (concat "https://www.youtube.com/results?search_query="
                 (url-hexify-string (if (and artist (not (string-empty-p artist)))
                                        (concat artist " " title)
                                      title))))
        ((string-match-p "youtube\\.com/watch" url)
         ;; Any moment the address already carries is replaced.
         (format "%s&t=%ds" (replace-regexp-in-string "[&?]t=[0-9]+s?" "" url) position))
        (t url))
       (format "%s%s (%d:%02d)"
               (if (and artist (not (string-empty-p artist))) (concat artist ": ") "")
               title (/ position 60) (% position 60))))))

;; Capture. The subject of the card being captured: org-capture asks for the
;; template first, so that is where the question is put. Super+C repeats the
;; last subject without asking (`my-capture-repeating'). The source is read
;; at the same moment, which is the moment of the key press.
(defvar my-srs-capture-deck nil)
(defvar my-srs-capture-source nil)

(defun my-srs-capture-template ()
  (unless (and my-capture-repeating my-srs-capture-deck)
    (setq my-srs-capture-deck (my-srs-read-deck)))
  (setq my-srs-capture-source (my-srs-source))
  "* %?\n")

(defun my-srs-capture-file ()
  (nth 1 my-srs-capture-deck))

(defun my-srs-make-card ()
  "Turn the entry being captured into a card of the kind its subject uses."
  (require 'org-srs)
  ;; The capture buffer shows the whole file at this point, so go to the new
  ;; entry explicitly.
  (goto-char (org-capture-get :begin-marker 'local))
  (org-id-get-create)
  (org-entry-put nil "CREATED" (format-time-string "[%Y-%m-%d %a %H:%M]"))
  (when-let* ((link (and my-srs-capture-source
                         (my-srs-source-link my-srs-capture-source))))
    (org-entry-put nil "SOURCE" link))
  (org-srs-item-new (nth 4 my-srs-capture-deck)))

;; Review. e turns the review keys back into ordinary keys so the card can
;; be edited, C-c C-c returns to the review.
(defvar-local my-srs-editing nil)

(defun my-srs-review ()
  "Ask for a subject and review its cards that are due."
  (interactive)
  (require 'org-srs)
  (find-file (nth 1 (my-srs-read-deck)))
  (setq my-srs-editing nil)
  ;; A review left behind (its frame closed with Super+K) would stop a new
  ;; one from starting.
  (when (org-srs-reviewing-p)
    (org-srs-review-quit))
  (org-srs-review-start))

(defun my-srs-quit ()
  "Stop the review and save the file."
  (interactive)
  (org-srs-review-quit)
  (save-buffer))

(defun my-srs-set-source-time (time)
  "Set the moment of the card at point in its source link, as TIME (m:ss).
For cards whose link was added by hand, without a moment."
  (interactive "sMoment in the video (m:ss): ")
  (pcase-let ((`(,minutes ,seconds) (mapcar #'string-to-number (split-string time ":"))))
    (my-srs-set-source-moment (+ (* 60 minutes) (or seconds 0)))))

(defun my-srs-set-source-moment (position)
  "Set the moment of the card at point in its source link to POSITION seconds."
  (let ((source (or (org-entry-get nil "SOURCE")
                    (user-error "This card has no source"))))
    (string-match org-link-bracket-re source)
    (let ((url (replace-regexp-in-string "[&?]t=[0-9]+s?" "" (match-string 1 source)))
          (description (replace-regexp-in-string " ([0-9]+:[0-9][0-9])\\'" ""
                                                 (or (match-string 2 source) ""))))
      (org-entry-put nil "SOURCE"
                     (org-link-make-string
                      (if (string-match-p "youtube\\.com/watch" url)
                          (format "%s&t=%ds" url position)
                        url)
                      (format "%s (%d:%02d)" description (/ position 60) (% position 60)))))))

;; Going back to the source during a review.
;;   o   hear it: the sound only, from `my-srs-source-lead' seconds before
;;       the moment, for `my-srs-clip-length' seconds. o again starts it
;;       over at once, as often as needed. It stops by itself and goes away
;;       with the card.
;;   O   watch it: the video in a browser window of its own, next to the
;;       review. Does nothing while that window is still open. The video
;;       has priority: O stops the sound clip, and o does nothing while
;;       the window is open.
;;   [ ] the clip cuts into the sentence: move the card's moment
;;       `my-srs-shift-step' seconds earlier or later and play it again.
;;       The card keeps the new moment.
(defvar my-srs-clip-length 10
  "Seconds of the source that o plays.")

(defvar my-srs-shift-step 1
  "Seconds by which [ and ] move a card's moment.")

(defun my-srs-source-parts ()
  "The source of the card at point as (URL . MOMENT), MOMENT in seconds or nil.
Nil when the card has no source."
  (when-let* ((source (org-entry-get nil "SOURCE"))
              ((string-match org-link-bracket-re source))
              (url (org-link-unescape (match-string 1 source))))
    (cons url (and (string-match "[&?]t=\\([0-9]+\\)s?" url)
                   (string-to-number (match-string 1 url))))))

(defun my-srs-source-start (moment)
  (max 0 (- (or moment 0) my-srs-source-lead)))

;; The mpv playing a card's source, as (PROCESS URL START), and the socket
;; it takes commands on.
(defvar my-srs-audio nil)
(defvar my-srs-audio-socket
  (expand-file-name "emacs-flashcard-mpv"
                    (or (getenv "XDG_RUNTIME_DIR") temporary-file-directory)))

(defun my-srs-audio-send (&rest commands)
  "Send COMMANDS to the mpv that is playing. Nothing if it is not up yet."
  (ignore-errors
    (let ((connection (make-network-process :name "flashcard-mpv-command"
                                            :family 'local
                                            :service my-srs-audio-socket
                                            :noquery t)))
      (process-send-string
       connection
       (mapconcat (lambda (command)
                    (concat (json-encode `((command . ,(vconcat command)))) "\n"))
                  commands))
      ;; Not closed at once: mpv drops what it has not read by then.
      (run-at-time 0.5 nil #'delete-process connection))))

(defun my-srs-audio-position ()
  "Where the mpv that is playing is, in seconds. Nil while it is loading."
  (ignore-errors
    (let* ((answer "")
           (connection (make-network-process
                        :name "flashcard-mpv-question"
                        :family 'local
                        :service my-srs-audio-socket
                        :noquery t
                        :filter (lambda (_ text) (setq answer (concat answer text)))))
           (asked (float-time)))
      (process-send-string connection "{\"command\":[\"get_property\",\"time-pos\"]}\n")
      ;; mpv answers within a few milliseconds.
      (while (and (not (string-match-p "\"error\"" answer))
                  (< (- (float-time) asked) 0.3))
        (accept-process-output connection 0.02))
      (delete-process connection)
      (when (string-match "\"data\":\\([0-9.]+\\)" answer)
        (string-to-number (match-string 1 answer))))))

(defun my-srs-audio-stop (&rest _)
  "Stop the sound of the card that was shown."
  (when (process-live-p (car my-srs-audio))
    (delete-process (car my-srs-audio)))
  (setq my-srs-audio nil))

(defun my-srs-play-source ()
  "Play the sound of the moment the card being shown came from."
  (interactive)
  (pcase-let ((`(,url . ,moment) (my-srs-source-parts)))
    (cond
     ((null url) (message "This card has no source."))
     ;; The video has the floor while its window is open.
     ((my-srs-video-window-p) nil)
     ;; Nothing to cut a clip from: watch it instead.
     ((not (and moment
                (string-match-p "youtube\\.com/watch" url)
                (executable-find "mpv")))
      (my-srs-watch-source))
     (t
      (let ((start (my-srs-source-start moment)))
        (if (and (process-live-p (car my-srs-audio))
                 (equal (cdr my-srs-audio) (list url start)))
            ;; This card's sound is already there. Playing or finished:
            ;; from the top again. Still loading: left alone, it starts
            ;; from the top anyway, and a seek now would only delay it.
            (when (my-srs-audio-position)
              (my-srs-audio-send
               (list "seek" start "absolute")
               ;; The end follows the start, which [ and ] may have moved.
               (list "set_property" "end"
                     (number-to-string (+ start my-srs-clip-length))))
              ;; mpv pauses itself at the end of the clip. Unpaused a
              ;; moment after the seek: at once, it would still be at the
              ;; end and pause again.
              (run-at-time 0.1 nil #'my-srs-audio-send
                           (list "set_property" "pause" :json-false)))
          (my-srs-audio-stop)
          (let ((mpv (start-process
                      "flashcard-mpv" nil "mpv"
                      "--no-video" "--no-terminal" "--ytdl-format=ba"
                      ;; At the end of the clip it pauses and stays, so
                      ;; that o only has to seek back and is instant.
                      "--keep-open=yes"
                      (format "--start=%d" start)
                      (format "--end=%d" (+ start my-srs-clip-length))
                      (concat "--input-ipc-server=" my-srs-audio-socket)
                      (replace-regexp-in-string "[&?]t=[0-9]+s?" "" url))))
            (set-process-query-on-exit-flag mpv nil)
            (setq my-srs-audio (list mpv url start)))))))))

(defun my-srs-shift-source (seconds)
  "Move the moment of the card being shown by SECONDS and play it again."
  (pcase-let ((`(,url . ,moment) (my-srs-source-parts)))
    (unless moment
      (user-error "This card's source has no moment"))
    (let ((new (max 0 (+ moment seconds))))
      (my-srs-set-source-moment new)
      ;; A player that has this card goes on with it under its new moment.
      (when (equal (nth 1 my-srs-audio) url)
        (setcdr my-srs-audio (list (car (my-srs-source-parts))
                                   (my-srs-source-start new))))
      (my-srs-play-source)
      (message "The card's moment is now %d:%02d." (/ new 60) (% new 60)))))

(defun my-srs-source-earlier ()
  "Move the card's moment earlier and play it again."
  (interactive)
  (my-srs-shift-source (- my-srs-shift-step)))

(defun my-srs-source-later ()
  "Move the card's moment later and play it again."
  (interactive)
  (my-srs-shift-source my-srs-shift-step))

;; When O last opened its window. The window takes a moment to appear, and
;; O pressed again in that moment must not open a second one.
(defvar my-srs-video-opened 0)

(defun my-srs-video-window-p ()
  "Non-nil if the window O opens is on screen."
  (ignore-errors
    (seq-some (lambda (window)
                (string-match-p "\\`brave-.*youtube" (gethash "class" window)))
              (json-parse-string
               (with-output-to-string
                 (call-process "hyprctl" nil standard-output nil "clients" "-j"))))))

(defun my-srs-watch-source ()
  "Open the video the card being shown came from, just before that moment."
  (interactive)
  (pcase-let ((`(,url . ,moment) (my-srs-source-parts)))
    (cond
     ((null url) (message "This card has no source."))
     ((or (< (- (float-time) my-srs-video-opened) 3)
          (my-srs-video-window-p))
      nil)
     (t
      ;; The video takes over from the sound clip.
      (my-srs-audio-stop)
      (setq my-srs-video-opened (float-time))
      ;; --app: a window with the page only, of a class of its own, which
      ;; is how `my-srs-video-window-p' tells it from the browser.
      (start-process
       "flashcard-video" nil "brave-origin"
       (concat "--app="
               (if moment
                   (replace-regexp-in-string
                    "\\([&?]t=\\)[0-9]+s?"
                    (format "\\1%ds" (my-srs-source-start moment))
                    url)
                 url)))))))

(defun my-srs-edit ()
  "Pause the review keys to edit the card being shown."
  (interactive)
  (setq my-srs-editing t)
  (message "Editing the card. C-c C-c goes back to the review."))

(defun my-srs-resume ()
  "Go back to the review after editing a card."
  (interactive)
  (setq my-srs-editing nil)
  (message "Back to the review."))

(use-package org-srs
  :ensure nil
  :bind ("C-c f" . my-srs-review)
  :custom
  ;; The answer is shown by a key (SPC below) and not by a prompt that blocks
  ;; Emacs until it is answered.
  (org-srs-item-confirm #'org-srs-item-confirm-command)
  :config
  (add-hook 'org-srs-review-finish-hook #'save-buffer)
  ;; The sound of a card ends with the card: on a rating, and on q.
  (add-hook 'org-srs-review-continue-hook #'my-srs-audio-stop)
  ;; A card shows the phrase only, not the drawers with the review data.
  (add-hook 'org-srs-item-before-confirm-hook
            (lambda (&rest _) (org-fold-hide-drawer-all)))
  ;; org-srs makes a hidden frame for its mouse buttons on every card even
  ;; with the buttons off. They are not used here, so it is never made.
  (remove-hook 'org-srs-item-before-confirm-hook #'org-srs-ui-mouse-mode-update-panels)
  (remove-hook 'org-srs-item-after-confirm-hook #'org-srs-ui-mouse-mode-update-panels))

;; The review keys only exist while a review is running. Otherwise they
;; are ordinary keys. A capture buffer is a clone of its file's buffer,
;; state included, so it would look like a review too; it never is one.
(defun my-srs-key (command)
  `(menu-item "" ,command
              :filter ,(lambda (cmd)
                         (and (fboundp 'org-srs-reviewing-p)
                              (org-srs-reviewing-p)
                              (not my-srs-editing)
                              (not (bound-and-true-p org-capture-mode))
                              cmd))))

(with-eval-after-load 'org
  (keymap-set org-mode-map "SPC" (my-srs-key #'org-srs-item-confirm-command))
  (keymap-set org-mode-map "1" (my-srs-key #'org-srs-review-rate-again))
  (keymap-set org-mode-map "2" (my-srs-key #'org-srs-review-rate-hard))
  (keymap-set org-mode-map "3" (my-srs-key #'org-srs-review-rate-good))
  (keymap-set org-mode-map "4" (my-srs-key #'org-srs-review-rate-easy))
  (keymap-set org-mode-map "q" (my-srs-key #'my-srs-quit))
  (keymap-set org-mode-map "e" (my-srs-key #'my-srs-edit))
  (keymap-set org-mode-map "o" (my-srs-key #'my-srs-play-source))
  (keymap-set org-mode-map "O" (my-srs-key #'my-srs-watch-source))
  (keymap-set org-mode-map "[" (my-srs-key #'my-srs-source-earlier))
  (keymap-set org-mode-map "]" (my-srs-key #'my-srs-source-later))
  (keymap-set org-mode-map "C-c C-c"
              `(menu-item "" org-ctrl-c-ctrl-c
                          :filter ,(lambda (cmd)
                                     (if my-srs-editing #'my-srs-resume cmd)))))

;; ---- Programming: Typst and Python ----------------------------------------
;; A language server per file type (tinymist, pylsp), both installed by
;; home/editors.nix and home/packages.nix. It gives:
;;   errors      underlined as you type. M-n / M-p jump between them,
;;               C-h . shows the full message, M-x flymake-show-buffer-diagnostics lists them.
;;   lookup      M-. go to definition, M-, back, M-? find uses.
;;               Documentation for the thing at point shows in the echo area.
;;   completion  TAB, only when you press it (see Completion).
;; Emacs 31 only shows a language server's errors for files it trusts,
;; because checking a file can mean running code from it. These are the
;; folders with your own work. Add a line for any other place you write
;; code; files elsewhere still get lookup and completion, just no errors.
(setq trusted-content '("~/projects/"
                        "~/documents/"
                        "~/nixos/"))

(use-package typst-ts-mode
  :ensure nil
  :mode "\\.typ\\'")

(use-package eglot
  :ensure nil
  :hook ((python-mode python-ts-mode typst-ts-mode) . eglot-ensure)
  :custom
  ;; Stop the server when its last file is closed.
  (eglot-autoshutdown t)
  ;; No type hints drawn into the code, no reformatting while typing.
  (eglot-ignored-server-capabilities
   '(:inlayHintProvider :documentOnTypeFormattingProvider))
  :config
  (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist"))))

(use-package flymake
  :ensure nil
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
