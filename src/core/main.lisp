;;;; core/main.lisp — Hngh entry point
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh)

(defparameter *version* "0.0.1"
  "Current Hngh version string.")

(defparameter *hngh-home* (merge-pathnames ".hngh/" (user-homedir-pathname))
  "Default path to the Hngh state directory (~/.hngh/).")

(defparameter *running* nil
  "Whether Hngh is currently running. Set by START, cleared by STOP.")

(defun version ()
  "Return the Hngh version string."
  *version*)

(defun start (&key (hngh-home *hngh-home*) (log-level :info))
  "Start the Hngh system.

HNGH-HOME: path to the Hngh state directory (default: ~/.hngh/).
LOG-LEVEL: one of :debug, :info, :warn, :error.

This is a stub — actual initialization will:
  1. Initialize the State Store (create ~/.hngh/ tree)
  2. Start the Event Bus
  3. Start the Supervisor
  4. Start the Scheduler
  5. Load first-party plugins
  6. Enter the main event loop

For now, it logs a startup message and returns."
  (declare (ignore log-level))
  (setf *hngh-home* hngh-home)
  (setf *running* t)
  (hngh.core:log-info "Hngh v~A starting..." *version*)
  (hngh.core:log-info "State directory: ~A" (namestring hngh-home))
  ;; TODO: actual initialization sequence (M0.2–M0.10)
  (hngh.core:log-info "Hngh started (stub — no components loaded yet)")
  t)

(defun stop ()
  "Stop the Hngh system.

Unloads plugins, shuts down scheduler, supervisor, event bus, and exits.

This is a stub — actual shutdown will gracefully deinitialize all components
in reverse order of startup."
  (unless *running*
    (hngh.core:log-warn "Hngh is not running")
    (return-from stop nil))
  (hngh.core:log-info "Stopping Hngh...")
  ;; TODO: actual shutdown sequence (M0.2–M0.10)
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
       (format t "  --version    Print version and exit~%")
       (format t "  --help       Print this help and exit~%")
       (format t "  --hngh-home  Set state directory (default: ~~/.hngh/)~%")
       (uiop:quit 0))
      (t
       ;; Parse --hngh-home if present
       (let ((home-idx (position "--hngh-home" args :test #'string=)))
         (let ((home (if (and home-idx (< (1+ home-idx) (length args)))
                         (merge-pathnames (nth (1+ home-idx) args))
                         *hngh-home*)))
           (start :hngh-home home)
           ;; TODO: enter main event loop (M0.8 Dashboard TUI will own this)
           ;; For now, just log and exit
           (hngh.core:log-info "No event loop yet — exiting after startup (stub)")
           (stop)
           (uiop:quit 0)))))))

;; Logging functions (used by all core components)

(in-package :hngh.core)

(defun log-info (format-string &rest args)
  "Log an informational message."
  (format t "[INFO] ~?~%" format-string args)
  (finish-output))

(defun log-warn (format-string &rest args)
  "Log a warning message."
  (format t "[WARN] ~?~%" format-string args)
  (finish-output))

(defun log-error (format-string &rest args)
  "Log an error message."
  (format t "[ERROR] ~?~%" format-string args)
  (finish-output))

(defun log-debug (format-string &rest args)
  "Log a debug message (only when debug logging is enabled)."
  ;; TODO: respect log level (M0.1 will add a *log-level* variable)
  (format t "[DEBUG] ~?~%" format-string args)
  (finish-output))
