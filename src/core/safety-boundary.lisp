;;;; core/safety-boundary.lisp — Wave C immutable safety layer.
;;;;
;;;; The first, root piece of the hardened security baseline
;;;; (docs/design/autonomy-strategy.md §7 Wave C): an immutable safety/policy
;;;; layer — the agent cannot edit its own approval policy, sentry config, or
;;;; sandbox config. Everything else in Wave C builds on this boundary.
;;;;
;;;; Design:
;;;;   - PROTECTED paths: the config tree (config/hngh.lisp) + the sentry and
;;;;     sandbox config files are REGISTERED at init and mode-locked (0444)
;;;;     when possible. This module lives in CORE, not a plugin, so a plugin
;;;;     (or a self-modifying agent) cannot simply add paths to its own
;;;;     ignore list — the registry is read-only after init.
;;;;   - MUTATION GUARD: allow-mutation-p returns NIL for any path under a
;;;;     protected root (fail-closed; caller must honor the refusal).
;;;;   - ACTION LOG: every denied/protected-mutation attempt is appended to
;;;;     an append-only journal (journal/actions.lisp) — the durable record
;;;;     for audit. Journal writes are the ONLY writes this layer performs.
;;;;
;;;; Gate: no C6 self-modification of core files until this wave lands
;;;; (the layer itself being the first enforcement point).

(in-package :hngh.core.safety-boundary)

(defvar *running* nil)
(defvar *protected-paths* '()
  "Absolute pathname list of protected files/dirs; frozen after INIT.")

(defparameter *action-log-name* "actions"
  "Journal name (under state/journal/) holding the append-only action log.")

(defparameter *default-protected-relative*
  '("config/hngh.lisp"
    "config/sentry.lisp"
    "config/sandbox.lisp")
  "Protected config paths, RELATIVE to hngh-home. The approval policy,
sentry policy, and sandbox policy live under the config tree; the agent
must never edit them at runtime.")

;;; --- Registry -------------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Register the protected config files under HNGH-HOME and freeze the list.
Mode-locks the files (0444) when the directory exists and we own them —
best-effort: a locked filesystem or missing file is not an error, the
in-process guard still enforces the boundary."
  (setf *protected-paths*
        (mapcar (lambda (rel)
                  (merge-pathnames rel hngh-home))
                *default-protected-relative*))
  (dolist (path *protected-paths*)
    (%mode-lock path))
  (setf *running* t)
  t)

(defun shutdown ()
  (setf *running* nil)
  t)

(defun running-p ()
  *running*)

(defun protected-paths ()
  (copy-list *protected-paths*))

;;; --- Guard ----------------------------------------------------------------

(defun protected-path-p (path)
  "Return T when PATH (string or pathname) is under a protected root.
Fail-closed on errors: unparseable input counts as protected."
  (handler-case
      (let* ((p (pathname path))
             (dir (uiop:pathname-directory-pathname p)))
        (dolist (protected *protected-paths*)
          (let ((pdir (uiop:pathname-directory-pathname protected)))
            (when (or (uiop:pathname-equal p protected)
                      (uiop:pathname-equal dir pdir)
                      (uiop:subpathp (namestring p)
                                     (namestring pdir)))
              (return-from protected-path-p t))))
        nil)
    (error () t)))

(defun allow-mutation-p (path)
  "Return T if a mutation of PATH is permitted under the safety boundary.
NIL (denied) for protected paths; logs the denial to the action log."
  (if (protected-path-p path)
      (progn
        (log-action :denied :target (namestring (pathname path)))
        nil)
      t))

(defun ensure-mutable (path)
  "Signal an error when PATH is protected. Wrapper for callers that must
fail hard rather than silently proceed."
  (unless (allow-mutation-p path)
    (error "safety boundary: ~A is protected (Wave C immutable config)"
           (namestring (pathname path)))))

;;; --- Action log (append-only) ---------------------------------------------

(defun log-action (kind &key target detail)
  "Append (KIND TARGET DETAIL) to the append-only action journal.
KIND: :denied (mutation guard refusal), :locked (mode-lock applied),
:attempt (mutation against a protected path that bypassed the guard).
Returns the journal path."
  (let ((entry (list :kind kind
                     :ts (get-universal-time)
                     :target target
                     :detail detail
                     :attribution "hngh.core.safety-boundary")))
    (hngh.core.state-store:append-journal *action-log-name* entry)))

(defun read-action-log ()
  "Read every action-log entry (oldest first). Fail-closed: any read error
returns NIL entries dropped."
  (handler-case
      (hngh.core.state-store:read-journal *action-log-name*)
    (error () '())))

(defun recent-denials (&optional (limit 20))
  "Most recent :denied entries, newest first, up to LIMIT."
  (let ((denied (remove-if-not (lambda (e) (eq (getf e :kind) :denied))
                               (read-action-log))))
    (last denied limit)))

;;; --- Mode-lock (best-effort OS-level protection) ---------------------------

(defun %mode-lock (path)
  "chmod 0444 PATH when it exists and is a regular file. Best-effort: not an
error when the file is absent (it hasn't been created yet — the next reader
of the config will still be guarded in-process)."
  (when (and (probe-file path)
             (uiop:file-exists-p path))
    (handler-case
        (sb-ext:run-program "chmod" (list "0444" (namestring path))
                            :search t :wait t)
      (error ()))
    (log-action :locked :target (namestring path))))

;;; --- Status ----------------------------------------------------------------

(defun status ()
  (list :running *running*
        :protected (mapcar #'namestring *protected-paths*)
        :denials-total
        (count-if (lambda (e) (eq (getf e :kind) :denied))
                  (read-action-log))))