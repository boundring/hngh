;;;; src/plugins/signals.lisp — Typed agent↔agent control channel (W1.5)
;;;;
;;;; Design: docs/design/social-senses.md §3. Signals are a fixed-code,
;;;; ~no-token semantic ACK/NAK/control layer over the event bus — cheaper
;;;; than a message bean because there is no free-form text, just a typed
;;;; code + a context-ref. Control kinds map onto existing queue transitions
;;;; (retry/block/permit/pause/done) as deterministic state changes; there is
;;;; no LLM and no anthropomorphizing — these are typed behavioral codes.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.signals)

(defvar *running* nil
  "Whether the signals plugin is active.")

(defparameter *signal-kinds*
  '(:ask :affirm :negate :wink :double-take
    :block :permit :retry :pause :done)
  "The fixed signal vocabulary (social-senses §3).")

(defparameter *signal-topic* "agent.signal"
  "Event-bus topic for signal publication.")

(defun init ()
  "Initialize the signals plugin."
  (setf *running* t)
  (hngh.core:log-info "Signals initialized")
  t)

(defun shutdown ()
  "Shut down the signals plugin."
  (setf *running* nil)
  t)

(defun running-p ()
  "Return T when the signals plugin is active."
  *running*)

(defun status ()
  "Return a one-line status summary."
  (if *running*
      "signals: channel ready"
      "signals: inactive"))

;;; --- Signal type ----------------------------------------------------------

(defun valid-signal-kind-p (kind)
  "Return T when KIND is a member of the fixed signal vocabulary."
  (member kind *signal-kinds*))

(defun %check-kind (kind)
  "Signal an error for an invalid KIND (fail closed, never emit)."
  (unless (valid-signal-kind-p kind)
    (error "Invalid signal kind ~S — must be one of ~S" kind *signal-kinds*)))

(defun plant-signal (recipient kind &key (context-ref nil) (source nil))
  "Plant a SIGNAL to RECIPIENT with KIND (fixed enum) and optional
CONTEXT-REF (a bean/task/thread id). Invalid KIND fails closed. Publishes on
the event bus as agent.signal (instant) and journals to the durable signal
inbox (append-only) so receive-signals works across restarts."
  (%check-kind kind)
  (let* ((now (get-universal-time))
         (entry (list :id (length (%read-inbox)) :recipient recipient
                      :sender source :kind kind :context-ref context-ref
                      :at now)))
    ;; Durable journal first (so a crash mid-publish still logs the signal).
    (%write-inbox (append (%read-inbox) (list entry)))
    ;; Then instant delivery on the bus.
    (hngh.core.event-bus:publish *signal-topic* entry
                                 :source (or source 'signals))))

;;; --- Receive ------------------------------------------------------------------

(defparameter *signal-inbox-path* "signals/inbox.lisp"
  "State-store relative path of the signal inbox (per-recipient journals).")

(defun %read-inbox ()
  "Read the signal inbox, or '() when absent/corrupt."
  (handler-case (or (hngh.core.state-store:read-state *signal-inbox-path*) '())
    (error () '())))

(defun %write-inbox (inbox)
  "Persist the signal inbox."
  (hngh.core.state-store:write-state *signal-inbox-path* inbox))

(defun receive-signals (recipient &key (since nil))
  "Return the list of signals addressed to RECIPIENT, optionally only those
at/after universal-time SINCE. Each signal entry:
  (:id <n> :recipient <sym> :sender <sym> :kind <kw> :context-ref <id> :at <utime>)"
  (let ((inbox (%read-inbox)))
    (remove-if-not
     (lambda (e)
       (and (string= (symbol-name (getf e :recipient))
                     (symbol-name recipient))
            (or (null since) (>= (getf e :at) since))))
     inbox)))

;;; --- Control-kind mapping (thin adapter, exported-transitions only) --------

(defun apply-signal (entry)
  "Apply a CONTROL signal ENTRY as a deterministic transition where an
EXPORTED queue transition exists. Currently maps only :PAUSE (via
pause-dispatch). Task-granular control kinds (:retry/:block/:permit/:done)
are recorded as follow-on work pending export of block-task/release-task/
complete-task from ai-orchestrator — we refuse to reach into unexported
internals (keeps the plugin boundary honest). Returns T on applied action,
NIL for informational kinds or kinds with no exported mapping."
  (ecase (getf entry :kind)
    ((:ask :affirm :negate :wink :double-take :retry :block :permit :done)
     ;; Informational, or task-granular with no exported transition yet.
     nil)
    (:pause
     (hngh.plugins.ai-orchestrator:pause-dispatch)
     t)))
