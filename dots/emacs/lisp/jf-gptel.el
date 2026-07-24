;;; jf-gptel.el --- Lightweight LLM chat through ChatGPT Pro -*- lexical-binding: t; -*-

(require 'gptel)
(require 'gptel-context)
(require 'gptel-openai-oauth)
(require 'gptel-rewrite)

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
      gptel-use-curl t)

;; Make sending available outside dedicated gptel buffers too.  C-c RET is
;; gptel's standard chat-buffer binding.
(keymap-global-set "C-c RET" #'gptel-send)

(provide 'jf-gptel)
;;; jf-gptel.el ends here
