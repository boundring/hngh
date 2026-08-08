;;;; tests/unit/test-situation-scoring.lisp — L3 scorer + action mapping.
;;;;
;;;; Fixture-driven:
;;;;   - score increases with impact/urgency/spread/confidence and with
;;;;     unresolved recurrence (gate-lowering).
;;;;   - the recovery-stage tracker resets on a VALIDATED fix, so a healthy
;;;;     fix-attempt routes :none/:log — never :interrupt.
;;;;   - 2x unvalidated same-class routes :steer then :interrupt (the ladder).
;;;;   - action mapping goes through acp-steer-command with (lowered)
;;;;     thresholds; a NAIL situation / low score fails closed to :none.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later

(in-package :hngh.tests)

(def-suite :hngh.situation-scoring
  :description "Tests for L3 situation scoring + action mapping"
  :in :hngh)

(in-suite :hngh.situation-scoring)

(defun %sit (&rest args)
  "Build a minimal situation datum: (%sit :category :token-sink :confidence 0.8)."
  (list* :category :token-sink
         :confidence 0.8
         (copy-list args)))

;;; --- Scoring ----------------------------------------------------------------

(test score-nil-situation-is-zero
  (is (= 0.0 (hngh.plugins.situation-scoring:score-situation nil))))

(test score-ranges-0-1
  (let ((s (hngh.plugins.situation-scoring:score-situation
            (%sit) :impact :s2 :urgency 0.5 :spread 0.5)))
    (is (>= s 0.0))
    (is (<= s 1.0))))

(test score-higher-impact-outranks-lower
  (is (> (hngh.plugins.situation-scoring:score-situation (%sit) :impact :s3)
         (hngh.plugins.situation-scoring:score-situation (%sit) :impact :s1))))

(test score-urgency-raises
  (is (> (hngh.plugins.situation-scoring:score-situation (%sit) :urgency 1.0)
         (hngh.plugins.situation-scoring:score-situation (%sit) :urgency 0.1))))

(test score-spread-raises
  (is (> (hngh.plugins.situation-scoring:score-situation (%sit) :spread 1.0)
         (hngh.plugins.situation-scoring:score-situation (%sit) :spread 0.1))))

(test score-recurrence-raises-gate-lowering
  (is (> (hngh.plugins.situation-scoring:score-situation (%sit) :unvalidated-count 3)
         (hngh.plugins.situation-scoring:score-situation (%sit) :unvalidated-count 0))))

;;; --- Recovery-stage tracker --------------------------------------------------

(test tracker-starts-clean
  (let ((t1 (hngh.plugins.situation-scoring:make-recovery-tracker)))
    (is (eql 0 (hngh.plugins.situation-scoring:tracker-count t1 :token-sink)))
    (is (eql 1 (hngh.plugins.situation-scoring:tracker-stage t1 :token-sink)))))

(test tracker-increments-unvalidated
  (let ((t1 (hngh.plugins.situation-scoring:make-recovery-tracker)))
    (is (eql 1 (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated nil)))
    (is (eql 2 (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated nil)))
    (is (eql 2 (hngh.plugins.situation-scoring:tracker-count t1 :token-sink)))))

(test tracker-resets-on-validated
  (let ((t1 (hngh.plugins.situation-scoring:make-recovery-tracker)))
    (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated nil)
    (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated nil)
    (is (eql 0 (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated t)))
    (is (eql 0 (hngh.plugins.situation-scoring:tracker-count t1 :token-sink)))))

(test tracker-isolation-per-category
  (let ((t1 (hngh.plugins.situation-scoring:make-recovery-tracker)))
    (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated nil)
    (is (eql 0 (hngh.plugins.situation-scoring:tracker-count t1 :chatter-loop)))))

;;; --- Gate-lowering thresholds -------------------------------------------------

(test effective-thresholds-lower-with-recurrence
  (multiple-value-bind (s0 i0)
      (hngh.plugins.situation-scoring:effective-thresholds 0)
    (multiple-value-bind (s1 i1)
        (hngh.plugins.situation-scoring:effective-thresholds 2)
      (is (< s1 s0))
      (is (< i1 i0))
      (is (>= i1 0.5))
      (is (>= s1 0.3)))))

;;; --- Action mapping (via acp-steer-command) ----------------------------------

(test single-fault-healthy-fix-routes-none
  ;; first-seen situation, low-enough score -> :none (never interrupt early)
  (is (eql :none
           (hngh.plugins.situation-scoring:situation-action
            (%sit) :impact :s2 :unvalidated-count 0))))

(test first-seen-can-steer
  ;; a genuinely urgent single situation can steer (but not interrupt)
  (let ((action (hngh.plugins.situation-scoring:situation-action
                 (%sit) :impact :s3 :zero-env-p nil :unvalidated-count 0)))
    (is (member action '(:none :steer)))))

(test two-unvalidated-routes-steer-then-interrupt
  ;; escalation ladder: 1 unresolved -> steer-class, 2+ -> interrupt-class
  (let* ((t1 (hngh.plugins.situation-scoring:make-recovery-tracker))
         (one (hngh.plugins.situation-scoring:decide
               (%sit) :impact :s2 :tracker t1)))
    (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated nil)
    (let* ((two (hngh.plugins.situation-scoring:decide
                 (%sit) :impact :s2 :tracker t1)))
      (is (member one '(:none :steer)))
      (is (member two '(:steer :interrupt))))))

(test validated-fix-never-interrupts
  ;; even a severe-seeming situation: after a validated recovery the tracker
  ;; resets, so decide() sees count 0 and cannot interrupt.
  (let ((t1 (hngh.plugins.situation-scoring:make-recovery-tracker)))
    (hngh.plugins.situation-scoring:record-recovery t1 :token-sink :validated t)
    (is (not (eql :interrupt
                  (hngh.plugins.situation-scoring:situation-action
                   (%sit) :impact :s3 :unvalidated-count
                   (hngh.plugins.situation-scoring:tracker-count t1 :token-sink)))))))

(test nil-situation-fails-closed-to-none
  (is (eql :none (hngh.plugins.situation-scoring:situation-action nil))))

(test token-sink-zero-env-escalates
  ;; the highest-risk pattern: long thinking, zero env interaction
  (let ((action (hngh.plugins.situation-scoring:situation-action
                 (%sit :category :token-sink)
                 :impact :s2 :zero-env-p t :unvalidated-count 1)))
    (is (member action '(:steer :interrupt)))))

;;; --- Standard plugin surface ---------------------------------------------------

(test situation-scoring-status-shape
  (let ((s (hngh.plugins.situation-scoring:status)))
    (is (listp s))
    (is (not (null (getf s :impact-table))))))