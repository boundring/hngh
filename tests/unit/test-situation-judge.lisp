;;;; tests/unit/test-situation-judge.lisp — Tier-1 semantic judge.
;;;;
;;;; Uses the *JUDGE-RESPONDER* injection seam — no network in tests. Covers:
;;;;   - bounded prompt construction (recent MAX-OBS window folded in)
;;;;   - verdict parsing (valid JSON; malformed/non-JSON -> NIL)
;;;;   - FAIL-CLOSED judge-situation (no budget / no response / unparseable)
;;;;   - watchdog budget gating (bounded calls per run)
;;;;   - offline calibration harness (precision/recall/conf + calibrated?)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later

(in-package :hngh.tests)

(def-suite :hngh.situation-judge
  :description "Tests for the L2/L3 Tier-1 semantic judge"
  :in :hngh)

(in-suite :hngh.situation-judge)

;;; --- Fixture helpers (namespaced %j- to avoid clobbering the shared
;;; hngh.tests package helpers defined by test-situation-detectors.lisp) -------

(defun %j-obs (kind &rest args)
  (list* :kind kind args))

(defun %j-call (tool args)
  (%j-obs :tool-call :tool tool :args args))

(defun %j-result (tool &key ok error-class)
  (%j-obs :tool-result :tool tool :args "" :ok ok :error-class error-class))

(defun %j-thinking (tokens)
  (%j-obs :thinking :tokens tokens))

(defun %j-json-verdict (score conf situation &optional reason)
  (format nil "{\"score\":~A,\"confidence\":~A,\"situation\":\"~A\",\"reason\":\"~A\"}"
          score conf situation (or reason "")))

;;; --- Prompt construction ------------------------------------------------------

(test build-judge-prompt-folds-recent-window
  (let* ((window (list (%j-call "terminal" "make test")
                       (%j-result "make test" :ok nil :error-class "compilation-failed")))
         (p (hngh.plugins.situation-judge:build-judge-prompt window)))
    (is (search "make test" p))
    (is (search "compilation-failed" p))
    (is (search "{\"score\"" p))))

(test build-judge-prompt-bounds-max-obs
  (let* ((window (loop for i below 30
                       collect (%j-call "terminal" (format nil "cmd ~D" i))))
         (p (hngh.plugins.situation-judge:build-judge-prompt window :max-obs 5)))
    ;; only the 5 newest commands appear
    (is (search "cmd 25" p))
    (is (null (search "cmd 3" p)))))

;;; --- Verdict parsing ------------------------------------------------------------

(test parse-verdict-valid-json
  (let ((v (hngh.plugins.situation-judge:parse-verdict
            (%j-json-verdict 0.8 0.9 "faulty-logic" "bad logic"))))
    (is (eq :faulty-logic (getf v :situation)))
    (is (= 0.8d0 (getf v :score)))
    (is (= 0.9d0 (getf v :confidence)))
    (is (string= "bad logic" (getf v :reason)))))

(test parse-verdict-rejects-non-json
  (is (null (hngh.plugins.situation-judge:parse-verdict "just some text"))))

(test parse-verdict-rejects-out-of-range
  (is (null (hngh.plugins.situation-judge:parse-verdict
             (%j-json-verdict 1.5 0.9 "faulty-logic"))))
  (is (null (hngh.plugins.situation-judge:parse-verdict
             (%j-json-verdict 0.5 0.9 "not-a-valid-situation")))))

(test parse-verdict-rejects-empty
  (is (null (hngh.plugins.situation-judge:parse-verdict nil)))
  (is (null (hngh.plugins.situation-judge:parse-verdict ""))))

;;; --- Budget gating -------------------------------------------------------------

(test judge-budget-bounded
  (hngh.plugins.situation-judge:reset-judge-budget 2)
  (is (hngh.plugins.situation-judge:judge-budget-ok-p))
  (is (hngh.plugins.situation-judge:reserve-judge-call))
  (is (hngh.plugins.situation-judge:judge-budget-ok-p))
  (is (hngh.plugins.situation-judge:reserve-judge-call))
  ;; budget now exhausted
  (is (null (hngh.plugins.situation-judge:judge-budget-ok-p)))
  (is (null (hngh.plugins.situation-judge:reserve-judge-call)))
  (hngh.plugins.situation-judge:reset-judge-budget))

;;; --- judge-situation (fail-closed) ----------------------------------------------

(test judge-situation-fails-closed-on-no-budget
  (hngh.plugins.situation-judge:reset-judge-budget 0)
  (let ((v (hngh.plugins.situation-judge:judge-situation (list (%j-call "x" "y")))))
    (is (eq :error (getf v :situation)))
    (is (= 0.0 (getf v :confidence))))
  (hngh.plugins.situation-judge:reset-judge-budget))

(test judge-situation-with-responder-parses
  (let ((window (list (%j-call "terminal" "make test")
                      (%j-result "make test" :ok nil :error-class "compilation-failed"))))
    (let ((old hngh.plugins.situation-judge:*judge-responder*))
      (unwind-protect
           (progn
             (setf hngh.plugins.situation-judge:*judge-responder*
                   (lambda (prompt &key &allow-other-keys)
                     (declare (ignore prompt))
                     (%j-json-verdict 0.7 0.85 "wasted-work" "re-running failing test")))
             (let ((v (hngh.plugins.situation-judge:judge-situation window)))
               (is (eq :wasted-work (getf v :situation)))
               (is (= 0.7d0 (getf v :score)))
               (is (= 0.85d0 (getf v :confidence)))))
        (setf hngh.plugins.situation-judge:*judge-responder* old)))))

(test judge-situation-fails-closed-on-unparseable-response
  (let ((old hngh.plugins.situation-judge:*judge-responder*))
    (unwind-protect
         (progn
           (setf hngh.plugins.situation-judge:*judge-responder*
                 (lambda (prompt &key &allow-other-keys)
                   (declare (ignore prompt)) "not json at all"))
           (let ((v (hngh.plugins.situation-judge:judge-situation (list (%j-call "x" "y")))))
             (is (eq :error (getf v :situation)))
             (is (= 0.0 (getf v :confidence)))))
      (setf hngh.plugins.situation-judge:*judge-responder* old))))

(test judge-situation-fails-closed-on-no-response
  ;; simulate a dead/down endpoint: the responder returns NIL (no response),
  ;; which judge-situation must treat as a failed call -> fail-closed :error.
  ;; (A real curl to an unreachable port is an integration concern, not a
  ;; fast-suite test — it would add ~5s connect timeout under the 15s budget.)
  (let ((old hngh.plugins.situation-judge:*judge-responder*))
    (unwind-protect
         (progn
           (setf hngh.plugins.situation-judge:*judge-responder*
                 (lambda (prompt &key &allow-other-keys)
                   (declare (ignore prompt)) nil))
           (let ((v (hngh.plugins.situation-judge:judge-situation
                     (list (%j-call "x" "y")))))
             (is (eq :error (getf v :situation)))
             (is (= 0.0d0 (getf v :confidence)))))
      (setf hngh.plugins.situation-judge:*judge-responder* old))))

;;; --- Calibration harness ---------------------------------------------------------

(defun %case (window exp-sit)
  (list :window window :expected (list :situation exp-sit)))

(test calibrate-judge-perfect-on-clear-case-base
  (let* ((cb (list
              (%case (list (%j-call "terminal" "make test")
                           (%j-result "make test" :ok nil :error-class "compile"))
                     :wasted-work)
              (%case (list (%j-call "terminal" "make test")
                           (%j-result "make test" :ok t))
                     :none)))
         (old hngh.plugins.situation-judge:*judge-responder*)
         (i 0)
         (answers '("{\"score\":0.8,\"confidence\":0.9,\"situation\":\"wasted-work\",\"reason\":\"\"}"
                    "{\"score\":0.0,\"confidence\":0.8,\"situation\":\"none\",\"reason\":\"\"}")))
    (unwind-protect
         (progn
           (setf hngh.plugins.situation-judge:*judge-responder*
                 (lambda (prompt &key &allow-other-keys)
                   (declare (ignore prompt))
                   (prog1 (nth i answers) (incf i))))
           (let ((c (hngh.plugins.situation-judge:calibrate-judge cb)))
             (is (= 2 (hngh.plugins.situation-judge:calibration-n c)))
             (is (= 2 (hngh.plugins.situation-judge:calibration-correct c)))
             (is (= 1.0 (hngh.plugins.situation-judge:calibration-precision c)))
             (is (hngh.plugins.situation-judge:calibration-calibrated c))))
      (setf hngh.plugins.situation-judge:*judge-responder* old))))

(test calibrate-judge-not-calibrated-on-wrong-answers
  (let* ((cb (list (%case (list (%j-call "x" "y")) :faulty-logic)))
         (old hngh.plugins.situation-judge:*judge-responder*))
    (unwind-protect
         (progn
           (setf hngh.plugins.situation-judge:*judge-responder*
                 (lambda (prompt &key &allow-other-keys)
                   (declare (ignore prompt))
                   "{\"score\":0.9,\"confidence\":0.9,\"situation\":\"none\",\"reason\":\"\"}" ))
           (let ((c (hngh.plugins.situation-judge:calibrate-judge cb)))
             (is (= 0.0 (hngh.plugins.situation-judge:calibration-precision c)))
             (is (null (hngh.plugins.situation-judge:calibration-calibrated c)))))
      (setf hngh.plugins.situation-judge:*judge-responder* old))))

;;; --- Standard plugin surface ---------------------------------------------------

(test situation-judge-status-shape
  (let ((s (hngh.plugins.situation-judge:status)))
    (is (listp s))
    (is (not (null (getf s :budget-remaining))))))