;;; early-init.el -*- lexical-binding: t; -*-

(defvar jf/startup-log-file (getenv "EUREKA_STARTUP_LOG")
  "File receiving Eureka cold-start timing events.")

(defvar jf/startup-epoch-ns
  (when-let ((value (getenv "EUREKA_STARTUP_EPOCH_NS")))
    (string-to-number value))
  "Unix epoch in nanoseconds recorded by eureka-init.")

(defvar jf/startup-log-lines nil
  "Startup timing lines waiting to be written in one batch.")

(defun jf/startup-mark (event)
  "Append EVENT and its elapsed time to the Eureka startup log."
  (when (and jf/startup-log-file jf/startup-epoch-ns)
    (let* (;; Retain millisecond resolution using `float-time'.
           (elapsed-ms
            (round (* 1000.0
                      (- (float-time)
                         (/ jf/startup-epoch-ns 1000000000.0)))))
           (line (format "%8d ms  emacs  %s\n" elapsed-ms event)))
      (push line jf/startup-log-lines))))

(defun jf/startup-log-flush ()
  "Append all buffered Emacs startup events to the session log."
  (when (and jf/startup-log-file jf/startup-log-lines)
    (let ((text (apply #'concat (nreverse jf/startup-log-lines))))
      (setq jf/startup-log-lines nil)
      (ignore-errors
        (write-region text nil jf/startup-log-file t 'silent)))))

(jf/startup-mark "early-init entry")

(setq package-enable-at-startup nil
      frame-inhibit-implied-resize t)

(defvar jf/orig-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(setq native-comp-async-report-warnings-errors 'silent)

(setq inhibit-startup-screen t
      inhibit-startup-message t)

(defconst jf/early-background "#000000"
  "Initial frame background used before the real theme loads.")

(defconst jf/early-foreground "#ffffff"
  "Initial frame foreground used before the real theme loads.")

;; Restore file-name-handler after startup, but let gcmh handle GC
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist jf/orig-file-name-handler-alist)))

;; Prevent UI flash
(let ((jf/early-frame-parameters
       `((background-color . ,jf/early-background)
         (foreground-color . ,jf/early-foreground)
         (cursor-color . ,jf/early-foreground)
         (mouse-color . ,jf/early-foreground)
         (border-color . ,jf/early-background)
         (internal-border-width . 0)
         (menu-bar-lines . 0)
         (tool-bar-lines . 0)
         (vertical-scroll-bars . nil)
         (undecorated . t))))
  (setq default-frame-alist
        (append jf/early-frame-parameters default-frame-alist)
        initial-frame-alist
        (append jf/early-frame-parameters initial-frame-alist)))

(set-face-attribute 'default nil
                    :background jf/early-background
                    :foreground jf/early-foreground)
(set-face-attribute 'mode-line nil
                    :background jf/early-background
                    :foreground jf/early-foreground
                    :box nil)
(set-face-attribute 'mode-line-inactive nil
                    :background jf/early-background
                    :foreground jf/early-foreground
                    :box nil)

(fringe-mode 0)
(setq-default mode-line-format nil)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

(jf/startup-mark "early-init exit")
