;;; jf-modeline.el --- Custom mode line and system status -*- lexical-binding: t; -*-

(require 'battery)
(require 'subr-x)

;;; Mode line

(defface jf/mode-line-buffer
  '((t :inherit (mode-line-buffer-id mode-line) :weight bold))
  "Face for the current buffer name in the mode line.")

(defface jf/mode-line-buffer-inactive
  '((t :inherit mode-line-inactive :weight bold))
  "Face for inactive buffer names in the mode line.")

(defface jf/mode-line-muted
  '((t :inherit (shadow mode-line)))
  "Face for low-priority mode line text.")

(defface jf/mode-line-muted-inactive
  '((t :inherit mode-line-inactive))
  "Face for inactive low-priority mode line text.")

(defface jf/mode-line-accent
  '((t :inherit (mode-line-emphasis font-lock-keyword-face mode-line)
       :weight medium))
  "Face for highlighted mode line text.")

(defface jf/mode-line-accent-inactive
  '((t :inherit mode-line-inactive :weight medium))
  "Face for inactive highlighted mode line text.")

(defface jf/mode-line-attention
  '((t :inherit (error mode-line) :weight bold))
  "Face for mode line text that needs attention.")

(defface jf/mode-line-attention-inactive
  '((t :inherit mode-line-inactive :weight bold))
  "Face for inactive mode line text that needs attention.")

(defun jf/mode-line-active-p ()
  "Return non-nil when formatting the selected window's mode line."
  (if (fboundp 'mode-line-window-selected-p)
      (mode-line-window-selected-p)
    (eq (selected-window) (get-buffer-window (current-buffer)))))

(defun jf/mode-line-face (face)
  "Return the active or inactive mode line variant of FACE."
  (if (jf/mode-line-active-p)
      (pcase face
        ('buffer 'jf/mode-line-buffer)
        ('muted 'jf/mode-line-muted)
        ('accent 'jf/mode-line-accent)
        ('attention 'jf/mode-line-attention))
    (pcase face
      ('buffer 'jf/mode-line-buffer-inactive)
      ('muted 'jf/mode-line-muted-inactive)
      ('accent 'jf/mode-line-accent-inactive)
      ('attention 'jf/mode-line-attention-inactive))))

(defun jf/mode-line--display-width (string)
  "Return the displayed width of STRING without text properties."
  (string-width (substring-no-properties (or string ""))))

(defun jf/mode-line--truncate-middle (string max-width)
  "Return STRING truncated in the middle to MAX-WIDTH columns."
  (let* ((max-width (max 0 max-width))
         (width (jf/mode-line--display-width string))
         (marker "..."))
    (cond
     ((<= width max-width) string)
     ((<= max-width 0) "")
     ((= max-width 1)
      (truncate-string-to-width string max-width nil nil ""))
     ((= max-width 2)
      (concat
       (truncate-string-to-width string 1 nil nil "")
       (truncate-string-to-width string width (1- width) nil "")))
     ((= max-width 3)
      (concat
       (truncate-string-to-width string 1 nil nil "")
       "."
       (truncate-string-to-width string width (1- width) nil "")))
     (t
      (let* ((content-width (- max-width (string-width marker)))
             (left-width (/ (+ content-width 1) 2))
             (right-width (/ content-width 2))
             (right-start (max 0 (- width right-width))))
        (concat
         (truncate-string-to-width string left-width nil nil "")
         (propertize marker 'face (get-text-property 0 'face string))
         (truncate-string-to-width string width right-start nil "")))))))

(defun jf/mode-line--escape-percent (string)
  "Escape percent characters in STRING for literal mode line display."
  (replace-regexp-in-string "%" "%%" string t t))

(defun jf/mode-line-status ()
  "Return a compact buffer status indicator."
  (cond
   (buffer-read-only
    nil)
   ((buffer-modified-p)
    (propertize "*" 'face (jf/mode-line-face 'attention)))
   (t
    (propertize "-" 'face (jf/mode-line-face 'muted)))))

(defun jf/mode-line-vc ()
  "Return the cached VC branch for the current buffer, if available."
  (when vc-mode
    (concat
     " "
     (propertize
      (string-trim
       (replace-regexp-in-string
        "\\`Git[:-]" "" (substring-no-properties vc-mode)))
      'face (jf/mode-line-face 'accent)))))

(defun jf/battery-data ()
  "Return battery data from Emacs' native battery backend."
  (when battery-status-function
    (funcall battery-status-function)))

(defun jf/mode-line-buffer-name (max-width)
  "Return the current buffer name for the mode line within MAX-WIDTH."
  (propertize
   (jf/mode-line--escape-percent
    (jf/mode-line--truncate-middle (buffer-name) max-width))
   'face (jf/mode-line-face 'buffer)))

(defun jf/mode-line-mode-name ()
  "Return the current major mode name for the mode line."
  (substring-no-properties
   (if (stringp mode-name)
       mode-name
     (format-mode-line mode-name))))

(defun jf/mode-line-right ()
  "Return the right-aligned mode line segment."
  (jf/mode-line-mode-name))

(defun jf/systeminfo ()
  "Show the current time and battery level."
  (interactive)
  (let* ((time (downcase (string-trim (format-time-string "%I:%M %p"))))
         (data (jf/battery-data))
         (capacity (and data (cdr (assq ?p data)))))
    (if capacity
        (message "It's %s. Battery at %s%%." time capacity)
      (message "It's %s. Battery unavailable." time))))

(defun jf/mode-line-left ()
  "Return the left mode-line segment, truncated before the native alignment."
  (let* ((window-width (window-total-width))
         (right (concat (jf/mode-line-right) " "))
         (prefix (concat
                  " "
                  (when-let ((status (jf/mode-line-status)))
                    (concat status " "))))
         (vc (or (jf/mode-line-vc) ""))
         (max-buffer-width
          (- window-width
             (jf/mode-line--display-width prefix)
             (jf/mode-line--display-width vc)
             (jf/mode-line--display-width right)
             1)))
    (concat prefix (jf/mode-line-buffer-name max-buffer-width) vc)))

(setq-default mode-line-format
              '("%e"
                (:eval (jf/mode-line-left))
                mode-line-format-right-align
                (:eval (jf/mode-line-right))
                " "))

;; Keep drag-to-resize, but make completed mode-line clicks inert.
(dolist (event '("<mode-line> <mouse-1>"
                 "<mode-line> <mouse-2>"
                 "<mode-line> <mouse-3>"))
  (keymap-global-set event #'ignore))

(provide 'jf-modeline)
;;; jf-modeline.el ends here
