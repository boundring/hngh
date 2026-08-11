;;;; tests/unit/test-planner-quota-admission.lisp — Planner quota-truth tests
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(in-suite :hngh.hngh-planner)

(defparameter *planner-quota-admission-route-defaults*
  '((kimi-sub
     (:buckets ((:period :five-hour :cap 100000 :units :tokens)
                (:period :week :cap 2000000 :units :tokens)
                (:period :day :cap 300000 :units :tokens)
                (:period :hour :cap 40000 :units :tokens)
                (:period :month :cap 8000000 :units :tokens)))))
  "Fixture-only numeric envelope for live ledger admission tests.")

(defun %seed-half-open-planner-quota-window ()
  "Seed every Kimi bucket halfway through its window and record one measured use."
  (let ((now (get-universal-time)))
    (hngh.core.state-store:write-state
     "quota-anchors"
     (loop for (period . seconds)
             in hngh.plugins.quota-spreader::*period-seconds*
           collect (list :route 'kimi-sub
                         :period period
                         :anchor (- now (floor seconds 2)))))
    (hngh.plugins.quota-spreader:quota-consumed
     'kimi-sub :actual-amount 1)))

(test planner-quota-gate-derives-live-pacing
  (with-aio-light (tmp)
    (let ((hngh.plugins.quota-spreader::*route-defaults*
            *planner-quota-admission-route-defaults*)
          (hngh.plugins.quota-spreader::*overrides* nil))
      (%seed-half-open-planner-quota-window)
      (is-true (hngh.plugins.hngh-planner::%quota-gate-open-p)))))
