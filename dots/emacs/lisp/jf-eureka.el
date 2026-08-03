;;; jf-eureka.el --- Eureka session entrypoint -*- lexical-binding: t; -*-

(declare-function jf/startup-mark "early-init" (event))

(jf/startup-mark "jf-eureka entry")

(require 'eureka)

;;; Eureka input policy

(setopt eureka-intercept-prefixes
        '("C-x" "C-u" "C-h" "M-x" "s-x" "s-v" "C-s-v"
          "s-SPC" "s-<tab>"
          "s-q" "s-o"
          "s-n" "C-s-n" "C-s-r"
          "s-/" "s--" "C-s-f"
          "s-t" "s-w" "C-s-w"
          "s-<escape>"
          "s-d" "s-i"
          "s-u"
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

;;; Session bindings

(global-set-key (kbd "s-x") #'jf-eureka-launch-program)
(global-set-key (kbd "s-v") #'jf/vterm)
(global-set-key (kbd "C-s-v") #'jf/vterm-new)
(global-set-key (kbd "s-c") #'jf/codex)

(defun jf-eureka--close-window-preserving-buffer (window buffer)
  "Remove WINDOW while preserving BUFFER.
When WINDOW is the frame's only window, bury BUFFER instead."
  (when (window-live-p window)
    (if (one-window-p t)
        (when (buffer-live-p buffer)
          (bury-buffer buffer))
      (delete-window window))))

(defun jf-eureka-close-dwim ()
  "Close the selected view, killing only resource-owning buffers.
Eureka buffers close their client and vterm buffers terminate their process.
Other Emacs buffers remain alive and available for later selection."
  (interactive)
  (let* ((buffer (current-buffer))
         (window (selected-window))
         (eureka-buffer-p (derived-mode-p 'eureka-mode))
         (kill-buffer-p (or eureka-buffer-p
                            (derived-mode-p 'vterm-mode))))
    (if kill-buffer-p
        ;; Eureka closure is asynchronous: its kill query returns nil after
        ;; requesting client closure, so still remove the view immediately.
        (when (or (kill-buffer buffer) eureka-buffer-p)
          (jf-eureka--close-window-preserving-buffer window buffer))
      (jf-eureka--close-window-preserving-buffer window buffer))))

(global-set-key (kbd "s-q") #'jf-eureka-close-dwim)
(global-set-key (kbd "s-SPC") #'consult-buffer)
(global-set-key (kbd "s-<tab>") #'mode-line-other-buffer)
(global-unset-key (kbd "s-b"))
(global-set-key (kbd "s-n") #'jf-notifications)
(global-set-key (kbd "C-s-n") #'jf/network-manager)
(global-set-key (kbd "C-s-r") #'jf/nixos-rebuild)
(global-unset-key (kbd "s-p"))
(global-set-key (kbd "s-o") #'other-window)
(global-unset-key (kbd "C-s-o"))
(global-set-key (kbd "s-/") #'split-window-right)
(global-set-key (kbd "s--") #'split-window-below)
(global-unset-key (kbd "s-f"))
(global-unset-key (kbd "s-m"))
(global-set-key (kbd "C-s-f") #'toggle-frame-fullscreen)
(global-set-key (kbd "s-t") #'jf-eureka-toggle-color-mode)
(global-set-key (kbd "s-w") #'jf/bookmark-open)
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
