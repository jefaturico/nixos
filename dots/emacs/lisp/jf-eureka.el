;;; jf-eureka.el --- Eureka session entrypoint -*- lexical-binding: t; -*-

(declare-function jf/startup-mark "early-init" (event))

(jf/startup-mark "jf-eureka entry")

(require 'eureka)

;;; Eureka input policy

(defvar-local jf-eureka--initial-placeholder nil
  "Non-nil when this buffer is only the initial workspace placeholder.")

(defun jf-eureka--placeholder-buffer-p (buffer)
  "Return non-nil when BUFFER should be replaced by the first Eureka client."
  (with-current-buffer buffer
    (or jf-eureka--initial-placeholder
        (string= (buffer-name) "*scratch*"))))

(setopt eureka-placeholder-buffer-predicate #'jf-eureka--placeholder-buffer-p)

(setopt eureka-intercept-prefixes
        '("C-x" "C-u" "C-h" "M-x" "s-x" "s-v" "s-<return>"
          "s-q" "s-k" "s-b" "s-o"
          "s-n"
          "s-/" "s--" "C-s-f"
          "s-t" "s-w" "C-s-w"
          "s-<escape>"
          "s-d" "s-i"
          "s-u"
          "s-0" "s-1" "s-2" "s-3" "s-4"
          "s-5" "s-6" "s-7" "s-8" "s-9"
          "C-s-0" "C-s-1" "C-s-2" "C-s-3" "C-s-4"
          "C-s-5" "C-s-6" "C-s-7" "C-s-8" "C-s-9"
          "<XF86AudioRaiseVolume>"
          "<XF86AudioLowerVolume>"
          "<XF86AudioMute>"
          "<XF86AudioMicMute>"
          "<XF86MonBrightnessUp>"
          "<XF86MonBrightnessDown>"
          "<PowerOff>"
          "<XF86PowerOff>"))

;; River no longer provides riverctl. Eureka supplies the protocol mechanism;
;; this session file owns the input policy applied to current and hot-plugged
;; devices.
(setopt eureka-input-repeat-rate 60
        eureka-input-repeat-delay 200
        eureka-touchpad-accel-speed 0.3
        eureka-mouse-accel-speed 0.0
        eureka-touchpad-tap t
        eureka-touchpad-natural-scroll t
        eureka-touchpad-disable-while-typing t
        eureka-touchpad-disable-while-trackpointing t
        eureka-touchpad-drag-lock t
        eureka-touchpad-two-finger-scroll t
        eureka-touchpad-accel-profile "adaptive"
        eureka-mouse-accel-profile "flat")

(require 'jf-eureka-session)
(require 'jf-eureka-launcher)
(require 'jf-eureka-notifications)
(require 'jf-eureka-desktop)

;;; Workspace and session bindings

(dotimes (digit 10)
  (let ((key (number-to-string digit))
        (workspace-digit digit))
    (global-set-key (kbd (concat "s-" key))
                    (lambda ()
                      (interactive)
                      (jf-eureka-switch-workspace workspace-digit)))
    (global-set-key (kbd (concat "C-s-" key))
                    (lambda ()
                      (interactive)
                      (jf-eureka-move-buffer-to-workspace workspace-digit)))))

(global-set-key (kbd "s-x") #'jf-eureka-launch-program)
(global-set-key (kbd "s-v") #'vterm-other-window)
(global-set-key (kbd "s-q") #'delete-window)
(global-set-key (kbd "s-k") #'kill-current-buffer)
(global-set-key (kbd "s-b") #'consult-buffer)
(global-set-key (kbd "s-n") #'jf-notifications)
(global-unset-key (kbd "s-p"))
(global-unset-key (kbd "s-<tab>"))
(global-set-key (kbd "s-o") #'other-window)
(global-unset-key (kbd "C-s-o"))
(global-set-key (kbd "s-/") #'split-window-right)
(global-set-key (kbd "s--") #'split-window-below)
(global-set-key (kbd "s-<return>") #'delete-other-windows)
(global-unset-key (kbd "s-f"))
(global-unset-key (kbd "s-m"))
(global-unset-key (kbd "s-SPC"))
(global-set-key (kbd "C-s-f") #'toggle-frame-fullscreen)
(global-set-key (kbd "s-t") #'jf-eureka-toggle-color-mode)
(global-set-key (kbd "s-w") #'jf/bookmark-open)
(global-unset-key (kbd "s-W"))
(global-set-key (kbd "C-s-w") #'jf/browser-open-or-search)
(global-set-key (kbd "s-u") #'jf-eureka-usb-open)
(global-set-key (kbd "s-i") #'jf/systeminfo)
(global-set-key (kbd "s-d") #'jf/pick-pdf)
(global-set-key (kbd "s-<escape>") #'jf-eureka-power-menu)
(global-unset-key (kbd "C-x C-c"))
(global-set-key (kbd "<XF86AudioRaiseVolume>") #'jf-eureka-volume-up)
(global-set-key (kbd "<XF86AudioLowerVolume>") #'jf-eureka-volume-down)
(global-set-key (kbd "<XF86AudioMute>") #'jf-eureka-volume-mute)
(global-set-key (kbd "<XF86AudioMicMute>") #'jf-eureka-mic-mute)
(global-set-key (kbd "<XF86MonBrightnessUp>") #'jf-eureka-brightness-up)
(global-set-key (kbd "<XF86MonBrightnessDown>") #'jf-eureka-brightness-down)
(global-set-key (kbd "<PowerOff>") #'jf-eureka-suspend)
(global-set-key (kbd "<XF86PowerOff>") #'jf-eureka-suspend)

(defun jf-eureka-set-home-directory ()
  "Use the home directory for file prompts in Eureka client buffers."
  (setq-local default-directory (file-name-as-directory
                                 (expand-file-name "~/"))))

(add-hook 'eureka-mode-hook #'jf-eureka-set-home-directory)

;;; Session startup

(defun jf-eureka--push-builtin-intercepts ()
  "Register Eureka builtin intercepts for keys handled outside Emacs."
  (eureka-push-intercept-prefix "C-s-f" 'toggle-fullscreen)
  (eureka-push-intercept-prefix "<Print>" 'toggle-fullscreen))

(remove-hook 'eureka-enable-hook #'jf-eureka--push-builtin-intercepts)
(add-hook 'eureka-enable-hook #'jf-eureka--push-builtin-intercepts)

(unless eureka-handle
  (jf/startup-mark "eureka-enable start")
  (eureka-enable)
  (jf/startup-mark "eureka-enable end"))

;; Neither operation is required to claim River's WM role or construct the
;; initial agenda.  Keep them off the login-to-first-buffer critical path.
(run-with-idle-timer 1 nil #'jf-eureka--inhibit-logind-power-key)
(run-with-idle-timer 1 nil #'jf-eureka-notifications-start)

(jf/startup-mark "jf-eureka exit")

(provide 'jf-eureka)
;;; jf-eureka.el ends here
