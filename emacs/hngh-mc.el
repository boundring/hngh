;;; hngh-mc.el --- Mission-control dashboard for hngh -*- lexical-binding: t -*-

;; MC-2 wave 1 - produced by opencode (kimi-k3, attended), 2026-07-31.
;; Emacs 30.2+.  Built-ins only; eat is optional (svc-dash panel).
;; tmux (`mc') remains the headless fallback and manages the hngh daemon.

;;; Code:

(require 'subr-x)

(declare-function eat-exec "eat")
(declare-function eat-mode "eat")

(defvar hngh-mc-status-buffer-name "*hngh-status*"
  "Name of the hngh-status panel buffer.")

(defvar hngh-mc-events-buffer-name "*hngh-events*"
  "Name of the event-journal panel buffer.")

(defvar hngh-mc-llmtrim-buffer-name "*llmtrim*"
  "Name of the llmtrim panel buffer.")

(defvar hngh-mc-svc-dash-buffer-name "*svc-dash*"
  "Name of the svc-dash terminal buffer.")

(defvar hngh-mc-events-directory (expand-file-name "~/.hngh/journal/events/")
  "Directory holding hngh event journal files (YYYY-MM-DD.lisp).")

(defvar hngh-mc-svc-dash-project (expand-file-name "~/Projects/etc/svc-dash")
  "Project directory handed to uv for the svc-dash TUI.")

(defvar hngh-mc-status-refresh-interval 5
  "Seconds between automatic hngh-status panel refreshes.")

(defvar hngh-mc-llmtrim-refresh-interval 30
  "Seconds between automatic llmtrim panel refreshes.")

(defvar hngh-mc--refresh-timer nil
  "Timer driving status-panel refresh and event-journal rollover.")

(defvar hngh-mc--llmtrim-timer nil
  "Timer driving llmtrim panel refresh.")

(defun hngh-mc--command-output (program &rest args)
  "Return the output of PROGRAM invoked with ARGS, or a notice if missing."
  (if-let* ((executable (executable-find program)))
      (with-temp-buffer
        (apply #'call-process executable nil t nil args)
        (buffer-string))
    (format "%s: executable not found on PATH\n" program)))

(define-derived-mode hngh-mc-status-mode special-mode "hngh-status"
  "Major mode for the hngh-status panel.")

(define-derived-mode hngh-mc-llmtrim-mode special-mode "llmtrim"
  "Major mode for the llmtrim panel.")

(defun hngh-mc--revert-status (&optional _ignore-auto _noconfirm)
  "Re-run hngh-status and replace the status panel contents."
  (let ((inhibit-read-only t)
        (position (point)))
    (erase-buffer)
    (insert (hngh-mc--command-output "hngh-status"))
    (goto-char (min position (point-max)))))

(defun hngh-mc--revert-llmtrim (&optional _ignore-auto _noconfirm)
  "Re-run llmtrim status and replace the llmtrim panel contents."
  (let ((inhibit-read-only t)
        (position (point)))
    (erase-buffer)
    (insert (hngh-mc--command-output "llmtrim" "status"))
    (goto-char (min position (point-max)))))

(defun hngh-mc--status-buffer ()
  "Return the hngh-status panel buffer, creating and populating it."
  (let ((buffer (get-buffer-create hngh-mc-status-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'hngh-mc-status-mode)
        (hngh-mc-status-mode))
      (setq-local revert-buffer-function #'hngh-mc--revert-status)
      (hngh-mc--revert-status nil t))
    buffer))

(defun hngh-mc--llmtrim-buffer ()
  "Return the llmtrim panel buffer, creating and populating it."
  (let ((buffer (get-buffer-create hngh-mc-llmtrim-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'hngh-mc-llmtrim-mode)
        (hngh-mc-llmtrim-mode))
      (setq-local revert-buffer-function #'hngh-mc--revert-llmtrim)
      (hngh-mc--revert-llmtrim nil t))
    buffer))

(defun hngh-mc--events-newest-file ()
  "Return the newest journal file in `hngh-mc-events-directory', or nil."
  (when (file-directory-p hngh-mc-events-directory)
    (car (last (sort (directory-files
                      hngh-mc-events-directory t
                      "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\.lisp\\'")
                     #'string-lessp)))))

(defun hngh-mc--events-placeholder ()
  "Return the events panel buffer shown when no journal files exist."
  (let ((buffer (get-buffer-create hngh-mc-events-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "No event journal files in " hngh-mc-events-directory "\n"))
      (special-mode))
    buffer))

(defun hngh-mc--events-buffer ()
  "Return the events panel buffer tailing the newest journal file."
  (let ((file (hngh-mc--events-newest-file)))
    (if (null file)
        (hngh-mc--events-placeholder)
      (let ((stale (get-buffer hngh-mc-events-buffer-name)))
        (when (and stale (not (equal (buffer-file-name stale) file)))
          (kill-buffer stale)))
      (let ((buffer (find-file-noselect file)))
        (with-current-buffer buffer
          (unless (string= (buffer-name) hngh-mc-events-buffer-name)
            (rename-buffer hngh-mc-events-buffer-name))
          (read-only-mode 1)
          (auto-revert-tail-mode 1)
          (goto-char (point-max)))
        buffer))))

(defun hngh-mc--events-maybe-switch ()
  "Roll the events panel over to a newer journal file when one appears."
  (when-let* ((file (hngh-mc--events-newest-file))
              (buffer (get-buffer hngh-mc-events-buffer-name)))
    (when (not (equal (buffer-file-name buffer) file))
      (kill-buffer buffer)
      (let ((replacement (hngh-mc--events-buffer)))
        (unless (get-buffer-window replacement)
          (display-buffer replacement
                          '((display-buffer-in-side-window)
                            (side . right) (slot . 0) (dedicated . t))))))))

(defun hngh-mc--delete-side-windows ()
  "Delete every side window on the selected frame."
  (dolist (window (window-list))
    (when (and (window-live-p window)
               (window-parameter window 'window-side))
      (delete-window window))))

(defun hngh-mc--layout (status-buffer events-buffer llmtrim-buffer)
  "Display STATUS-BUFFER left, EVENTS-BUFFER right-top, LLMTRIM-BUFFER below."
  (hngh-mc--delete-side-windows)
  (delete-other-windows)
  (let ((display-buffer-alist
         `((,(concat "\\`" (regexp-quote hngh-mc-events-buffer-name) "\\'")
            (display-buffer-in-side-window)
            (side . right) (slot . 0) (dedicated . t))
           (,(concat "\\`" (regexp-quote hngh-mc-llmtrim-buffer-name) "\\'")
            (display-buffer-in-side-window)
            (side . right) (slot . 1) (dedicated . t)))))
    (display-buffer events-buffer)
    (display-buffer llmtrim-buffer))
  (set-window-buffer (window-main-window) status-buffer)
  (select-window (window-main-window)))

(defun hngh-mc--refresh-status ()
  "Refresh the hngh-status panel if its buffer exists."
  (when-let* ((buffer (get-buffer hngh-mc-status-buffer-name)))
    (with-current-buffer buffer
      (hngh-mc--revert-status nil t))))

(defun hngh-mc--refresh-llmtrim ()
  "Refresh the llmtrim panel if its buffer exists."
  (when-let* ((buffer (get-buffer hngh-mc-llmtrim-buffer-name)))
    (with-current-buffer buffer
      (hngh-mc--revert-llmtrim nil t))))

(defun hngh-mc--live-p ()
  "Return non-nil while any dashboard buffer is live."
  (let ((live nil))
    (dolist (name (list hngh-mc-status-buffer-name
                        hngh-mc-events-buffer-name
                        hngh-mc-llmtrim-buffer-name
                        hngh-mc-svc-dash-buffer-name))
      (when (get-buffer name)
        (setq live t)))
    live))

(defun hngh-mc--cancel-timers ()
  "Cancel and clear all dashboard timers."
  (dolist (symbol '(hngh-mc--refresh-timer hngh-mc--llmtrim-timer))
    (when (timerp (symbol-value symbol))
      (cancel-timer (symbol-value symbol))
      (set symbol nil))))

(defun hngh-mc--tick ()
  "Refresh status and journal rollover, or self-cancel when closed."
  (if (hngh-mc--live-p)
      (progn
        (hngh-mc--refresh-status)
        (hngh-mc--events-maybe-switch))
    (hngh-mc--cancel-timers)))

(defun hngh-mc--tick-llmtrim ()
  "Refresh the llmtrim panel, or self-cancel when closed."
  (if (hngh-mc--live-p)
      (hngh-mc--refresh-llmtrim)
    (hngh-mc--cancel-timers)))

(defun hngh-mc--ensure-timers ()
  "Start the dashboard timers unless they are already running."
  (unless (timerp hngh-mc--refresh-timer)
    (setq hngh-mc--refresh-timer
          (run-at-time hngh-mc-status-refresh-interval
                       hngh-mc-status-refresh-interval
                       #'hngh-mc--tick)))
  (unless (timerp hngh-mc--llmtrim-timer)
    (setq hngh-mc--llmtrim-timer
          (run-at-time hngh-mc-llmtrim-refresh-interval
                       hngh-mc-llmtrim-refresh-interval
                       #'hngh-mc--tick-llmtrim))))

;;;###autoload
(defun hngh-mc-open ()
  "Open the hngh mission-control dashboard in the selected frame."
  (interactive)
  (hngh-mc--layout (hngh-mc--status-buffer)
                   (hngh-mc--events-buffer)
                   (hngh-mc--llmtrim-buffer))
  (hngh-mc--ensure-timers))

;;;###autoload
(defun hngh-mc-refresh ()
  "Refresh every hngh mission-control panel immediately."
  (interactive)
  (hngh-mc--refresh-status)
  (hngh-mc--refresh-llmtrim)
  (hngh-mc--events-maybe-switch))

;;;###autoload
(defun hngh-mc-svc-dash ()
  "Open the svc-dash TUI, using eat when available and compile otherwise."
  (interactive)
  (let ((buffer (get-buffer-create hngh-mc-svc-dash-buffer-name)))
    (if (require 'eat nil t)
        (progn
          (with-current-buffer buffer
            (unless (derived-mode-p 'eat-mode)
              (eat-mode))
            (unless (get-buffer-process buffer)
              (apply #'eat-exec buffer "svc-dash" "uv" nil
                     (list "run" "--project" hngh-mc-svc-dash-project
                           "python" "-m" "svc_dash.app"))))
          (pop-to-buffer buffer))
      (with-current-buffer buffer
        (let ((compilation-buffer-name-function
               (lambda (_mode) hngh-mc-svc-dash-buffer-name)))
          (compile (concat "uv run --project "
                           (shell-quote-argument hngh-mc-svc-dash-project)
                           " python -m svc_dash.app")))
        (setq-local mode-line-process
                    " [eat unavailable: compilation fallback]"))
      (pop-to-buffer buffer))))

;;;###autoload
(defun hngh-mc-tmux-status ()
  "Display a one-line summary of `mc status' in the echo area."
  (interactive)
  (message "%s" (string-trim (hngh-mc--command-output "mc" "status"))))

;;;###autoload
(defun hngh-mc-close ()
  "Kill dashboard timers and buffers, and remove dashboard windows."
  (interactive)
  (hngh-mc--cancel-timers)
  (hngh-mc--delete-side-windows)
  (let ((kill-buffer-query-functions nil))
    (dolist (name (list hngh-mc-status-buffer-name
                        hngh-mc-events-buffer-name
                        hngh-mc-llmtrim-buffer-name
                        hngh-mc-svc-dash-buffer-name))
      (when-let* ((buffer (get-buffer name)))
        (kill-buffer buffer)))))

(provide 'hngh-mc)
;;; hngh-mc.el ends here
