;;;; tests/unit/test-situation-detectors.lisp — Tier-0 detector fixtures.
;;;;
;;;; Every detector must fire on its synthetic fixture (derived from the
;;;; /steer case-base classes: wasted waits, faulty logic, not-sourcing-info,
;;;; risky-experiment, coordination, cost/token, stuck-seat) and must NOT
;;;; fire on the healthy counter-example. No model calls anywhere.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later

(in-package :hngh.tests)

(def-suite :hngh.situation-detectors
  :description "Tests for L2 Tier-0 situation detectors"
  :in :hngh)

(in-suite :hngh.situation-detectors)

;;; --- Fixture helpers --------------------------------------------------------

(defun %obs (kind &rest args)
  "Build an observation plist: (%obs :tool-call :tool \"terminal\" :args \"make test\")."
  (list* :kind kind args))

(defun %call (tool args)
  (%obs :tool-call :tool tool :args args
        :fingerprint (hngh.plugins.situation-detectors:fingerprint tool args)))

(defun %result (tool &key ok error-class artifacts)
  (let ((obs (%obs :tool-result :tool tool
                   :ok ok :error-class error-class)))
    (when artifacts (setf (getf obs :artifacts) artifacts))
    obs))

(defun %thinking (tokens)
  (%obs :thinking :tokens tokens))

(defun %wait (seconds)
  (%obs :wait :seconds seconds))

(defun %message ()
  (%obs :message))

;;; --- Identical-call loop -----------------------------------------------------

(test identical-loop-fires-on-3x-same-call
  (let ((s (hngh.plugins.situation-detectors:detect-identical-call-loop
            (list (%call "terminal" "make test")
                  (%call "terminal" "make test")
                  (%call "terminal" "make test")))))
    (is (not (null s)))
    (is (eq (getf s :category) :identical-call-loop))
    (is (>= (getf s :count) 3))))

(test identical-loop-not-fires-on-distinct-calls
  (is (null (hngh.plugins.situation-detectors:detect-identical-call-loop
             (list (%call "terminal" "make test")
                   (%call "terminal" "grep foo")
                   (%call "terminal" "sbcl --version"))))))

(test identical-loop-exempts-poll-tools
  (is (null (hngh.plugins.situation-detectors:detect-identical-call-loop
             (list (%call "process" "list")
                   (%call "process" "list")
                   (%call "process" "list"))))))

;;; --- Retry without progress --------------------------------------------------

(test retry-no-progress-fires-on-cosmetic-retry
  ;; same tool, args change cosmetically, error class unchanged, 2 cycles
  (let ((s (hngh.plugins.situation-detectors:detect-retry-without-progress
            (list
             (%call "sbcl" "--eval (foo)")
             (%result "sbcl" :ok nil :error-class "undefined-function")
             (%call "sbcl" "--eval (foo) ; retry")
             (%result "sbcl" :ok nil :error-class "undefined-function")
             (%call "sbcl" "--eval (foo) ;; again")
             (%result "sbcl" :ok nil :error-class "undefined-function")))))
    (is (not (null s)))
    (is (eq (getf s :category) :retry-without-progress))
    (is (>= (getf s :count) 2))))

(test retry-no-progress-not-fires-on-healthy-fix
  ;; error class CHANGES on the fix attempt — that's a healthy correction
  (is (null (hngh.plugins.situation-detectors:detect-retry-without-progress
             (list
              (%call "sbcl" "--eval (foo)")
              (%result "sbcl" :ok nil :error-class "undefined-function")
              (%call "sbcl" "--eval (bar)")
              (%result "sbcl" :ok nil :error-class "undefined-function-bar"))))))

;;; --- Zero progress ------------------------------------------------------------

(test zero-progress-fires-on-unchanged-artifacts
  (let ((s (hngh.plugins.situation-detectors:detect-zero-progress
            (list
             (%result "terminal" :ok t :artifacts '("a.lisp"))
             (%result "terminal" :ok t :artifacts '("a.lisp"))
             (%result "terminal" :ok t :artifacts '("a.lisp"))))))
    (is (not (null s)))
    (is (eq (getf s :category) :zero-progress))))

(test zero-progress-not-fires-on-changing-artifacts
  (is (null (hngh.plugins.situation-detectors:detect-zero-progress
             (list
              (%result "terminal" :ok t :artifacts '("a.lisp"))
              (%result "terminal" :ok t :artifacts '("a.lisp" "b.lisp")))))))

;;; --- Long-thinking token sink -------------------------------------------------

(test token-sink-fires-on-long-thinking-run
  (let ((s (hngh.plugins.situation-detectors:detect-token-sink
            (list (%thinking 6000) (%thinking 6000) (%thinking 6000))
            :token-budget 16000 :min-tokens 4000)))
    (is (not (null s)))
    (is (eq (getf s :category) :token-sink))))

(test token-sink-not-fires-when-interleaved-with-tool-calls
  ;; contact with the environment resets the run — healthy
  (is (null (hngh.plugins.situation-detectors:detect-token-sink
             (list (%thinking 6000) (%call "terminal" "ls") (%thinking 6000))
             :token-budget 16000 :min-tokens 4000))))

;;; --- Repeated failing verification ---------------------------------------------

(test failing-verification-fires-on-rerun-no-pass
  (let ((s (hngh.plugins.situation-detectors:detect-failing-verification
            (list
             (%result "make test" :ok nil :error-class "compilation-failed")
             (%result "make test" :ok nil :error-class "compilation-failed")))))
    (is (not (null s)))
    (is (eq (getf s :category) :failing-verification))))

(test failing-verification-not-fires-when-passes
  (is (null (hngh.plugins.situation-detectors:detect-failing-verification
             (list
              (%result "make test" :ok nil :error-class "compilation-failed")
              (%result "make test" :ok t))))))

;;; --- Excessive waits ------------------------------------------------------------

(test excessive-waits-fires-on-3-waits
  (let ((s (hngh.plugins.situation-detectors:detect-excessive-waits
            (list (%wait 30) (%wait 30) (%wait 30)))))
    (is (not (null s)))
    (is (eq (getf s :category) :excessive-waits))))

(test excessive-waits-not-fires-on-short-single-wait
  (is (null (hngh.plugins.situation-detectors:detect-excessive-waits
             (list (%wait 5))))))

;;; --- Cost exceedance -------------------------------------------------------------

(test cost-exceedance-fires-on-budget-crossed
  (let ((s (hngh.plugins.situation-detectors:detect-cost-exceedance
            nil :budget (list :spent 500 :limit 100))))
    (is (not (null s)))
    (is (eq (getf s :category) :cost-exceedance))))

(test cost-exceedance-not-fires-within-budget
  (is (null (hngh.plugins.situation-detectors:detect-cost-exceedance
             nil :budget (list :spent 50 :limit 100)))))

(test cost-exceedance-fails-closed-on-no-budget
  (is (null (hngh.plugins.situation-detectors:detect-cost-exceedance nil))))

;;; --- Chatter loop ------------------------------------------------------------------

(test chatter-loop-fires-on-message-ping-pong
  (let ((s (hngh.plugins.situation-detectors:detect-chatter-loop
            (list (%message) (%message) (%message)))))
    (is (not (null s)))
    (is (eq (getf s :category) :chatter-loop))))

(test chatter-loop-not-fires-on-messages-with-progress
  ;; a tool-result breaks the ping-pong — progress happened
  (is (null (hngh.plugins.situation-detectors:detect-chatter-loop
             (list (%message) (%result "terminal" :ok t) (%message))))))

;;; --- Combined detect-situations -----------------------------------------------------

(test detect-situations-finds-known-class
  (let ((situations (hngh.plugins.situation-detectors:detect-situations
                     (list (%call "terminal" "make test")
                           (%call "terminal" "make test")
                           (%call "terminal" "make test")))))
    (is (member :identical-call-loop
                (mapcar (lambda (s) (getf s :category)) situations)))))

(test detect-situations-empty-on-healthy-window
  (is (null (hngh.plugins.situation-detectors:detect-situations
             (list (%call "terminal" "grep foo")
                   (%result "terminal" :ok t)
                   (%thinking 500))))))

;;; --- Standard plugin surface ---------------------------------------------------------

(test situation-detectors-status-shape
  (let ((s (hngh.plugins.situation-detectors:status)))
    (is (listp s))
    (is (not (null (getf s :window-size))))))