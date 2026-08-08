;;;; plugins/situation-scoring.lisp — L3 scoring + recovery + action mapping
;;;;
;;;; The "brain" that turns a detected situation datum (from
;;;; situation-detectors.lisp) into a score and an action. Two jobs:
;;;;   (1) SCORE — priority (impact x urgency x spread) + a confidence term;
;;;;   (2) ACTION — decide :none/:steer/:interrupt, reusing the A3 actuator
;;;;       (acp-steer-command) with progressively-lowered thresholds as the
;;;;       same situation class recurs unvalidated (the recovery-stage model).
;;;;
;;;; Load-bearing rules (docs/design/situation-scoring.md §3):
;;;;   - Recovery-STAGE progression, not isolated faults: never escalate on a
;;;;     single tool-level fault with a visible fix attempt.
;;;;   - Weight the ACTING stream (tool results, test passes) over the
;;;;     THINKING stream (asserted self-correction) — recovery is only real
;;;;     when a changed, validated action follows.
;;;;   - Escalate only on: 2 consecutive unvalidated same-class faults, an S3
;;;;     situation (policy/irreversible/instruction-misread), or a long
;;;;     thinking run with zero environment interaction.
;;;;   - FAIL CLOSED: missing impact/urgency/spread -> lowest tier, never a
;;;;     speculative interrupt.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.situation-scoring)

(defvar *running* nil)

;;; --- Impact classification -------------------------------------------------

;;; Impact level per detected situation category (docs/design/
;;; situation-scoring.md §3.1 + §4):
;;;   :s1 wasted tokens / will-correct    :s2 wrong-but-correctable
;;;   :s3 destructive / silent-wrong / policy-violation
(defparameter *category-impact*
  '((:identical-call-loop       . :s2)
    (:retry-without-progress    . :s2)
    (:zero-progress             . :s2)
    (:token-sink                . :s1)
    (:failing-verification      . :s2)
    (:excessive-waits           . :s1)
    (:cost-exceedance           . :s2)
    (:chatter-loop              . :s2))
  "Default impact level per detected category. Callers may override per run.")

(defparameter *impact-value*
  '((:s1 . 0.4) (:s2 . 0.7) (:s3 . 1.0))
  "Normalized priority weight per impact level.")

(defun category-impact (category)
  "Return the impact keyword for CATEGORY, defaulting to :s2 (safe, fail-closed)."
  (or (cdr (assoc category *category-impact*)) :s2))

;;; --- Recovery-stage tracker -------------------------------------------------

(defstruct recovery-tracker
  "Tracks per-category recovery-stage progression. COUNT is the number of
consecutive UNVALIDATED occurrences of the situation class; STAGE is the
highest recovery stage reached (1..4). A validated recovery RESETS both."
  (table (make-hash-table :test 'equal)))

(defun %ensure-state (tracker category)
  "Return (and intern if absent) the state plist for CATEGORY."
  (or (gethash category (recovery-tracker-table tracker))
      (setf (gethash category (recovery-tracker-table tracker))
            (list :count 0 :stage 1))))

(defun tracker-count (tracker category)
  "Consecutive unvalidated occurrences of CATEGORY (0 when clean)."
  (getf (%ensure-state tracker category) :count))

(defun tracker-stage (tracker category)
  "Recovery stage reached for CATEGORY (1..4)."
  (getf (%ensure-state tracker category) :stage))

(defun record-recovery (tracker category &key validated)
  "Record a recovery outcome for CATEGORY:
  - VALIDATED: a changed action produced a positive/validated result — reset
    count and advance stage (the fault is resolved; do not escalate).
  - Not validated: count another unresolved occurrence (feeds escalations);
    leave stage at the fault-attempt level.
Returns the updated count."
  (let ((st (gethash category (recovery-tracker-table tracker))))
    (if validated
        (progn
          (setf (gethash category (recovery-tracker-table tracker))
                (list :count 0 :stage 4))
          0)
        (progn
          (unless st
            (setf st (%ensure-state tracker category)))
          (incf (getf st :count))
          (getf st :count)))))

;;; --- Scoring ---------------------------------------------------------------

(defparameter *w-impact* 0.6
  "Weight of the priority term (impact x urgency x spread) in the score.")
(defparameter *w-confidence* 0.4
  "Weight of the confidence term in the score.")

(defun score-situation (situation &key impact urgency spread confidence
                                    (unvalidated-count 0))
  "Compute a normalized 0..1 priority score for a SITUATION datum.
  score = w_i * impact * urgency * spread + w_c * confidence, plus a small
  recurrence boost proportional to UNVALIDATED-COUNT (progressive
  gate-lowering: an unresolved recurring class outranks a first-seen one).
  FAIL CLOSED: missing impact/urgency/spread default to their lowest values;
  a non-situation returns 0.0."
  (when (null situation) (return-from score-situation 0.0))
  (let* ((imp-val (or (cdr (assoc (or impact (category-impact (getf situation :category)))
                                  *impact-value*))
                      (cdr (assoc :s1 *impact-value*))))
         (urg (or urgency 0.5))
         (spr (or spread 0.5))
         (conf (or confidence (getf situation :confidence) 0.5))
         (base (+ (* *w-impact* imp-val urg spr)
                  (* *w-confidence* conf)))
         (boost (* 0.15 (max 0 unvalidated-count))))
    (max 0.0 (min 1.0 (+ base boost)))))

;;; --- Gate-lowering + A3 action mapping -------------------------------------

(defconstant +steer-base+ 0.6
  "Base steer threshold (matches acp-steer-command default).")
(defconstant +interrupt-base+ 0.9
  "Base interrupt threshold (matches acp-steer-command default).")
(defparameter *gate-lowering-step* 0.1
  "How much each unresolved recurrence lowers both thresholds.")

(defun effective-thresholds (unvalidated-count)
  "Return (values steer interrupt) thresholds, lowered by
*GATE-LOWERING-STEP* per unresolved recurrence (floor 0.3/0.5 so a single
situation never interrupts)."
  (let ((step (* *gate-lowering-step* (max 0 unvalidated-count))))
    (values (max 0.3 (- +steer-base+ step))
            (max 0.5 (- +interrupt-base+ step)))))

(defun escalate-by-class-p (category zero-env-p)
  "Whether CATEGORY + ZERO-ENV-P alone forces an interrupt regardless of
count (the S3 / long-thinking-zero-env rule)."
  (or (eq category :token-sink)        ; long thinking, zero env interaction
      (eq category :instruction-misread)))

(defun situation-action (situation &key impact zero-env-p (unvalidated-count 0))
  "Map a SITUATION datum to an ACP steering action :none/:steer/:interrupt by
scoring it and passing through acp-steer-command with the effective (possibly
lowered) thresholds. FAIL CLOSED: a NIL situation or one below the steer
threshold returns :none. The ladder (§3.3):
  - 1 unresolved same-class -> steer-class; 2+ -> interrupt-class
  - highest-risk class (token-sink/instruction-misread) recurring in a
    zero-env context, or S3 severity with recurrence, forces :interrupt."
  (when (null situation) (return-from situation-action :none))
  (let* ((imp (or impact (category-impact (getf situation :category))))
         (cat (getf situation :category))
         (score (score-situation situation
                                 :impact imp
                                 :confidence (getf situation :confidence)
                                 :unvalidated-count unvalidated-count)))
    (cond
      ((and (escalate-by-class-p cat zero-env-p) (>= unvalidated-count 1))
       :interrupt)
      ((and (eq imp :s3) (>= unvalidated-count 1))
       :interrupt)
      (t
       (multiple-value-bind (steer interrupt)
           (effective-thresholds unvalidated-count)
         (hngh.plugins.acp-client:acp-steer-command
          score :steer-above steer :interrupt-above interrupt))))))

(defun decide (situation &key impact zero-env-p tracker)
  "End-to-end L3 decision for a SITUATION datum: consult the TRACKER (when
given) for validated/unvalidated history, score, and return an action keyword.
When TRACKER is given, a prior VALIDATED recovery for the same category is
honored (count reset => no escalation); otherwise the recurrence count defaults
to 0 (first-seen situations never interrupt)."
  (let ((count (if tracker (tracker-count tracker (getf situation :category)) 0)))
    (situation-action situation
                      :impact impact
                      :zero-env-p zero-env-p
                      :unvalidated-count count)))

;;; --- Standard plugin surface ----------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Situation scorer initialized (L3)")
  t)

(defun shutdown ()
  (setf *running* nil)
  (hngh.core:log-info "Situation scorer shut down"))

(defun running-p () *running*)

(defun status ()
  (list :running *running*
        :impact-table (length *category-impact*)
        :steer-base +steer-base+
        :interrupt-base +interrupt-base+))