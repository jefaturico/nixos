;;; jf-nixos.el --- NixOS rebuild interface -*- lexical-binding: t; -*-

(require 'ansi-color)
(require 'compile)
(require 'consult)
(require 'seq)
(require 'subr-x)

(defcustom jf/nixos-repository (expand-file-name "~/nixos/")
  "Directory containing the NixOS flake."
  :type 'directory)

(defconst jf/nixos--actions
  '(("Switch — build and activate permanently" . switch)
    ("Test — activate until the next boot" . test)
    ("Boot — build and select for the next boot" . boot)
    ("Build — evaluate and build without activating" . build))
  "Actions offered by `jf/nixos-rebuild'.")

(defvar-local jf/nixos--stage 0)
(defvar-local jf/nixos--stage-label "Starting")
(defvar-local jf/nixos--started-at nil)
(defvar-local jf/nixos--result nil)
(defvar-local jf/nixos--timer nil)

(defun jf/nixos--host ()
  "Return the current machine's short hostname."
  (car (split-string (system-name) "\\." t)))

(defun jf/nixos--repository ()
  "Return and validate `jf/nixos-repository'."
  (let ((directory (file-name-as-directory
                    (expand-file-name jf/nixos-repository))))
    (unless (file-readable-p (expand-file-name "flake.nix" directory))
      (user-error "No readable flake.nix in %s" directory))
    directory))

(defun jf/nixos--sudo-program ()
  "Return the system sudo wrapper or signal a user error."
  (let ((sudo "/run/wrappers/bin/sudo"))
    (unless (file-executable-p sudo)
      (user-error "The NixOS sudo wrapper is unavailable"))
    sudo))

(defun jf/nixos--elapsed ()
  "Return elapsed operation time as MM:SS."
  (let* ((seconds (if jf/nixos--started-at
                      (floor (float-time
                              (time-subtract nil jf/nixos--started-at)))
                    0))
         (minutes (/ seconds 60)))
    (format "%02d:%02d" minutes (% seconds 60))))

(defun jf/nixos--mode-line-status ()
  "Return the compact rebuild status displayed in the mode line."
  (let* ((complete (min jf/nixos--stage 5))
         (filled (make-string complete ?●))
         (empty (make-string (- 5 complete) ?○))
         (face (pcase jf/nixos--result
                 ('success 'success)
                 ('failed 'error)
                 (_ 'mode-line-emphasis))))
    (propertize
     (format " NixOS [%s%s] %s · %s"
             filled empty jf/nixos--stage-label (jf/nixos--elapsed))
     'face face)))

(defun jf/nixos--tick (buffer)
  "Refresh elapsed time for rebuild BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (force-mode-line-update t))))

(defun jf/nixos--set-stage (stage label)
  "Set current rebuild STAGE and LABEL when it advances."
  (when (> stage jf/nixos--stage)
    (setq jf/nixos--stage stage
          jf/nixos--stage-label label)
    (force-mode-line-update t)))

(defun jf/nixos--track-output ()
  "Update the concise stage indicator from newly inserted rebuild output."
  (let ((output (buffer-substring-no-properties
                 (max (point-min) (- compilation-filter-start 100))
                 (point-max))))
    (cond
     ((string-match-p "reloading user units\\|restarting.*units" output)
      (jf/nixos--set-stage 4 "Reloading services"))
     ((string-match-p "activating the configuration\\|setting up /etc" output)
      (jf/nixos--set-stage 3 "Activating system"))
     ((string-match-p "Checking switch inhibitors\\|updating GRUB" output)
      (jf/nixos--set-stage 2 "Preparing activation"))
     ((string-match-p "building the system configuration" output)
      (jf/nixos--set-stage 1 "Evaluating / building")))))

(define-compilation-mode jf/nixos-rebuild-mode "NixOS-Rebuild"
  "Compilation mode for concise NixOS rebuild output."
  (setq-local compilation-scroll-output t
              header-line-format nil
              mode-line-process '(:eval (jf/nixos--mode-line-status)))
  (add-hook 'compilation-filter-hook #'ansi-color-compilation-filter nil t)
  (add-hook 'compilation-filter-hook #'jf/nixos--track-output nil t)
  (add-hook 'kill-buffer-hook #'jf/nixos--cancel-timer nil t))

(defun jf/nixos--cancel-timer ()
  "Cancel this rebuild buffer's elapsed-time timer."
  (when (timerp jf/nixos--timer)
    (cancel-timer jf/nixos--timer)
    (setq jf/nixos--timer nil)))

(defun jf/nixos--running-process ()
  "Return a live process from any NixOS rebuild buffer."
  (seq-find
   (lambda (process)
     (and (process-live-p process)
          (buffer-live-p (process-buffer process))
          (with-current-buffer (process-buffer process)
            (derived-mode-p 'jf/nixos-rebuild-mode))))
   (process-list)))

(defun jf/nixos--command (action repository host)
  "Construct command arguments for ACTION in REPOSITORY targeting HOST."
  (let ((flake (format "path:%s#%s"
                       (directory-file-name repository) host)))
    (if (eq action 'build)
        (list (or (executable-find "nix")
                  (user-error "nix executable not found"))
              "--log-format" "bar-with-logs"
              "--print-build-logs"
              "build"
              (format "%s#nixosConfigurations.%s.config.system.build.toplevel"
                      (substring flake 0 (string-search "#" flake)) host)
              "--no-link")
      (list (jf/nixos--sudo-program)
            "--non-interactive"
            (or (executable-find "nixos-rebuild")
                (user-error "nixos-rebuild executable not found"))
            "--log-format" "bar-with-logs"
            "--print-build-logs"
            (symbol-name action)
            "--flake" flake))))

(defun jf/nixos--finish (buffer status)
  "Record completion STATUS and leave the result visible in BUFFER."
  (with-current-buffer buffer
    (jf/nixos--cancel-timer)
    (let ((success (string-prefix-p "finished" status))
          (inhibit-read-only t))
      (setq jf/nixos--stage 5
            jf/nixos--result (if success 'success 'failed)
            jf/nixos--stage-label (if success "Succeeded" "Failed"))
      (goto-char (point-max))
      (insert (propertize
               (format "\n%s NixOS operation %s in %s\n"
                       (if success "✓" "✗")
                       (if success "succeeded" "failed")
                       (jf/nixos--elapsed))
               'face (if success 'success 'error)
               'font-lock-face (if success 'success 'error)))
      (force-mode-line-update t)
      (if success
          (message "NixOS operation completed successfully")
        (message "NixOS operation failed; see %s" (buffer-name buffer))))))

(defun jf/nixos--start (action)
  "Start NixOS rebuild ACTION in a persistent compilation buffer."
  (when-let ((process (jf/nixos--running-process)))
    (pop-to-buffer (process-buffer process))
    (user-error "A NixOS operation is already running"))
  (let* ((repository (jf/nixos--repository))
         (host (jf/nixos--host))
         (privileged (memq action '(switch test boot))))
    (when (and privileged
               (not (yes-or-no-p
                     (format "Run nixos-rebuild %s for %s? " action host))))
      (user-error "Rebuild cancelled"))
    (let ((password (and privileged (read-passwd "Sudo password: "))))
      (unwind-protect
          (let* ((default-directory repository)
                 (action-command
                  (mapconcat #'shell-quote-argument
                             (jf/nixos--command action repository host) " "))
                 (command
                  (if privileged
                      (let ((sudo (shell-quote-argument
                                   (jf/nixos--sudo-program))))
                        (format "%s -k; %s --stdin --prompt= --validate && %s"
                                sudo sudo action-command))
                    action-command))
                 ;; Sudo password input is reliable only over a pipe.
                 (process-connection-type nil)
                 (buffer (compilation-start
                          command #'jf/nixos-rebuild-mode
                          (lambda (_) (format "*nixos-%s:%s*" action host)))))
            (with-current-buffer buffer
              (setq jf/nixos--stage 1
                    jf/nixos--stage-label "Evaluating / building"
                    jf/nixos--started-at (current-time)
                    jf/nixos--result nil)
              (when (timerp jf/nixos--timer)
                (cancel-timer jf/nixos--timer))
              (setq jf/nixos--timer
                    (run-at-time 1 1 #'jf/nixos--tick buffer))
              (add-hook 'compilation-finish-functions #'jf/nixos--finish nil t))
            (when password
              (let ((process (get-buffer-process buffer)))
                (process-send-string process (concat password "\n"))
                (process-send-eof process)))
            (pop-to-buffer buffer)
            (message "NixOS %s started for %s" action host)
            buffer)
        (when password
          (clear-string password))))))

(defun jf/nixos-rebuild ()
  "Choose and run a concise NixOS operation for this machine."
  (interactive)
  (let* ((host (jf/nixos--host))
         (choice (consult--read (mapcar #'car jf/nixos--actions)
                                :prompt (format "NixOS (%s): " host)
                                :require-match t
                                :sort nil
                                :category 'nixos-action))
         (action (cdr (assoc choice jf/nixos--actions))))
    (jf/nixos--start action)))

(provide 'jf-nixos)
;;; jf-nixos.el ends here
