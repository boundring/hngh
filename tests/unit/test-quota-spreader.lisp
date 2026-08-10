;;;; tests/unit/test-quota-spreader.lisp — Tests for Quota Spreader (C6 W2)
;;;;
;;;; Fixture tests exercise envelope resolution, even-sparse drawdown,
;;;; recurring-authority reservations (no spillover), strategic-reserve
;;;; refusal, and reset advancement — all pure, no live API.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.quota-spreader
  :description "Tests for Quota Spreader (C6 W2)"
  :in :hngh)

(in-suite :hngh.quota-spreader)

;;; --- Envelope resolution --------------------------------------------------

(test strategic-routes-are-refused-by-default
  (is-true (hngh.plugins.quota-spreader:route-strategic-p 'frontier))
  (is-true (hngh.plugins.quota-spreader:route-strategic-p 'anthropic))
  (is-false (hngh.plugins.quota-spreader:route-strategic-p 'kimi-sub))
  ;; A strategic route refuses general quota-ok.
  (is-false (hngh.plugins.quota-spreader:quota-ok-p 'frontier :used 0)))

(test unknown-route-has-empty-fail-closed-envelope
  (let ((env (hngh.plugins.quota-spreader:quota-envelope 'not-a-route)))
    (is (eql 'not-a-route (getf env :route)))
    (is-false (getf env :strategic))
    (is (null (getf env :buckets)))))

(test kimi-sub-has-quota-buckets
  (let ((env (hngh.plugins.quota-spreader:quota-envelope 'kimi-sub)))
    (is (eq 'kimi-sub (getf env :route)))
    (is-true (getf env :buckets))
    ;; Buckets preserve declared order (week, day, hour, month); assert each period/cap.
    (let ((buckets (getf env :buckets)))
      (is (= 4 (length buckets)))
      (is (eql :month (getf (fourth buckets) :period)))
      (is (= 8000000 (getf (fourth buckets) :cap)))
      (is (= 2000000 (getf (first buckets) :cap)))
      (is (eql :hour (getf (third buckets) :period)))
      (is (= 40000 (getf (third buckets) :cap))))))

(test k3-driver-routes-authority-situations
  (is-true (hngh.plugins.quota-spreader:should-route-to-k3-p
            :code-final-review :used 0 :elapsed-seconds 3600))
  (is-true (hngh.plugins.quota-spreader:should-route-to-k3-p
            :plan-veto :used 0 :elapsed-seconds 3600))
  (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
             :tool-preview :used 0 :elapsed-seconds 3600))
  (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
             :code-final-review :used 400000 :elapsed-seconds 3600)))

(test k3-driver-surfaces-availability
  (is-true (hngh.plugins.quota-spreader:quota-available-p
            'kimi-sub :used 0 :elapsed-seconds 3600))
  (is (search "available-now"
              (hngh.plugins.quota-spreader:quota-status
               'kimi-sub :used 0 :elapsed-seconds 3600))))


(test even-rate-five-hour-window
  (is-true (hngh.plugins.quota-spreader::%even-rate-ok-p
            :five-hour 1000 100 9000))
  (is-false (hngh.plugins.quota-spreader::%even-rate-ok-p
             :five-hour 1000 600 9000)))

(test even-rate-ok-early-in-period
  ;; Day 2 of a weekly bucket (mostly time left) -> room.
  (is-true (hngh.plugins.quota-spreader::%even-rate-ok-p
            :week 700000 100000 172800)))

(test even-rate-over-early-burn
  ;; Used 600k of the week with lots of time left -> over even rate.
  (is-false (hngh.plugins.quota-spreader::%even-rate-ok-p
             :week 700000 600000 172800)))

(test even-rate-near-end-allows-full-spend
  ;; Nearly the whole period elapsed, used near cap -> still within even.
  (is-true (hngh.plugins.quota-spreader::%even-rate-ok-p
            :week 700000 680000 600000)))

;;; --- Authority reservation (no spillover) ---------------------------------

(test reservation-exists-for-authority-class
  (let ((rs (hngh.plugins.quota-spreader:reservations-for 'kimi-sub)))
    (is-true rs)
    (is (find 'code-final-review rs :key (lambda (r) (getf r :situation))
              :test (lambda (a b) (string= (symbol-name a) (symbol-name b)))))))

(test reservation-within-cap-is-ok
  (is-true (hngh.plugins.quota-spreader:quota-reserved-ok-p
            'kimi-sub 'code-final-review :used 100000)))

(test reservation-over-cap-refuses
  (is-false (hngh.plugins.quota-spreader:quota-reserved-ok-p
             'kimi-sub 'code-final-review
             :used 500000)))

(test unlisted-situation-has-no-reservation
  ;; A situation with no reservation is not an authority draw (general pool).
  (is-false (hngh.plugins.quota-spreader:quota-reserved-ok-p
             'kimi-sub 'tool-preview :used 10)))

;;; --- Strategic one-off vs general pool ------------------------------------

(test general-pool-one-off-ok-on-quota-route
  ;; kimi-sub general pool, early in period -> allowed.
  (is-true (hngh.plugins.quota-spreader:quota-general-ok-p
            'kimi-sub :used 10000 :elapsed-seconds 3600)))

(test strategic-route-never-general
  (is-false (hngh.plugins.quota-spreader:quota-general-ok-p
             'frontier :used 0 :elapsed-seconds 3600)))
