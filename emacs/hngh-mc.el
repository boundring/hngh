;;; hngh-mc.el --- Mission-control dashboard for hngh -*- lexical-binding: t -*-

;; MC-2 wave 1 - produced by opencode (kimi-k3, attended), 2026-07-31.
;; MC-2 wave 2 WP-A (task-queue panel) - opencode (kimi-k3), 2026-07-31.
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

(defvar hngh-mc-opencode-buffer-name "*opencode*"
  "Name of the opencode session-log panel buffer.")

(defvar hngh-mc-opencode-log
  (expand-file-name "~/.local/share/opencode/log/opencode.log")
  "Path to the opencode session log tailed by the opencode panel.")

(defvar hngh-mc-svc-dash-buffer-name "*svc-dash*"
  "Name of the svc-dash terminal buffer.")

(defvar hngh-mc-events-directory (expand-file-name "~/.hngh/journal/events/")
  "Directory holding hngh event journal files (YYYY-MM-DD.lisp).")

(defvar hngh-mc-svc-dash-project (expand-file-name "~/Projects/etc/svc-dash")
  "Project directory handed to uv for the svc-dash TUI.")

(defvar hngh-mc-queue-buffer-name "*hngh-queue*"
  "Name of the task-queue panel buffer.")

(defvar hngh-mc-task-buffer-name "*hngh-task*"
  "Name of the task detail buffer.")

(defvar hngh-mc-queue-file (expand-file-name "~/.hngh/tasks/queue.lisp")
  "Path to the hngh task queue file; owned by hngh, read-only here.")

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

(defvar hngh-mc-queue-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "d") #'hngh-mc-task-ack)
    (define-key map (kbd "D") #'hngh-mc-task-ack-clear)
    (define-key map (kbd "RET") #'hngh-mc-task-detail)
    map)
  "Keymap for `hngh-mc-queue-mode'.")

(define-derived-mode hngh-mc-queue-mode special-mode "hngh-queue"
  "Major mode for the task-queue panel.")

(defvar hngh-mc--queue-acked nil
  "Buffer-local list of task ids acknowledged (hidden) in the queue panel.")

(defvar hngh-mc--queue-error nil
  "Message of the last queue parse failure, nil when the last read succeeded.")

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

(defun hngh-mc--opencode-buffer ()
  "Return the opencode panel buffer tailing the opencode session log."
  (if (not (file-readable-p hngh-mc-opencode-log))
      (let ((buffer (get-buffer-create hngh-mc-opencode-buffer-name)))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert "No opencode log at " hngh-mc-opencode-log "\n"))
          (special-mode))
        buffer)
    (let ((buffer (find-file-noselect hngh-mc-opencode-log)))
      (with-current-buffer buffer
        (unless (string= (buffer-name) hngh-mc-opencode-buffer-name)
          (rename-buffer hngh-mc-opencode-buffer-name))
        (read-only-mode 1)
        (auto-revert-tail-mode 1)
        (goto-char (point-max)))
      buffer)))


(defun hngh-mc--queue-epoch (universal-time)
  "Convert hngh (Common Lisp) UNIVERSAL-TIME to seconds since the epoch."
  (- universal-time 2208988800))

(defun hngh-mc--queue-read ()
  "Return the list of task plists from `hngh-mc-queue-file'.
Return nil when the file is missing or empty; on parse failure record
`hngh-mc--queue-error' and return nil.  Never signals."
  (setq hngh-mc--queue-error nil)
  (when (file-exists-p hngh-mc-queue-file)
    (condition-case err
        (with-temp-buffer
          (insert-file-contents hngh-mc-queue-file)
          (goto-char (point-min))
          (if (zerop (buffer-size))
              nil
            (let ((data (read (current-buffer))))
              (if (listp data)
                  data
                (setq hngh-mc--queue-error "queue file is not a list")
                nil))))
      (error
       (setq hngh-mc--queue-error (error-message-string err))
       nil))))

(defun hngh-mc--queue-age (task)
  "Return a compact age string for TASK's :submitted-at, or \"?\"."
  (let ((submitted (plist-get task :submitted-at)))
    (if (not (integerp submitted))
        "?"
      (let ((delta (max 0 (- (float-time) (hngh-mc--queue-epoch submitted)))))
        (cond ((< delta 60) (format "%ds" (floor delta)))
              ((< delta 3600) (format "%dm" (floor delta 60)))
              ((< delta 86400) (format "%dh" (floor delta 3600)))
              (t (format "%dd" (floor delta 86400))))))))

(defun hngh-mc--queue-dim-p (task)
  "Return non-nil when TASK is done/failed and submitted over 10 minutes ago."
  (and (memq (plist-get task :status) '(:done :failed))
       (integerp (plist-get task :submitted-at))
       (> (- (float-time) (hngh-mc--queue-epoch (plist-get task :submitted-at)))
          600)))

(defun hngh-mc--queue-done-today (tasks)
  "Return the number of TASKS with status :done finished today."
  (let ((today (format-time-string "%F"))
        (count 0))
    (dolist (task tasks count)
      (when (and (eq (plist-get task :status) :done)
                 (integerp (plist-get task :finished-at))
                 (equal today
                        (format-time-string
                         "%F" (hngh-mc--queue-epoch
                               (plist-get task :finished-at)))))
        (setq count (1+ count))))))

(defun hngh-mc--queue-insert (tasks)
  "Insert the queue header and one row per task in TASKS.
Acknowledged tasks (see `hngh-mc-task-ack') are skipped; done/failed
tasks older than 10 minutes are de-emphasized with the shadow face."
  (insert (propertize
           (format "hngh queue — %d done today"
                   (hngh-mc--queue-done-today tasks))
           'face 'bold)
          "\n\n")
  (insert (format "%3s  %-11s %-5s %s" "ID" "STATUS" "AGE" "TASK") "\n")
  (let* ((window (get-buffer-window (current-buffer)))
         (width (if (window-live-p window) (window-width window) 80))
         (task-width (max 10 (- width 24))))
    (dolist (task tasks)
      (unless (memq (plist-get task :id) hngh-mc--queue-acked)
        (let ((start (point))
              (text (truncate-string-to-width
                     (string-trim
                      (string-replace
                       "\n" " " (or (plist-get task :task) "")))
                     task-width)))
          (insert (format "%3s  %-11s %-5s %s\n"
                          (or (plist-get task :id) "?")
                          (or (plist-get task :status) "?")
                          (hngh-mc--queue-age task)
                          text))
          (put-text-property start (point) 'hngh-mc-task task)
          (when (hngh-mc--queue-dim-p task)
            (put-text-property start (point) 'face 'shadow)))))))

(defun hngh-mc--revert-queue (&optional _ignore-auto _noconfirm)
  "Re-read the task queue file and replace the queue panel contents."
  (let ((inhibit-read-only t)
        (position (point)))
    (erase-buffer)
    (let ((tasks (hngh-mc--queue-read)))
      (cond
       (hngh-mc--queue-error
        (insert "Queue parse error: " hngh-mc--queue-error "\n"))
       ((null tasks)
        (insert (if (file-exists-p hngh-mc-queue-file)
                    "Task queue is empty.\n"
                  (concat "No task queue file at " hngh-mc-queue-file "\n"))))
       (t (hngh-mc--queue-insert tasks))))
    (goto-char (min position (point-max)))))

(defun hngh-mc--queue-buffer ()
  "Return the queue panel buffer, creating and populating it."
  (let ((buffer (get-buffer-create hngh-mc-queue-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'hngh-mc-queue-mode)
        (hngh-mc-queue-mode))
      (setq-local revert-buffer-function #'hngh-mc--revert-queue)
      (hngh-mc--revert-queue nil t))
    buffer))

(defun hngh-mc--queue-task-at-point ()
  "Return the task plist stored on the current queue row, or nil."
  (get-text-property (line-beginning-position) 'hngh-mc-task))

(defun hngh-mc-task-ack ()
  "Acknowledge the done/failed task on the current row, hiding it this session."
  (interactive)
  (if-let* ((task (hngh-mc--queue-task-at-point)))
      (if (memq (plist-get task :status) '(:done :failed))
          (progn
            (setq-local hngh-mc--queue-acked
                        (cons (plist-get task :id) hngh-mc--queue-acked))
            (hngh-mc--revert-queue nil t))
        (message "Only done/failed tasks can be acknowledged"))
    (message "No task on this row")))

(defun hngh-mc-task-ack-clear ()
  "Clear all task acknowledgements and re-show every task."
  (interactive)
  (setq-local hngh-mc--queue-acked nil)
  (hngh-mc--revert-queue nil t))

(defun hngh-mc-task-detail ()
  "Show the full task plist for the current row in a read-only detail buffer."
  (interactive)
  (if-let* ((task (hngh-mc--queue-task-at-point)))
      (let ((buffer (get-buffer-create hngh-mc-task-buffer-name)))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "hngh task %s — %s\n\n"
                            (plist-get task :id) (plist-get task :status)))
            (pp task (current-buffer)))
          (special-mode)
          (goto-char (point-min)))
        (pop-to-buffer buffer))
    (message "No task on this row")))

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

(defun hngh-mc--layout (status-buffer events-buffer llmtrim-buffer queue-buffer opencode-buffer)
  "Display STATUS-BUFFER left, with EVENTS-BUFFER, LLMTRIM-BUFFER,
OPENCODE-BUFFER and QUEUE-BUFFER stacked in right side windows."
  (hngh-mc--delete-side-windows)
  (delete-other-windows)
  (let ((display-buffer-alist
         `((,(concat "\\`" (regexp-quote hngh-mc-events-buffer-name) "\\'")
            (display-buffer-in-side-window)
            (side . right) (slot . 0) (dedicated . t))
           (,(concat "\\`" (regexp-quote hngh-mc-llmtrim-buffer-name) "\\'")
            (display-buffer-in-side-window)
            (side . right) (slot . 1) (dedicated . t))
           (,(concat "\\`" (regexp-quote hngh-mc-opencode-buffer-name) "\\'")
            (display-buffer-in-side-window)
            (side . right) (slot . 2) (dedicated . t))
           (,(concat "\\`" (regexp-quote hngh-mc-queue-buffer-name) "\\'")
            (display-buffer-in-side-window)
            (side . right) (slot . 3) (dedicated . t)))))
    (display-buffer events-buffer)
    (display-buffer llmtrim-buffer)
    (display-buffer opencode-buffer)
    (display-buffer queue-buffer))
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

(defun hngh-mc--refresh-queue ()
  "Refresh the queue panel if its buffer exists."
  (when-let* ((buffer (get-buffer hngh-mc-queue-buffer-name)))
    (with-current-buffer buffer
      (hngh-mc--revert-queue nil t))))

(defun hngh-mc--live-p ()
  "Return non-nil while any dashboard buffer is live."
  (let ((live nil))
    (dolist (name (list hngh-mc-status-buffer-name
                        hngh-mc-events-buffer-name
                        hngh-mc-llmtrim-buffer-name
                        hngh-mc-opencode-buffer-name
                        hngh-mc-queue-buffer-name
                        hngh-mc-task-buffer-name
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
        (hngh-mc--refresh-queue)
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
                   (hngh-mc--llmtrim-buffer)
                   (hngh-mc--queue-buffer)
                   (hngh-mc--opencode-buffer))
  (hngh-mc--ensure-timers))

;;;###autoload
(defun hngh-mc-refresh ()
  "Refresh every hngh mission-control panel immediately."
  (interactive)
  (hngh-mc--refresh-status)
  (hngh-mc--refresh-llmtrim)
  (hngh-mc--refresh-queue)
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
                        hngh-mc-opencode-buffer-name
                        hngh-mc-queue-buffer-name
                        hngh-mc-task-buffer-name
                        hngh-mc-svc-dash-buffer-name))
      (when-let* ((buffer (get-buffer name)))
        (kill-buffer buffer)))))

(provide 'hngh-mc)
;;; hngh-mc.el ends here
