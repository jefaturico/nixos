;;; jf-network.el --- Asynchronous NetworkManager interface -*- lexical-binding: t; -*-

(require 'consult)
(require 'seq)
(require 'subr-x)

(defconst jf/network--action-rescan 'rescan)
(defconst jf/network--action-toggle 'toggle)
(defconst jf/network--action-forget 'forget)

(defvar jf/network--process nil
  "Currently running NetworkManager subprocess, if any.")

(defun jf/network--ensure-nmcli ()
  "Signal a user error when NetworkManager's command client is unavailable."
  (unless (executable-find "nmcli")
    (user-error "nmcli is not available")))

(defun jf/network--error-message (result)
  "Return a useful error message from nmcli RESULT."
  (if (string-empty-p (cdr result))
      "NetworkManager operation failed"
    (cdr result)))

(defun jf/network--successful-p (result)
  "Return non-nil when nmcli RESULT represents success."
  (and (integerp (car result)) (zerop (car result))))

(defun jf/network--run-async (callback &rest arguments)
  "Run nmcli with ARGUMENTS and call CALLBACK with (STATUS . OUTPUT).
Only one request is allowed at a time so an old callback cannot replace a
newer menu.  NetworkManager latency never blocks the Emacs event loop."
  (jf/network--ensure-nmcli)
  (if (process-live-p jf/network--process)
      (message "A NetworkManager request is already in progress")
    (let* ((buffer (generate-new-buffer " *jf-network-manager*"))
           (process-environment (cons "LC_ALL=C" process-environment))
           process)
      (setq process
            (make-process
             :name "jf-network-manager"
             :buffer buffer
             :command (append
                       (list (executable-find "nmcli")
                             "--colors" "no" "--wait" "20")
                       arguments)
             :connection-type 'pipe
             :noquery t
             :sentinel
             (lambda (finished _event)
               (when (memq (process-status finished) '(exit signal))
                 (let ((result
                        (cons (process-exit-status finished)
                              (if (buffer-live-p (process-buffer finished))
                                  (with-current-buffer (process-buffer finished)
                                    (string-trim (buffer-string)))
                                ""))))
                   (when (eq jf/network--process finished)
                     (setq jf/network--process nil))
                   (when (buffer-live-p (process-buffer finished))
                     (kill-buffer (process-buffer finished)))
                   ;; Leave the sentinel before opening a Consult minibuffer
                   ;; or asking for a password.
                   (run-at-time 0 nil callback result))))))
      (setq jf/network--process process)
      process)))

(defun jf/network--split-terse-line (line)
  "Split one escaped, colon-separated nmcli LINE."
  (let ((index 0)
        (length (length line))
        (field "")
        fields)
    (while (< index length)
      (let ((character (aref line index)))
        (cond
         ((and (= character ?\\) (< (1+ index) length))
          (setq index (1+ index)
                field (concat field (string (aref line index)))))
         ((= character ?:)
          (push field fields)
          (setq field ""))
         (t
          (setq field (concat field (string character))))))
      (setq index (1+ index)))
    (nreverse (cons field fields))))

(defun jf/network--terse-rows (output)
  "Parse escaped terse nmcli OUTPUT into rows."
  (mapcar #'jf/network--split-terse-line
          (split-string output "\n" t)))

(defun jf/network--parse-wifi-networks (output)
  "Parse Wi-Fi list OUTPUT into deduplicated network plists."
  (let ((networks (make-hash-table :test #'equal)))
    (dolist (fields (jf/network--terse-rows output))
      (when (>= (length fields) 5)
        (let* ((ssid (nth 1 fields))
               (network (list :active (string= (nth 0 fields) "*")
                              :ssid ssid
                              :signal (string-to-number (nth 2 fields))
                              :security (nth 3 fields)
                              :device (nth 4 fields)))
               (previous (gethash ssid networks)))
          (when (and (not (string-empty-p ssid))
                     (or (null previous)
                         (plist-get network :active)
                         (> (plist-get network :signal)
                            (plist-get previous :signal))))
            (puthash ssid network networks)))))
    (sort (hash-table-values networks)
          (lambda (left right)
            (let ((left-active (plist-get left :active))
                  (right-active (plist-get right :active)))
              (cond
               ((and left-active (not right-active)) t)
               ((and right-active (not left-active)) nil)
               (t (> (plist-get left :signal)
                     (plist-get right :signal)))))))))

(defun jf/network--network-display (network)
  "Format NETWORK for minibuffer selection."
  (format "%s %-32s %3d%%  %-14s %s"
          (if (plist-get network :active) "●" " ")
          (truncate-string-to-width (plist-get network :ssid) 32 nil nil t)
          (plist-get network :signal)
          (let ((security (plist-get network :security)))
            (if (or (string-empty-p security) (string= security "--"))
                "open"
              security))
          (plist-get network :device)))

(defun jf/network--menu-candidates (enabled networks)
  "Return action and NETWORKS candidates, given radio state ENABLED."
  (append
   `(("↻  Rescan Wi-Fi" . ,jf/network--action-rescan)
     (,(if enabled "○  Turn Wi-Fi off" "●  Turn Wi-Fi on")
      . ,jf/network--action-toggle)
     ("×  Forget a saved network…" . ,jf/network--action-forget))
   (mapcar (lambda (network)
             (cons (jf/network--network-display network) network))
           networks)))

(defun jf/network--show-menu (enabled networks)
  "Show the NetworkManager menu for ENABLED state and NETWORKS."
  (let* ((active (seq-find (lambda (network)
                             (plist-get network :active))
                           networks))
         (prompt (cond
                  ((not enabled) "Network (Wi-Fi off): ")
                  (active (format "Network (%s): " (plist-get active :ssid)))
                  (t "Network (disconnected): ")))
         (candidates (jf/network--menu-candidates enabled networks))
         (choice (consult--read (mapcar #'car candidates)
                                :prompt prompt
                                :require-match t
                                :sort nil
                                :category 'network))
         (selection (cdr (assoc choice candidates))))
    (pcase selection
      ('rescan (jf/network--load t))
      ('toggle (jf/network--toggle enabled))
      ('forget (jf/network-forget))
      ((pred listp)
       (if (plist-get selection :active)
           (jf/network--disconnect selection)
         (jf/network--connect selection))))))

(defun jf/network--load (&optional rescan)
  "Load radio state and networks asynchronously, forcing scan when RESCAN."
  (message "%s" (if rescan "Rescanning Wi-Fi…" "Loading networks…"))
  (jf/network--run-async
   (lambda (radio-result)
     (if (not (jf/network--successful-p radio-result))
         (message "%s" (jf/network--error-message radio-result))
       (let ((enabled (string= (cdr radio-result) "enabled")))
         (if (not enabled)
             (jf/network--show-menu nil nil)
           (jf/network--run-async
            (lambda (list-result)
              (if (jf/network--successful-p list-result)
                  (jf/network--show-menu
                   t (jf/network--parse-wifi-networks (cdr list-result)))
                (message "%s" (jf/network--error-message list-result))))
            "--terse" "--escape" "yes"
            "--fields" "IN-USE,SSID,SIGNAL,SECURITY,DEVICE"
            "device" "wifi" "list"
            "--rescan" (if rescan "yes" "auto"))))))
   "--terse" "--get-values" "WIFI" "radio"))

(defun jf/network--toggle (enabled)
  "Asynchronously toggle Wi-Fi from current state ENABLED."
  (let ((new-state (if enabled "off" "on")))
    (message "Turning Wi-Fi %s…" new-state)
    (jf/network--run-async
     (lambda (result)
       (if (jf/network--successful-p result)
           (progn
             (message "Wi-Fi turned %s" new-state)
             (jf/network--load (string= new-state "on")))
         (message "%s" (jf/network--error-message result))))
     "radio" "wifi" new-state)))

(defun jf/network--connect-with-arguments (ssid arguments &optional password)
  "Connect to SSID asynchronously using ARGUMENTS and optional PASSWORD."
  (message "Connecting to %s…" ssid)
  (apply
   #'jf/network--run-async
   (lambda (result)
     (cond
      ((jf/network--successful-p result)
       (message "Connected to %s" ssid))
      ((and (null password)
            (string-match-p "\\(?:[Ss]ecret\\|[Pp]assword\\)" (cdr result)))
       (let ((entered (read-passwd (format "Password for %s: " ssid))))
         (unwind-protect
             (jf/network--connect-with-arguments ssid arguments entered)
           (clear-string entered))))
      (t
       (message "%s" (jf/network--error-message result)))))
   (append arguments (when password (list "password" password)))))

(defun jf/network--connect (network)
  "Connect asynchronously to NETWORK."
  (let ((ssid (plist-get network :ssid))
        (device (plist-get network :device)))
    (jf/network--connect-with-arguments
     ssid
     (append (list "device" "wifi" "connect" ssid)
             (unless (string-empty-p device)
               (list "ifname" device))))))

(defun jf/network--disconnect (network)
  "Disconnect asynchronously from active NETWORK."
  (let ((device (plist-get network :device))
        (ssid (plist-get network :ssid)))
    (if (string-empty-p device)
        (message "NetworkManager did not report a device for this connection")
      (message "Disconnecting from %s…" ssid)
      (jf/network--run-async
       (lambda (result)
         (if (jf/network--successful-p result)
             (message "Disconnected from %s" ssid)
           (message "%s" (jf/network--error-message result))))
       "device" "disconnect" device))))

(defun jf/network--parse-saved-connections (output)
  "Parse saved Wi-Fi connections from nmcli OUTPUT."
  (delq nil
        (mapcar
         (lambda (fields)
           (when (and (>= (length fields) 3)
                      (member (nth 2 fields) '("802-11-wireless" "wifi")))
             (let ((name (nth 0 fields))
                   (uuid (nth 1 fields)))
               (cons (format "%s  (%s)"
                             name (substring uuid 0 (min 8 (length uuid))))
                     uuid))))
         (jf/network--terse-rows output))))

(defun jf/network-forget ()
  "Choose and asynchronously delete a saved NetworkManager Wi-Fi profile."
  (interactive)
  (message "Loading saved networks…")
  (jf/network--run-async
   (lambda (result)
     (if (not (jf/network--successful-p result))
         (message "%s" (jf/network--error-message result))
       (let ((connections (jf/network--parse-saved-connections (cdr result))))
         (if (null connections)
             (message "There are no saved Wi-Fi networks")
           (let* ((choice (consult--read (mapcar #'car connections)
                                         :prompt "Forget network: "
                                         :require-match t
                                         :sort nil
                                         :category 'network-connection))
                  (uuid (cdr (assoc choice connections))))
             (when (yes-or-no-p (format "Delete saved connection %s? " choice))
               (message "Forgetting %s…" choice)
               (jf/network--run-async
                (lambda (delete-result)
                  (if (jf/network--successful-p delete-result)
                      (message "Forgot %s" choice)
                    (message "%s" (jf/network--error-message delete-result))))
                "connection" "delete" "uuid" uuid)))))))
   "--terse" "--escape" "yes"
   "--fields" "NAME,UUID,TYPE" "connection" "show"))

(defun jf/network-manager ()
  "Open the asynchronous NetworkManager Wi-Fi interface."
  (interactive)
  (jf/network--ensure-nmcli)
  (jf/network--load))

(provide 'jf-network)
;;; jf-network.el ends here
