;;;; core/sandbox.lisp — per-task execution sandbox (Wave C item 8).
;;;;
;;;; Wrap agent-generated / external tool execution in a Bubblewrap
;;;; (bwrap) default-deny sandbox: no network, read-only system dirs,
;;;; writable only the explicit task dir. Unprivileged, no SUID, smallest
;;;; trust base (Flatpak's engine) — see docs/research/wave-c-open-source-
;;;; tooling.md item 6 and ADR-043/044.
;;;;
;;;; Fail-closed: missing bwrap => error, NEVER fall back to unsandboxed.
;;;; Callers opt in per tool (tool-hub :sandboxed-p flag); attended agent
;;;; sessions (openode/Hermes ACP) are NOT routed through this — over-
;;;; wrapping the dev loop breaks it (they need network + workspace).

(in-package :hngh.core.sandbox)

(defvar *running* nil)
(defparameter *bwrap* "bwrap"
  "Path to the bubblewrap binary (searched unless absolute).")

(defun init (&key (bwrap *bwrap*))
  "Set BWRAP and report availability. Returns T when bwrap is usable;
NIL when absent (callers fail closed / surface a situation)."
  (setf *bwrap* bwrap)
  (setf *running* t)
  (bwrap-available-p))

(defun shutdown ()
  (setf *running* nil)
  t)

(defun running-p ()
  *running*)

(defun bwrap-available-p ()
  "T when the configured bwrap binary resolves (allows absolute path).
Uses the house `which` probe pattern (see dbus-bridge)."
  (handler-case
      (cond ((and (uiop:absolute-pathname-p *bwrap*)
                  (probe-file *bwrap*))
             t)
            (t
             (let* ((probe (sb-ext:run-program "which" (list *bwrap*)
                                               :output :stream :error :output
                                               :wait t :search t))
                    (out (and probe
                              (let ((stream (sb-ext:process-output probe)))
                                (ignore-errors (read-line stream nil ""))))))
               (and probe
                    (zerop (or (sb-ext:process-exit-code probe) -1))
                    (plusp (length (string-trim '(#\Newline #\Space)
                                                (or out ""))))))))
    (error () nil)))

;;; --- sandbox profile ------------------------------------------------------

(defun %argv (task-dir &key network (deny-write t) (read-only-dirs
                                                    '("/usr" "/bin" "/lib"
                                                      "/lib64" "/etc" "/opt"))
                       (bind-readonly '()))
  "Build the bwrap argv: default-deny file/network. TASK-DIR is bound
writable (or read-only via BIND-READONLY if DENY-WRITE is NIL it stays
writable; you must pass BIND-READONLY explicitly for read-only extras).
NETWORK nil => --unshare-net (default deny). Returns the argv list ending
with the shell command passed separately (callers append cmd+args)."
  (let ((argv (list *bwrap*
                    "--die-with-parent"
                    "--new-session"
                    (if network "--share-net" "--unshare-net")
                    (if deny-write "--unshare-all" "--unshare-user"))))
    (dolist (dir read-only-dirs)
      (when (uiop:directory-exists-p dir)
        (setf argv (append argv (list "--ro-bind" dir dir)))))
    (dolist (dir bind-readonly)
      (when (uiop:directory-exists-p dir)
        (setf argv (append argv (list "--ro-bind" dir dir)))))
    ;; writable task dir (or read-only if caller chose)
    (when (and task-dir (uiop:directory-exists-p task-dir))
      (setf argv (append argv (list "--bind" task-dir task-dir))))
    ;; minimal dev nodes + proc
    (setf argv (append argv (list "--dev" "/dev" "--proc" "/proc")))
    argv))

;;; --- runner ---------------------------------------------------------------

(defun run-sandboxed (command args &key (task-dir nil) (network nil)
                                   (timeout 300))
  "Run COMMAND (string) with ARGS (list of strings) inside a bwrap
default-deny sandbox rooted at TASK-DIR (optional; when NIL only the
read-only system dirs + /dev + /proc are visible and nothing is writable
except via explicit bind). Returns (VALUES OUTPUT EXIT-CODE) where OUTPUT
is captured stdout+stderr; fail-closed: no bwrap => signals an error.
TIMEOUT is a wall-clock cap in seconds (0 = no cap, caller takes care)."
  (unless (bwrap-available-p)
    (error "sandbox: bwrap unavailable — refusing to run unsandboxed (~A)"
           command))
  (let* ((argv (append (%argv task-dir :network network)
                       (list command) args))
         (proc (sb-ext:run-program (first argv) (rest argv)
                                   :output :stream
                                   :error :output
                                   :search t
                                   :wait nil)))
    (unwind-protect
        (handler-case
            (let ((deadline (and (plusp timeout)
                                 (+ (get-universal-time) timeout))))
              (loop
                (when (and deadline (>= (get-universal-time) deadline))
                  (ignore-errors (sb-ext:process-kill proc 9))
                  (return (values (format nil "~%sandbox: ~A timed out after ~D s"
                                          command timeout)
                                  -1)))
                (unless (sb-ext:process-alive-p proc)
                  (return (values (read-stream-to-string
                                   (sb-ext:process-output proc))
                                  (or (sb-ext:process-exit-code proc) -1))))
                (sleep 0.05)))
          (error (c)
            (values (format nil "~%sandbox: ~A failed: ~A" command c) -1)))
      (ignore-errors (sb-ext:process-close proc)))))

(defun read-stream-to-string (stream)
  "Read STREAM to its end as a string (best-effort, NIL-safe)."
  (handler-case
      (let ((out (make-string-output-stream)))
        (loop for c = (read-char stream nil nil)
              while c do (write-char c out))
        (get-output-stream-string out))
    (error () "")))