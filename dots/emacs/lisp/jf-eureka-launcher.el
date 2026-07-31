;;; jf-eureka-launcher.el --- Eureka application launcher -*- lexical-binding: t; -*-

(require 'seq)
(require 'subr-x)
(require 'xdg)

(defvar jf-eureka--application-cache nil
  "Cached application launcher candidates.")

(defvar jf-eureka--desktop-ids (make-hash-table :test #'equal)
  "Desktop-file IDs keyed by their absolute file names.")

(defun jf-eureka--application-dirs ()
  "Return existing XDG application directories in precedence order."
  (delete-dups
   (seq-filter
    #'file-directory-p
    (mapcar (lambda (dir) (expand-file-name "applications" dir))
            (cons (xdg-data-home) (xdg-data-dirs))))))

(defun jf-eureka--desktop-true-p (value)
  "Return non-nil when desktop entry VALUE represents true."
  (and value (member (downcase value) '("true" "1"))))

(defun jf-eureka--desktop-entry (file)
  "Return a launcher candidate for desktop FILE."
  (condition-case nil
      (let* ((entry (xdg-desktop-read-file file))
             (type (gethash "Type" entry))
             (name (gethash "Name" entry)))
        (when (and (equal type "Application")
                   (not (string-empty-p (or name "")))
                   (gethash "Exec" entry)
                   (not (jf-eureka--desktop-true-p (gethash "Hidden" entry)))
                   (not (jf-eureka--desktop-true-p (gethash "NoDisplay" entry)))
                   ;; Preserve the launcher's existing graphical-app scope.
                   (not (jf-eureka--desktop-true-p (gethash "Terminal" entry))))
          (cons name file)))
    (error nil)))

(defun jf-eureka--desktop-id (file directory)
  "Return the desktop-file ID for FILE relative to DIRECTORY."
  (replace-regexp-in-string
   "/" "-" (file-relative-name file directory) t t))

(defun jf-eureka--applications (&optional refresh)
  "Return application launcher candidates respecting XDG precedence.

Cache the result for subsequent launches.  With REFRESH non-nil, rescan the
XDG application directories."
  (when (or refresh (null jf-eureka--application-cache))
    (let ((seen (make-hash-table :test #'equal))
          (ids (make-hash-table :test #'equal))
          applications)
      (clrhash jf-eureka--desktop-ids)
      (dolist (directory (jf-eureka--application-dirs))
        (dolist (file (directory-files-recursively directory "\\.desktop\\'"))
          (let ((id (jf-eureka--desktop-id file directory)))
            (unless (gethash id seen)
              ;; Hidden entries still mask lower-priority copies.
              (puthash id t seen)
              (when-let ((application (jf-eureka--desktop-entry file)))
                (puthash file id ids)
                (puthash file id jf-eureka--desktop-ids)
                (push application applications))))))
      (let ((name-counts (make-hash-table :test #'equal)))
        (dolist (application applications)
          (let ((name (car application)))
            (puthash name (1+ (gethash name name-counts 0)) name-counts)))
        (setq jf-eureka--application-cache
              (sort
               (mapcar
                (lambda (application)
                  (let ((name (car application))
                        (file (cdr application)))
                    (if (> (gethash name name-counts) 1)
                        (cons (format "%s — %s" name (gethash file ids)) file)
                      application)))
                applications)
               (lambda (a b) (string-lessp (car a) (car b))))))))
  jf-eureka--application-cache)

(defun jf-eureka--desktop-app-id (desktop-file)
  "Return the standard Wayland app ID for DESKTOP-FILE."
  (string-remove-suffix
   ".desktop"
   (or (gethash desktop-file jf-eureka--desktop-ids)
       (file-name-nondirectory desktop-file))))

(defun jf-eureka--buffer-for-app-ids (app-ids)
  "Return the most recently used Eureka buffer matching APP-IDS."
  (seq-find
   (lambda (buffer)
     (and (buffer-live-p buffer)
          (with-current-buffer buffer
            (and (eq major-mode 'eureka-mode)
                 (boundp 'eureka-app-id)
                 (member eureka-app-id app-ids)))))
   (buffer-list)))

(defun jf-eureka-launch-or-focus (name app-ids launch-function)
  "Focus NAME when its Eureka buffer matches APP-IDS, otherwise launch it.

When a matching buffer already exists, display it and ask whether to invoke
LAUNCH-FUNCTION for another instance."
  (if-let ((buffer (jf-eureka--buffer-for-app-ids app-ids)))
      (progn
        (switch-to-buffer buffer)
        (when (y-or-n-p
               (format "%s is already running. Run another instance? " name))
          (funcall launch-function)))
    (funcall launch-function)))

(defun jf-eureka-launch-program (&optional refresh)
  "Launch an XDG desktop application using Emacs completion.

With a prefix argument, REFRESH the cached application list first."
  (interactive "P")
  (unless (executable-find "gio")
    (user-error "gio executable not found"))
  (let* ((applications (jf-eureka--applications refresh))
         (choice (completing-read "Launch: " applications nil t))
         (desktop-file (cdr (assoc choice applications))))
    (unless desktop-file
      (user-error "No desktop file for %s" choice))
    (jf-eureka-launch-or-focus
     choice
     (list (jf-eureka--desktop-app-id desktop-file))
     (lambda ()
       (make-process :name (concat "launch-program-" choice)
                     :command (list "gio" "launch" desktop-file)
                     :noquery t
                     :connection-type 'pipe)))))

(provide 'jf-eureka-launcher)
;;; jf-eureka-launcher.el ends here
