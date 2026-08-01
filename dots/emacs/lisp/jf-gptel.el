;;; jf-gptel.el --- Lightweight LLM chat through ChatGPT Pro -*- lexical-binding: t; -*-

(require 'gptel)
(require 'gptel-context)
(require 'gptel-openai-oauth)
(require 'gptel-rewrite)
(require 'gptel-transient)
(require 'subr-x)

;; The transient menu still calls these public compatibility names.  Define
;; them from their canonical implementations explicitly: this also repairs a
;; long-running Emacs whose gptel files changed across a Nix generation.
(defalias 'gptel-add #'gptel-context-add)
(defalias 'gptel-add-file #'gptel-context-add-file)

;; This backend authenticates against the ChatGPT subscription endpoint.  It
;; intentionally has no API key and does not use OpenAI Platform billing.
(setq gptel-model 'gpt-5.4-mini
      gptel-backend (gptel-make-openai-oauth "ChatGPT Pro")
      gptel-default-mode 'org-mode
      gptel-stream t
      gptel-use-curl t
      ;; Treat buffers and files as reference material, not instructions.
      gptel-use-context 'user
      gptel-confirm-tool-calls t
      gptel-rewrite-default-action 'dispatch
      gptel-log-level nil)

(add-hook 'gptel-post-stream-hook #'gptel-auto-scroll)

(defun jf/gptel--buffer-name (&optional source)
  "Return a unique, automatic name for a new chat about SOURCE.

SOURCE is a buffer.  Its name is included only to make chats easier to
recognize; the timestamp keeps unrelated conversations distinct."
  (let ((subject
         (when source
           (string-trim (buffer-name source) "\\*+" "\\*+"))))
    (generate-new-buffer-name
     (format "*AI %s%s*"
             (format-time-string "%Y-%m-%d %H:%M:%S")
             (if (and subject (not (string-empty-p subject)))
                 (format " · %s" subject)
               "")))))

(defun jf/gptel-chat (arg)
  "Open a new automatically named chat.

With prefix ARG, use gptel's buffer chooser instead, which is useful for
returning to an existing conversation."
  (interactive "P")
  (if arg
      (call-interactively #'gptel)
    (gptel (jf/gptel--buffer-name) nil nil t)))

(defun jf/gptel-ask-buffer (arg)
  "Ask about the focused buffer and answer in a new chat.

Read additional instructions from the minibuffer.  The complete widened
buffer is included as the source material.  With prefix ARG, open
`gptel-menu' so the source, destination and model can be adjusted."
  (interactive "P")
  (if arg
      (call-interactively #'gptel-menu)
    (when (minibufferp)
      (user-error "Cannot ask about the minibuffer"))
    (let ((destination (jf/gptel--buffer-name (current-buffer)))
          (transient-mark-mode t))
      (save-restriction
        (widen)
        (save-mark-and-excursion
          ;; gptel's minibuffer reader combines an active region with the
          ;; additional prompt.  Temporarily make the whole buffer that region.
          (goto-char (point-max))
          (push-mark (point-min) t t)
          (setq deactivate-mark nil)
          (gptel--suffix-send (list "m" (concat "g" destination))))))))

;; Leave C-c RET to Org and gptel's own local chat binding.
(keymap-global-set "s-g" #'jf/gptel-chat)
(keymap-global-set "C-c g" #'jf/gptel-ask-buffer)

(provide 'jf-gptel)
;;; jf-gptel.el ends here
