;;;; tests/unit/test-situation-casebase.lisp — L2/L3 persistent case-base +
;;;; review pass (step 5 / design §7).
;;;;
;;;; Uses a temp hngh-home for isolation and a DETERMINISTIC judge hook for
;;;; the review pass — no network, no model. Covers:
;;;;   - record/read persistence (append-only, id monotonic)
;;;;   - source + weight handling (human /steer = high-weight ground truth)
;;;;   - situation distribution
;;;;   - review pass metrics (precision/recall/conf) computed without model
;;;;   - accuracy-improving-p across successive passes (the §8 gate)
;;;;   - emergent-class probe
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later

(in-package :hngh.tests)

(def-suite :hngh.situation-casebase
  :description "Tests for the L2/L3 case-base + review pass"
  :in :hngh)

(in-suite :hngh.situation-casebase)

;;; --- fixture: isolated temp hngh-home -------------------------------------

(defun %fresh-home ()
  (let* ((base (merge-pathnames
                (format nil "hngh-casebase-test-~D-~D-/"
                        (get-universal-time) (random 1000000))
                (uiop:temporary-directory)))
         (h (merge-pathnames "home/" base)))
    (ensure-directories-exist h)
    h))

(defmacro %within-home (&body body)
  "Run BODY with a fresh isolated state dir; init + shutdown the case-base."
  `(let* ((home (%fresh-home))
          (hngh:*hngh-home* home))
     (hngh.core.state-store:init :hngh-home home)
     (hngh.plugins.situation-casebase:init :hngh-home home)
     (unwind-protect (progn ,@body)
       (hngh.plugins.situation-casebase:shutdown))))

;;; --- record/read persistence ----------------------------------------------

(test record-appends-and-reads-back
  (%within-home
    (hngh.plugins.situation-casebase:record-case
      '((:kind :tool-call :tool "terminal")) :faulty-logic
      :score 0.8 :action :steer :outcome :improved)
    (is (= 1 (hngh.plugins.situation-casebase:case-count)))
    (let ((c (first (hngh.plugins.situation-casebase:all-cases))))
      (is (eq :faulty-logic (getf c :situation)))
      (is (= 0.8 (getf c :score)))
      (is (eq :improved (getf c :outcome))))))

(test record-ids-monotonic
  (%within-home
    (hngh.plugins.situation-casebase:record-case '() :faulty-logic)
    (hngh.plugins.situation-casebase:record-case '() :wasted-work)
    (hngh.plugins.situation-casebase:record-case '() :none)
    (let ((ids (mapcar (lambda (c) (getf c :id))
                       (hngh.plugins.situation-casebase:all-cases))))
      (is (= 3 (length ids)))
      (is (= 3 (length (remove-duplicates ids))) "ids are distinct")
      (is (= 1 (apply #'min ids)) "first id is 1"))))

(test human-cases-high-weight
  (%within-home
    (hngh.plugins.situation-casebase:record-case '() :faulty-logic
      :source :human :weight 2.0)
    (hngh.plugins.situation-casebase:record-case '() :wasted-work
      :source :auto)
    (is (= 1 (length
              (hngh.plugins.situation-casebase:cases-by-source :human))))
    (let ((h (first (hngh.plugins.situation-casebase:cases-by-source :human))))
      (is (= 2.0 (getf h :weight))))))

(test distribution-counts
  (%within-home
    (hngh.plugins.situation-casebase:record-case '() :faulty-logic)
    (hngh.plugins.situation-casebase:record-case '() :faulty-logic)
    (hngh.plugins.situation-casebase:record-case '() :wasted-work)
    (let ((dist (hngh.plugins.situation-casebase:situation-distribution)))
      (is (= 2 (second (assoc :faulty-logic dist))))
      (is (= 1 (second (assoc :wasted-work dist)))))))

;;; --- review pass (deterministic judge hook) --------------------------------

(test review-pass-computes-metrics
  (%within-home
    (hngh.plugins.situation-casebase:record-case '(:w1) :faulty-logic)
    (hngh.plugins.situation-casebase:record-case '(:silent) :none)
    ;; deterministic judge: labels every window the same known situation class
    (let ((r (hngh.plugins.situation-casebase:run-review-pass
               :judge-hook (lambda (window)
                             (declare (ignore window))
                             (list :situation :faulty-logic
                                   :confidence 0.9)))))
      (is (= 1 (getf r :n)))
      (is (= 1 (getf r :correct)))
      (is (= 1.0 (getf r :precision)))
      (is (= 1.0 (getf r :recall))))))

(test review-pass-accuracy-improves-across-passes
  ;; Pass 1: judge wrong on a case. Pass 2: correct. The §8 step 5 gate is
  ;; that calibration/accuracy IMPROVES (or holds) across successive passes.
  (%within-home
    (hngh.plugins.situation-casebase:record-case '(:w) :faulty-logic)
    ;; deterministic hook that is WRONG on pass 1, RIGHT on pass 2
    (let ((pass 0))
      (flet ((hook (window) (declare (ignore window))
                  (incf pass)
                  (if (= pass 1)
                      (list :situation :wasted-work :confidence 0.4)
                      (list :situation :faulty-logic :confidence 0.9))))
        (hngh.plugins.situation-casebase:run-review-pass :judge-hook #'hook)
        (let ((r2 (hngh.plugins.situation-casebase:run-review-pass
                    :judge-hook #'hook)))
          (is (= 1 (getf r2 :correct)))
          (is (hngh.plugins.situation-casebase:accuracy-improving-p))
          (is (= 2 (length (hngh.plugins.situation-casebase:pass-stats)))))))))

(test review-pass-noop-empty-base
  (%within-home
    (let ((r (hngh.plugins.situation-casebase:run-review-pass
               :judge-hook (lambda (w) (declare (ignore w)) nil))))
      (is (= 0 (getf r :n)))
      (is (= 1.0 (getf r :precision))))))

(test emergent-classes-probe
  (%within-home
    (dotimes (i 6)
      (hngh.plugins.situation-casebase:record-case '() :faulty-logic))
    (dotimes (i 8)
      (hngh.plugins.situation-casebase:record-case '() :wasted-work))
    (let ((em (hngh.plugins.situation-casebase:emergent-classes)))
      (is (listp em))
      (is (<= (length em) 2)))))

(test classify-lane-line-uses-deterministic-taxonomy
  (is (eq :loop-or-stuck
          (hngh.plugins.situation-casebase:classify-lane-line
           "STATE: found false-death retry loop")))
  (is (eq :human-steer
          (hngh.plugins.situation-casebase:classify-lane-line
           "STEER: check the sibling lane"))))

(test feed-lanes-appends-fixture-records
  (%within-home
    (let* ((root (merge-pathnames "lane-fixture/" (uiop:temporary-directory)))
           (lane (merge-pathnames "tandem-cibo/" root)))
      (unwind-protect
           (progn
             (ensure-directories-exist lane)
             (with-open-file (stream (merge-pathnames "worklog.md" lane)
                                     :direction :output :if-exists :supersede)
               (format stream "STATE: false-death retry loop~%")
               (format stream "STEER: check the sibling lane~%")
               (format stream "ordinary note~%"))
             (is (= 2 (hngh.plugins.situation-casebase:feed-lanes root
                                                                    :seats '("cibo"))))
             (is (= 2 (hngh.plugins.situation-casebase:case-count)))
             (is (= 1 (length (hngh.plugins.situation-casebase:cases-by-source :human)))))
        (when (probe-file root)
          (uiop:delete-directory-tree root :validate #'identity))))))


(test situation-casebase-status-shape
  (%within-home
    (hngh.plugins.situation-casebase:record-case '() :faulty-logic)
    (let ((s (hngh.plugins.situation-casebase:status)))
      (is (listp s))
      (is (= 1 (getf s :cases)))
      (is (listp (getf s :distribution))))))
