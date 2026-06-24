;;;; core/main.lisp — Hngh entry point
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh)

(defparameter *version* "0.0.1"
  "Current Hngh version string.")

(defparameter *hngh-home* (merge-pathnames ".hngh/" (user-homedir-pathname))
  "Path to the Hngh state directory (~/.hngh/).")

(defparameter *running* nil
  "Whether Hngh is currently running.")

(defparameter *state-tree-dirs*
  '("config/"
    "config/plugins/"
    "state/"
    "state/plugin-observations/"
    "journal/"
    "journal/events/"
    "journal/hnghbeats/"
    "knowledge-base/"
    "knowledge-base/articles/"
    "knowledge-base/decisions/"
    "knowledge-base/learned-patterns/"
     "knowledge-base/learned-patterns/threats/"
     "knowledge-base/learned-patterns/optimizations/"
     "knowledge-base/learned-patterns/workflows/"
      "config/plugins/backup-manager/"
      "state/plugins/backup-manager/"
      "config/plugins/llm-threat/"
      "state/plugins/llm-threat/"
      "plugins/"
     "agents/"
     "secrets/")
  "Subdirectories to create in the Hngh state tree on first start.")

(defun version ()
  "Return the Hngh version string."
  *version*)

(defun init-state-tree (hngh-home)
  "Create the Hngh state directory tree under HNGH-HOME.
Idempotent — does nothing for directories that already exist."
  (hngh.core:log-debug "Initializing state tree at ~A" (namestring hngh-home))
  (dolist (dir *state-tree-dirs*)
    (let ((full-path (merge-pathnames dir hngh-home)))
      (ensure-directories-exist full-path)))
  ;; Set restrictive permissions on secrets/ (0700)
  #+sbcl
  (let ((secrets-dir (merge-pathnames "secrets/" hngh-home)))
    (sb-ext:run-program "chmod"
                        (list "700" (namestring secrets-dir))
                        :search t :wait t :output nil))
  (hngh.core:log-debug "State tree initialized"))

(defun install-signal-handlers ()
  "Install SIGTERM and SIGINT handlers for graceful shutdown."
  #+sbcl
  (progn
    (sb-sys:enable-interrupt sb-unix:sigterm
                             (lambda (signal code ctx)
                               (declare (ignore signal code ctx))
                               (hngh.core:log-info "Received SIGTERM — shutting down")
                               (stop)
                               (uiop:quit 0)))
    (sb-sys:enable-interrupt sb-unix:sigint
                             (lambda (signal code ctx)
                               (declare (ignore signal code ctx))
                               (hngh.core:log-info "Received SIGINT — shutting down")
                               (stop)
                               (uiop:quit 0))))
  #-sbcl
  (hngh.core:log-warn "Signal handling not supported on this Lisp implementation"))

(defun start (&key (hngh-home *hngh-home*) (log-level nil log-level-p))
  "Start the Hngh system.

HNGH-HOME: path to the Hngh state directory (default: ~/.hngh/).
LOG-LEVEL: one of :debug, :info, :warn, :error. If not specified, uses config.

Initialization sequence:
  1. Set HNGH-HOME
  2. Initialize state directory tree
  3. Load configuration
  4. Set log level (from arg, config, or default :info)
  5. Install signal handlers
  6. Start Event Bus
  7. Start State Store
  8. Start Supervisor
  9. Start Scheduler
  10. Load first-party plugins
  11. Set *running* flag
  12. Log startup complete

If any step fails, already-started components are shut down in reverse order."
  (setf *hngh-home* hngh-home)
  (init-state-tree hngh-home)
  (hngh.core.config:load-config :hngh-home hngh-home)
  (let ((effective-level (cond
                            (log-level-p log-level)
                            (t (hngh.core.config:config-get :log-level :info)))))
    (hngh.core:set-log-level effective-level))
  (hngh.core:log-info "Hngh v~A starting..." *version*)
  (hngh.core:log-info "State directory: ~A" (namestring hngh-home))
  (hngh.core:log-info "Log level: ~A" hngh.core:*log-level*)
  (install-signal-handlers)
  (unwind-protect
       (progn
         (hngh.core.event-bus:init :hngh-home hngh-home)
         (hngh.core.state-store:init :hngh-home hngh-home)
         (hngh.core.supervisor:init)
         (hngh.core.scheduler:init)
         (hngh.core.threat-detection:init :hngh-home hngh-home)
         (hngh.core.resource-manager:init :hngh-home hngh-home)
         (hngh.plugins.dbus-bridge:init :monitor-systemd nil)
         (hngh.plugins.dashboard-tui:init :headless t)
          (hngh.plugins.package-manager:init)
          (hngh.plugins.system-config:init)
          (hngh.plugins.secrets-manager:init)
          (hngh.plugins.backup-manager:init)
           (hngh.plugins.model-runtime:init)
            (hngh.plugins.ai-tool-hub:init)
            (hngh.plugins.ai-orchestrator:init)
           (hngh.plugins.hnghbeats:init)
           (hngh.plugins.knowledge-base:initialize-knowledge-base :hngh-home hngh-home)
           (hngh.plugins.llm-threat-detector:init :hngh-home hngh-home)
           (setf *running* t)
           (hngh.core:log-info "Hngh started")
           t)
     (unless *running*
       (hngh.core:log-error "Startup failed — rolling back")
       (ignore-errors (hngh.plugins.llm-threat-detector:shutdown))
       (ignore-errors (hngh.plugins.knowledge-base:shutdown-knowledge-base))
       (ignore-errors (hngh.plugins.hnghbeats:shutdown))
       (ignore-errors (hngh.plugins.ai-orchestrator:shutdown))
       (ignore-errors (hngh.plugins.ai-tool-hub:shutdown))
       (ignore-errors (hngh.plugins.model-runtime:shutdown))
       (ignore-errors (hngh.plugins.backup-manager:shutdown))
       (ignore-errors (hngh.plugins.secrets-manager:shutdown))
       (ignore-errors (hngh.plugins.system-config:shutdown))
      (ignore-errors (hngh.plugins.package-manager:shutdown))
      (ignore-errors (hngh.plugins.dashboard-tui:shutdown))
      (ignore-errors (hngh.plugins.dbus-bridge:shutdown))
      (ignore-errors (hngh.core.resource-manager:shutdown))
      (ignore-errors (hngh.core.threat-detection:shutdown))
      (ignore-errors (hngh.core.scheduler:shutdown))
      (ignore-errors (hngh.core.supervisor:shutdown))
      (ignore-errors (hngh.core.state-store:shutdown))
      (ignore-errors (hngh.core.event-bus:shutdown)))))

(defun stop ()
  "Stop the Hngh system.

Shutdown sequence (reverse of startup):
  1. Unload plugins
  2. Stop Scheduler
  3. Stop Supervisor
  4. Flush State Store (releases locks)
  5. Stop Event Bus
  6. Mark as not running"
  (unless *running*
    (hngh.core:log-warn "Hngh is not running")
    (return-from stop nil))
  (hngh.core:log-info "Stopping Hngh...")
  ;; Stop first-party plugins (reverse order)
  (ignore-errors (hngh.plugins.llm-threat-detector:shutdown))
  (ignore-errors (hngh.plugins.knowledge-base:shutdown-knowledge-base))
  (ignore-errors (hngh.plugins.hnghbeats:shutdown))
  (hngh.plugins.ai-orchestrator:shutdown)
  (hngh.plugins.ai-tool-hub:shutdown)
  (hngh.plugins.model-runtime:shutdown)
  (hngh.plugins.backup-manager:shutdown)
  (hngh.plugins.secrets-manager:shutdown)
  (hngh.plugins.system-config:shutdown)
  (hngh.plugins.package-manager:shutdown)
  (hngh.plugins.dashboard-tui:shutdown)
  (hngh.plugins.dbus-bridge:shutdown)
  ;; Stop core components
  (hngh.core.threat-detection:shutdown)
  (hngh.core.resource-manager:shutdown)
  ;; Stop Scheduler
  (hngh.core.scheduler:shutdown)
  ;; Stop Supervisor
  (hngh.core.supervisor:shutdown)
  ;; Flush State Store (releases locks)
  (hngh.core.state-store:shutdown)
  ;; Stop Event Bus
  (hngh.core.event-bus:shutdown)
  (setf *running* nil)
  (hngh.core:log-info "Hngh stopped")
  t)

(defun main ()
  "Entry point for the Hngh binary.

Parses command-line arguments, starts the system, and enters the main loop.
Used when building a standalone executable via `make build`."
  (let ((args (uiop:command-line-arguments)))
    (cond
      ((member "--version" args :test #'string=)
       (format t "hngh ~A~%" *version*)
       (uiop:quit 0))
      ((member "--help" args :test #'string=)
       (format t "Usage: hngh [options]~%")
       (format t "~%")
       (format t "Options:~%")
       (format t "  --version          Print version and exit~%")
       (format t "  --help             Print this help and exit~%")
       (format t "  --hngh-home PATH   Set state directory (default: ~~/.hngh/)~%")
       (format t "  --log-level LEVEL  Set log level: debug, info, warn, error~%")
       (uiop:quit 0))
      (t
       ;; Parse options
       (let ((home (parse-option args "--hngh-home" #'identity))
             (level-str (parse-option args "--log-level" #'identity)))
           (let ((hngh-home (if home
                               (merge-pathnames (concatenate 'string home "/"))
                               *hngh-home*))
               (log-level (when level-str
                           (keyword-from-string level-str))))
           (if log-level
               (start :hngh-home hngh-home :log-level log-level)
               (start :hngh-home hngh-home))
            ;; No event loop yet — start and stop immediately (stub)
            (hngh.core:log-info "No event loop — exiting after startup")
           (stop)
           (uiop:quit 0)))))))

(defun parse-option (args flag converter)
  "Parse a --flag VALUE option from ARGS. Returns (funcall CONVERTER value) or NIL."
  (let ((idx (position flag args :test #'string=)))
    (when (and idx (< (1+ idx) (length args)))
      (funcall converter (nth (1+ idx) args)))))

(defun keyword-from-string (str)
  "Convert a string like \"debug\" to a keyword like :debug."
  (intern (string-upcase str) :keyword))
