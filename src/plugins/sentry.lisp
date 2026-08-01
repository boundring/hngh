;;;; plugins/sentry.lisp — Sentry (M-sentry): procedural safeguards layer
;;;;
;;;; Tier-0 watchers: cheap, always-on, NO model calls in the hot path
;;;; (llmtrim's shape). secret-guard scans text for exfiltratable secrets;
;;;; context-watch reads the hermes agent.log and reports context pressure.
;;;; Both fail closed and redact evidence. See .omc/plans/sentry-safeguards.md.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.sentry)

(defvar *running* nil)

;;; --- Secret patterns (procedural, no model) -------------------------------
;;; Each entry: (name . regex). Evidence reports the NAME only, never the
;;; matched value (redaction is the whole point).
(defparameter *secret-patterns*
  '(("openrouter-key" . "sk-or-[A-Za-z0-9]{16,}")
    ("generic-api-key" . "sk-[A-Za-z0-9]{20,}")
    ("private-key-block" . "-----BEGIN [A-Z ]*PRIVATE KEY-----")
    ("github-pat" . "ghp_[A-Za-z0-9]{36}")
    ("github-oauth" . "gho_[A-Za-z0-9]{36}")
    ("slack-token" . "xox[baprs]-[A-Za-z0-9-]+")
    ("google-api-key" . "AIza[0-9A-Za-z_-]{35}")
    ("aws-access-key" . "AKIA[0-9A-Z]{16}")
    ("bearer-token" . "Bearer [A-Za-z0-9._~+/-]{20,}"))
  "Alist of (pattern-name . regex) for secret detection.")

(defun scan-secrets (text)
  "Scan TEXT for secret patterns. Returns a list of pattern-NAME strings
that matched (never the matched values). Returns NIL when clean.
Fails closed: on any scanner error, returns (\"scanner-error\")."
  (handler-case
      (let ((hits '()))
        (dolist (entry *secret-patterns*)
          (when (ppcre:scan (cdr entry) text)
            (push (car entry) hits)))
        (nreverse hits))
    (error () (list "scanner-error"))))

(defun guard-text (text &key (requester "sentry"))
  "Guard TEXT against secret exfiltration. Returns (values T NIL) when clean,
(values NIL hits) when secrets are found. Publishes threat.flag on detection.
Evidence is redacted: pattern names + text length, never content."
  (let ((hits (scan-secrets text)))
    (if hits
        (progn
          (when hngh.core.event-bus:*event-bus*
            (hngh.core.event-bus:publish
             "threat.flag"
             (list :plugin requester :severity :high
                   :evidence (format nil "secret-guard blocked ~D pattern(s): ~A (text ~D chars, content redacted)"
                                     (length hits) hits (length text))
                   :layer :L3 :timestamp (get-universal-time))
             :source 'sentry))
          (values nil hits))
        (values t nil))))

;;; --- Context watch (from the tool-channel diagnosis) ----------------------
;;; Reads the hermes agent.log's latest in=<N> and reports pressure as
;;; :green/:yellow/:red against the model ceiling. Read-only; never mutates
;;; the session (human decides to compact/branch).
(defvar *context-ceiling* 256000
  "Model context ceiling (tokens). Yellow at 70%, red at 85%.")

(defvar *agent-log-path*
  (merge-pathnames ".hermes/logs/agent.log" (user-homedir-pathname)))

(defun latest-context-size (&optional (path *agent-log-path*))
  "Return the most recent in=<N> token count from the agent log, or NIL.
Scans the tail of the log for 'in=<digits>'."
  (handler-case
      (when (probe-file path)
        (with-open-file (s path)
          (let ((file-length (file-length s))
                (latest nil))
            ;; read the last ~64KB to stay cheap on a 4.6MB log
            (file-position s (max 0 (- file-length 65536)))
            (loop for line = (read-line s nil nil)
                  while line
                  do (let ((pos (search "in=" line)))
                       (when pos
                         (let* ((start (+ pos 3))
                                (end (or (position-if-not #'digit-char-p line :start start)
                                         (length line)))
                                (n (parse-integer line :start start :end end :junk-allowed t)))
                           (when n (setf latest n))))))
            latest)))
    (error () nil)))

(defun context-pressure (&optional (path *agent-log-path*))
  "Return (values status size) where status is :green/:yellow/:red/:unknown."
  (let ((n (latest-context-size path)))
    (if (null n)
        (values :unknown nil)
        (values (cond ((>= n (* 0.85 *context-ceiling*)) :red)
                      ((>= n (* 0.70 *context-ceiling*)) :yellow)
                      (t :green))
                n))))

;;; --- Standard plugin surface ----------------------------------------------
(defun init (&key (hngh-home hngh:*hngh-home*))
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Sentry initialized (secret patterns: ~D, context ceiling: ~D)"
                      (length *secret-patterns*) *context-ceiling*)
  t)

(defun shutdown ()
  (setf *running* nil)
  (hngh.core:log-info "Sentry shut down"))

(defun running-p () *running*)

(defun status ()
  (multiple-value-bind (pressure size) (context-pressure)
    (list :running *running*
          :secret-patterns (length *secret-patterns*)
          :context-pressure pressure
          :context-size size)))
