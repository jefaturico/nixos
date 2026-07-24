;;; jf-tools.el --- Interactive tools and utility commands -*- lexical-binding: t; -*-

(require 'seq)
(require 'subr-x)
(require 'url-util)
(require 'use-package)

;;; Documents

(use-package pdf-tools
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :magic ("%PDF" . pdf-view-mode)
  :config
  (setq pdf-view-use-scaling t
        pdf-view-continuous t
        pdf-view-display-size 'fit-width
        pdf-view-resize-factor 1.1
        pdf-cache-image-limit 64
        pdf-cache-prefetch-delay 0.15
        pdf-view-max-image-width 2048)
  (setq-default pdf-view-use-unicode-lighter nil)
  (add-hook 'pdf-view-mode-hook
            (lambda ()
              (pdf-cache-prefetch-minor-mode 1)
              (display-line-numbers-mode -1)
              (auto-revert-mode -1)
              (cursor-sensor-mode -1))))

;;; Feeds

(use-package elfeed
  :commands elfeed
  :bind ("C-c f" . elfeed)
  :custom
  (elfeed-feeds
   '("https://www.europapress.es/rss/rss.aspx?ch=66"
     "https://feeds.bbci.co.uk/news/world/rss.xml"))
  :hook (elfeed-show-mode . jf/reading-layout)
  :config
  (keymap-set elfeed-show-mode-map "o" #'elfeed-show-visit))

;;; Web reading

(use-package eww
  :ensure nil
  :commands eww
  :hook (eww-mode . jf/reading-layout)
  :custom
  (eww-readable-adds-to-history nil))

;;; Terminal

(use-package vterm
  :commands (vterm vterm-other-window vterm-send-return vterm-send-string)
  :config
  (setq vterm-shell "/run/current-system/sw/bin/bash"))

(defun jf/vterm-new ()
  "Create a new vterm in another window.

Unlike `vterm-other-window', always use a fresh buffer instead of returning to
an existing *vterm* buffer."
  (interactive)
  (vterm-other-window (generate-new-buffer-name "*vterm*")))

(defun jf/codex (&optional directory)
  "Start a new Codex session in a fresh vterm.

Prompt for DIRECTORY, defaulting to ~/nixos.  Every invocation creates an
independent Codex process."
  (interactive
   (let ((default (expand-file-name "~/nixos/")))
     (list (read-directory-name "Codex directory: " default default t))))
  (unless (executable-find "codex")
    (user-error "codex executable not found"))
  (let* ((default-directory
          (file-name-as-directory (expand-file-name (or directory
                                                        default-directory))))
         (project-name (file-name-nondirectory
                        (directory-file-name default-directory)))
         (buffer-name
          (generate-new-buffer-name (format "*codex:%s*" project-name))))
    (vterm buffer-name)
    (vterm-send-string "exec codex")
    (vterm-send-return)))

;;; Finance

(defun jf/hledger-balance ()
  "Show the hledger balance report."
  (interactive)
  (hledger-run-command "balance"))

(defun jf/hledger-register ()
  "Show the hledger register report."
  (interactive)
  (hledger-run-command "register"))

(use-package hledger-mode
  :mode ("\\.journal\\'" . hledger-mode)
  :bind (:map hledger-mode-map
              ("C-c h b" . jf/hledger-balance)
              ("C-c h r" . jf/hledger-register)
              ("C-c h h" . hledger-run-command))
  :init
  (setq hledger-jfile (expand-file-name
                       "~/documents/personal/finance/main.journal")))

;;; Document picker

(defvar jf/pdf-document-roots
  '("~/documents" "~/downloads" "~/projects")
  "Directories searched by `jf/pick-pdf'.")

(defun jf/pdf-document--mtime (file)
  "Return FILE modification time as a float."
  (float-time (file-attribute-modification-time (file-attributes file))))

(defun jf/pdf-document--display-name (file)
  "Return display name for PDF FILE."
  (abbreviate-file-name file))

(defun jf/pdf-documents ()
  "Return current PDF files below `jf/pdf-document-roots', newest first."
  (unless (executable-find "fd")
    (user-error "fd executable not found"))
  (let ((roots (seq-filter #'file-directory-p
                           (mapcar #'expand-file-name jf/pdf-document-roots))))
    (when roots
      (with-temp-buffer
        (let ((status (apply #'process-file
                             "fd" nil t nil
                             "--type" "f" "--extension" "pdf" "--print0"
                             "." roots)))
          (unless (zerop status)
            (user-error "fd failed with status %s" status))
          (sort (split-string (buffer-string) "\0" t)
                (lambda (a b)
                  (> (jf/pdf-document--mtime a)
                     (jf/pdf-document--mtime b)))))))))

(defun jf/pick-pdf (&optional _prefix)
  "Select a current PDF below the configured roots and open it in Zathura."
  (interactive "P")
  (let* ((candidates
          (mapcar (lambda (file)
                    (cons (jf/pdf-document--display-name file) file))
                  (jf/pdf-documents)))
         (choice (when candidates
                   (completing-read "Select PDF: " candidates nil t))))
    (if-let ((path (cdr (assoc choice candidates))))
        (set-process-query-on-exit-flag
         (start-process "jf-pick-pdf-zathura" nil "zathura" path)
         nil)
      (user-error "No PDFs found"))))

;;; Bookmarks and browser commands

(defvar jf/bookmarks-file
  (expand-file-name "nixos/common/bookmarks.txt" (getenv "HOME"))
  "Plain text bookmark file.  Each line is NAME URL.")

(defun jf/bookmark--canonical-url (url)
  "Return a stable comparison key for URL."
  (let ((url (string-trim url)))
    (if (and (> (length url) 1) (string-suffix-p "/" url))
        (substring url 0 -1)
      url)))

(defun jf/bookmark--read-bookmarks ()
  "Return bookmarks from `jf/bookmarks-file' as plists."
  (unless (file-readable-p jf/bookmarks-file)
    (user-error "Bookmark file is not readable: %s" jf/bookmarks-file))
  (with-temp-buffer
    (insert-file-contents jf/bookmarks-file)
    (let (bookmarks)
      (dolist (line (split-string (buffer-string) "\n" t))
        (unless (string-match-p "\\`[ \t]*\\(?:#.*\\)?\\'" line)
          (if (string-match "\\`[ \t]*\\(.+?\\)[ \t]+\\(https?://.+\\)[ \t]*\\'" line)
              (push (list :name (string-trim (match-string 1 line))
                          :url (string-trim (match-string 2 line)))
                    bookmarks)
            (message "Skipping malformed bookmark line: %s" line))))
      (nreverse bookmarks))))

(defun jf/bookmark--eureka-browser-buffer (url)
  "Return a Eureka browser buffer already showing URL, if one is visible to Emacs."
  (let ((url (jf/bookmark--canonical-url url)))
    (seq-find
     (lambda (buffer)
       (with-current-buffer buffer
         (when (eq major-mode 'eureka-mode)
           (let ((app-id (and (boundp 'eureka-app-id)
                              (buffer-local-value 'eureka-app-id buffer)))
                 (title (if (and (boundp 'eureka-title)
                                 (buffer-local-value 'eureka-title buffer))
                            (buffer-local-value 'eureka-title buffer)
                          (buffer-name buffer))))
             (and (member app-id '("brave"
                                    "brave-browser"
                                    "Brave-browser"
                                    "com.brave.Browser"
                                    "librewolf"
                                    "LibreWolf"))
                  (or (string-match-p (regexp-quote (concat "[" url "]")) title)
                      (string-match-p (regexp-quote url) title)))))))
     (buffer-list))))

(defun jf/bookmark--open-url (url)
  "Open URL in the default browser."
  (browse-url url))

(defun jf/browser--url-or-search (text)
  "Return TEXT as a URL or a search URL."
  (if (string-match-p "\\`\\(?:[[:alpha:]][[:alnum:]+.-]*://\\|about:\\)" text)
      text
    (format "https://html.duckduckgo.com/html/?q=%s"
            (url-hexify-string text))))

(defun jf/browser-open-or-search ()
  "Open a URL or search arbitrary text in the default browser."
  (interactive)
  (let ((text (string-trim (read-string "Open/search: "))))
    (when (string-empty-p text)
      (user-error "Empty browser input"))
    (jf/bookmark--open-url (jf/browser--url-or-search text))))

(defun jf/bookmark-open ()
  "Pick a bookmark from `jf/bookmarks-file' and open it in the browser."
  (interactive)
  (let* ((bookmarks (jf/bookmark--read-bookmarks))
         (candidates
          (mapcar
           (lambda (bookmark)
             (let* ((url (plist-get bookmark :url))
                    (buffer (jf/bookmark--eureka-browser-buffer url))
                    (label (format "%-10s %s  %s"
                                   (if buffer "[open]" "")
                                   (plist-get bookmark :name)
                                   url)))
               (cons label bookmark)))
           bookmarks))
         (label (completing-read "Bookmark: " candidates nil t))
         (choice (cdr (assoc label candidates)))
         (url (plist-get choice :url))
         (buffer (jf/bookmark--eureka-browser-buffer url)))
    (cond
     ((not buffer)
      (jf/bookmark--open-url url))
     ((eq (car (read-multiple-choice
                "Bookmark is already open"
                '((?s "switch" "switch to bookmark buffer")
                  (?n "new tab" "open another tab"))))
          ?s)
      (switch-to-buffer buffer))
     (t
      (jf/bookmark--open-url url)))))

(provide 'jf-tools)
;;; jf-tools.el ends here
