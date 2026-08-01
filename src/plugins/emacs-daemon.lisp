;;;; plugins/emacs-daemon.lisp — Hngh Emacs Daemon lifecycle (M6.3, MC-2 wave 2)
;;;;
;;;; Start/stop/health for the emacs daemon server. The daemon outlives hngh
;;;; (like the tmux session outlives mission-control): init never auto-starts
;;;; it and shutdown never stops it. Safety property: emacsclient --eval
;;;; (including (kill-emacs)) reaches only the daemon's server socket, so a
;;;; non-daemon GUI emacs is never touched.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.emacs-daemon)

(defvar *running* nil)

(defun %emacsclient-run (args)
  "Run emacsclient with ARGS (list of strings). Returns (values output exit-code stderr)."
  (handler-case
      (let* ((out-str (make-string-output-stream))
             (err-str (make-string-output-stream))
             (proc (sb-ext:run-program "emacsclient" args
                                       :output out-str :error err-str
                                       :search t :wait t)))
        (values (get-output-stream-string out-str)
                (sb-ext:process-exit-code proc)
                (get-output-stream-string err-str)))
    (error (c)
      (values (princ-to-string c) 127 ""))))

(defun %wait-with-timeout (proc timeout-seconds)
  "Wait up to TIMEOUT-SECONDS for PROC to exit. Returns the exit code, or NIL
on timeout (killing PROC) or when PROC was signaled."
  (let ((deadline (+ (get-internal-real-time)
                     (* timeout-seconds internal-time-units-per-second))))
    (loop
      (case (sb-ext:process-status proc)
        (:exited (return (sb-ext:process-exit-code proc)))
        (:signaled (return nil)))
      (when (> (get-internal-real-time) deadline)
        (ignore-errors (sb-ext:process-kill proc 9))
        (ignore-errors (sb-ext:process-wait proc))
        (return nil))
      (sleep 0.05))))

(defun daemon-alive-p ()
  "T when `emacsclient --eval t` exits 0 within ~5 seconds."
  (handler-case
      (let ((proc (sb-ext:run-program "emacsclient" '("--eval" "t")
                                      :search t :wait nil :output nil :error nil)))
        (let ((code (%wait-with-timeout proc 5)))
          (and code (zerop code))))
    (error () nil)))

(defun start-daemon (&key (load-files nil))
  "Start the emacs daemon; with LOAD-FILES, pass each file as --load FILE.
Idempotent: when a daemon already answers, log and return T. Polls
daemon-alive-p up to ~15s at 1s intervals. Returns T/NIL; never errors."
  (when (daemon-alive-p)
    (hngh.core:log-info "Emacs daemon already running (pid ~A); start is idempotent"
                        (getf (health) :pid))
    (return-from start-daemon t))
  (handler-case
      (progn
        (sb-ext:run-program "emacs"
                            (append '("--daemon")
                                    (loop for f in load-files
                                          append (list "--load" (namestring (pathname f)))))
                            :search t :wait t :output nil :error nil)
        (if (loop repeat 15
                  thereis (daemon-alive-p)
                  do (sleep 1))
            (progn
              (hngh.core:log-info "Emacs daemon started (pid ~A)" (getf (health) :pid))
              t)
            (progn
              (hngh.core:log-warn "Emacs daemon did not become ready within ~15s")
              nil)))
    (error (c)
      (hngh.core:log-error "Emacs daemon start failed: ~A" c)
      nil)))

(defun stop-daemon ()
  "Ask the emacs daemon to exit via `emacsclient --eval \"(kill-emacs)\"`.
Acts only when daemon-alive-p; returns NIL otherwise. Never touches a
non-daemon GUI emacs — kill-emacs via emacsclient reaches only the daemon
server socket."
  (when (daemon-alive-p)
    (multiple-value-bind (out code err) (%emacsclient-run '("--eval" "(kill-emacs)"))
      (declare (ignore out))
      (if (zerop code)
          (progn
            (hngh.core:log-info "Emacs daemon stopping (kill-emacs sent)")
            t)
          (progn
            (hngh.core:log-warn "kill-emacs via emacsclient exited ~A: ~A" code err)
            nil)))))

(defun health ()
  "Return a plist :alive :pid. :pid is parsed from `emacsclient --eval
\"(emacs-pid)\"`; NIL on any failure."
  (let ((alive (daemon-alive-p)))
    (list :alive alive
          :pid (when alive
                 (multiple-value-bind (out code) (%emacsclient-run '("--eval" "(emacs-pid)"))
                   (when (zerop code)
                     (handler-case
                         (parse-integer
                          (string-trim '(#\Space #\Tab #\Newline #\Return) out))
                       (error () nil))))))))

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the emacs-daemon plugin. Does NOT auto-start the daemon —
starting it is an explicit user/other-plugin action (policy)."
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Emacs daemon plugin initialized (daemon alive: ~A; start is policy-explicit)"
                      (daemon-alive-p))
  t)

(defun shutdown ()
  "Shut down the emacs-daemon plugin (bookkeeping only). MUST NOT stop the
emacs daemon — the daemon outlives hngh, like the tmux session outlives
mission-control."
  (setf *running* nil)
  (hngh.core:log-info "Emacs daemon plugin shut down (daemon left running)"))

(defun running-p ()
  "Return T if the emacs-daemon plugin is active."
  *running*)

(defun status ()
  "Return a plist with emacs-daemon plugin status: :running :daemon-alive :pid."
  (let ((h (health)))
    (list :running *running*
          :daemon-alive (getf h :alive)
          :pid (getf h :pid))))
