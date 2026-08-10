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
    ;; The five-hour cap is intentionally unresolved until operator config.
    (let ((buckets (getf env :buckets)))
      (is (= 5 (length buckets)))
      (is (eql :five-hour (getf (first buckets) :period)))
      (is (eql :unknown (getf (first buckets) :cap)))
      (is (= 8000000 (getf (fifth buckets) :cap)))
      (is (eql :month (getf (fifth buckets) :period))))))

(test k3-driver-routes-authority-situations
  (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
            :code-final-review :used 0 :elapsed-seconds 3600))
  (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
            :plan-veto :used 0 :elapsed-seconds 3600))
  (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
             :tool-preview :used 0 :elapsed-seconds 3600))
  (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
             :code-final-review :used 400000 :elapsed-seconds 3600)))

(test k3-driver-surfaces-availability
  ;; Automatic admission is unavailable until the five-hour cap resolves.
  (is-false (hngh.plugins.quota-spreader:quota-available-p
             'kimi-sub :used 0 :elapsed-seconds 3600))
  (is (search "over-even-rate"
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

(test unlisted-situation-has-no-reservation
  ;; A situation with no reservation is not an authority draw (general pool).
  (is-false (hngh.plugins.quota-spreader:quota-reserved-ok-p
             'kimi-sub 'tool-preview :used 10)))

;;; --- Strategic one-off vs general pool ------------------------------------

(test general-pool-one-off-ok-on-quota-route
  ;; Unknown five-hour cap refuses automatic admission.
  (is-false (hngh.plugins.quota-spreader:quota-general-ok-p
            'kimi-sub :used 10000 :elapsed-seconds 3600)))

(test strategic-route-never-general
  (is-false (hngh.plugins.quota-spreader:quota-general-ok-p
             'frontier :used 0 :elapsed-seconds 3600)))

;;; --- Card 128 settlement and reservation contract -------------------------

(defmacro with-quota-fixture ((tmp-var) &body body)
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (let ((hngh:*hngh-home* ,tmp-var)
           (hngh.plugins.quota-spreader:*route-defaults*
             '((kimi-sub
                (:buckets ((:period :five-hour :cap 100 :units :tokens)
                           (:period :week :cap 1000 :units :tokens)
                           (:period :month :cap 10000 :units :tokens))))))
           (hngh.plugins.quota-spreader:*reservation-defaults*
             '((kimi-authority
                (:route kimi-sub :cap 100 :units :tokens :even-over 7
                 :situations (:code-final-review :plan-veto
                               :design-authority :sanity-review)))))
           (hngh.plugins.quota-spreader:*overrides* nil))
       (hngh.core.state-store:init :hngh-home ,tmp-var)
       (unwind-protect
            (progn ,@body)
         (hngh.core.state-store:shutdown)
         (cleanup-tmp-home ,tmp-var)))))

(test reservation-within-cap-is-ok
  ;; Full even-over window elapsed: the whole reserved cap share is available.
  (with-quota-fixture (tmp)
    (let ((now (get-universal-time)))
      (hngh.core.state-store:write-state
       "quota-anchors"
       (list (list :route 'kimi-sub :period :week :anchor (- now 604800))))
      (is-true (hngh.plugins.quota-spreader:quota-reserved-ok-p
                'kimi-sub 'code-final-review :amount 50)))))

(test reservation-over-cap-refuses
  ;; Even at full window the 1.1 margin caps the share; amount over it refuses.
  (with-quota-fixture (tmp)
    (let ((now (get-universal-time)))
      (hngh.core.state-store:write-state
       "quota-anchors"
       (list (list :route 'kimi-sub :period :week :anchor (- now 604800))))
      (is-false (hngh.plugins.quota-spreader:quota-reserved-ok-p
                 'kimi-sub 'code-final-review :amount 200)))))

(test card-128-authoritative-settlement-writes-actual-before-next-admission
  (with-quota-fixture (tmp)
    (let ((first (hngh.plugins.quota-spreader::quota-reserve
                  'kimi-sub :sanity-review
                  :reservation-id "call-a" :amount 10
                  :elapsed-seconds 18000)))
      (is-true first)
      (is-true (hngh.plugins.quota-spreader::quota-settle
                "call-a" :actual-amount 90
                :provider-response-id "provider-a"))
      (is-false (hngh.plugins.quota-spreader::quota-reserve
                 'kimi-sub :sanity-review
                 :reservation-id "call-b" :amount 1
                 :elapsed-seconds 18000)))))

(test card-128-actual-over-projection-exhausts-coupled-windows
  (with-quota-fixture (tmp)
    (is-true (hngh.plugins.quota-spreader::quota-reserve
              'kimi-sub :plan-veto
              :reservation-id "call-overage" :amount 10
              :elapsed-seconds 18000))
    (let ((settled (hngh.plugins.quota-spreader::quota-settle
                    "call-overage" :actual-amount 90)))
      (is-true settled)
      (is (eq :overage (getf settled :status)))
      (is-true (getf settled :actual-amount)))
    (is-false (hngh.plugins.quota-spreader::quota-reserve
               'kimi-sub :plan-veto
               :reservation-id "call-after-overage" :amount 1
               :elapsed-seconds 18000))))

(test card-128-missing-measurement-refuses-further-admission
  (with-quota-fixture (tmp)
    (is-true (hngh.plugins.quota-spreader::quota-reserve
              'kimi-sub :code-final-review
              :reservation-id "call-missing" :amount 10
              :elapsed-seconds 18000))
    (is-false (hngh.plugins.quota-spreader::quota-settle
               "call-missing" :actual-amount nil))
    (is-false (hngh.plugins.quota-spreader::quota-reserve
               'kimi-sub :code-final-review
               :reservation-id "call-after-missing" :amount 1
               :elapsed-seconds 18000))))

(test card-128-reservation-idempotency-and-lock-contention
  (with-quota-fixture (tmp)
    (let ((first (hngh.plugins.quota-spreader::quota-reserve
                  'kimi-sub :sanity-review
                  :reservation-id "same-call" :amount 10
                  :elapsed-seconds 18000)))
      (is-true first)
      (is (equal first
                 (hngh.plugins.quota-spreader::quota-reserve
                  'kimi-sub :sanity-review
                  :reservation-id "same-call" :amount 10
                  :elapsed-seconds 18000)))
      (is-false (hngh.plugins.quota-spreader::quota-reserve
                 'kimi-sub :sanity-review
                 :reservation-id "same-call" :amount 11
                 :elapsed-seconds 18000)))
    (is-true (hngh.core.state-store:acquire-lock
              "quota-reservations" :holder "other-seat" :ttl 60))
    (unwind-protect
         (is-false (hngh.plugins.quota-spreader::quota-reserve
                    'kimi-sub :sanity-review
                    :reservation-id "blocked-call" :amount 1
                    :elapsed-seconds 18000))
      (hngh.core.state-store:release-lock
       "quota-reservations" :holder "other-seat"))))

(test card-128-public-predicate-uses-settled-ledger
  (with-quota-fixture (tmp)
    (is-true (hngh.plugins.quota-spreader::quota-reserve
              'kimi-sub :sanity-review
              :reservation-id "public-a" :amount 10
              :elapsed-seconds 18000))
    (is-true (hngh.plugins.quota-spreader::quota-settle
              "public-a" :actual-amount 90))
    ;; Caller :used is ignored by the public K3 predicate; settled actuals win.
    (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
               :sanity-review :used 0 :amount 1
               :elapsed-seconds 18000))))

(test card-128-actual-usage-is-window-specific
  (with-quota-fixture (tmp)
    (let* ((now (get-universal-time))
           (usage (list (list :route 'kimi-sub :actual-amount 90
                              :at (- now 100) :units :tokens)
                        (list :route 'kimi-sub :actual-amount 90
                              :at (- now 40000) :units :tokens))))
      (hngh.core.state-store:write-state "quota-usage.lisp" usage)
      (is (= 90
             (hngh.plugins.quota-spreader::%actual-usage
              'kimi-sub :five-hour now)))
      (is (= 180
             (hngh.plugins.quota-spreader::%actual-usage
              'kimi-sub :week now))))))

(test card-128-reset-anchors-are-per-bucket
  (with-quota-fixture (tmp)
    (let ((now (get-universal-time)))
      (hngh.core.state-store:write-state
       "quota-anchors"
       (list (list :route 'kimi-sub :period :week
                   :anchor (- now 604800))
             (list :route 'kimi-sub :period :five-hour
                   :anchor (- now 10))))
      (is-true (hngh.plugins.quota-spreader:maybe-advance-reset 'kimi-sub))
      (let ((anchors (hngh.core.state-store:read-state "quota-anchors")))
        (is-true (find :week anchors :key (lambda (entry) (getf entry :period))))
        (is (= (- now 10)
               (getf (find :five-hour anchors
                           :key (lambda (entry) (getf entry :period)))
                     :anchor)))))))

(test card-128-reserve-advances-stale-bucket-before-admission
  ;; Seu seam: quota-reserve must run %advance-resets-under-lock BEFORE the
  ;; admission math, exactly like both public paths do. A five-hour anchor
  ;; left 3 periods in the past keeps the prior period's burn inside the
  ;; window; the reserve must roll the anchor so old burn can't block a
  ;; fresh current-period spend.
  (with-quota-fixture (tmp)
    (let ((now (get-universal-time)))
      ;; Stale five-hour anchor (3 periods back) + an old-period burn of 1000
      ;; tokens. Month cap is 10000 and week cap 1000, so the only thing that
      ;; can block a 10-token fresh reserve is the stale five-hour window
      ;; still counting the old burn against cap 100.
      (hngh.core.state-store:write-state
       "quota-anchors"
       (list (list :route 'kimi-sub :period :five-hour
                   :anchor (- now 54000))))
      (hngh.core.state-store:write-state
       "quota-usage.lisp"
       (list (list :route 'kimi-sub :actual-amount 1000
                   :units :tokens :at (- now 50000))))
      (is-true (hngh.plugins.quota-spreader::quota-reserve
                'kimi-sub :sanity-review
                :reservation-id "fresh-window" :amount 10
                :elapsed-seconds 18000))
      ;; And the reserve must have advanced the anchor out of the past.
      (let ((anchor (getf (find :five-hour
                                (hngh.core.state-store:read-state
                                 "quota-anchors")
                                :key (lambda (entry)
                                       (getf entry :period)))
                          :anchor)))
        (is (numberp anchor))
        (is (>= anchor now))))))

(test card-128-caller-elapsed-cannot-alter-public-admission
  ;; Seu BLOCK: should-route-to-k3-p must not let caller pacing inflate
  ;; admission. Caller :elapsed-seconds (and :used) are never authority;
  ;; pacing is derived from the reset anchors under the lock.
  (with-quota-fixture (tmp)
    ;; Fresh window: five-hour anchor is set at NOW, so derived elapsed ~ 0
    ;; and the even-rate envelope refuses a spend. A caller-supplied elapsed
    ;; of a full period must NOT flip that to YES.
    (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
               :sanity-review :amount 10 :used 0
               :elapsed-seconds 18000))
    (is-false (hngh.plugins.quota-spreader:should-route-to-k3-p
               :sanity-review :amount 10 :used 0
               :elapsed-seconds 9999999999))))

(test card-128-reservation-amount-and-share-can-refuse
  ;; Seu BLOCK: quota-reserved-ok-p must enforce the reservation's even
  ;; share against AMOUNT plus ledger and reservation truth, not a
  ;; caller-supplied flat :used against cap * 0.9.
  (with-quota-fixture (tmp)
    (let ((now (get-universal-time)))
      ;; Week anchor 3.5 days back: exactly half the 7-day even-over window,
      ;; so the paced share = 100 * 0.5 * 1.1 = 55.
      (hngh.core.state-store:write-state
       "quota-anchors"
       (list (list :route 'kimi-sub :period :week
                   :anchor (- now 302400))))
      ;; Reserve and settle a call that consumed 40 of the 100-cap share.
      (is-true (hngh.plugins.quota-spreader::quota-reserve
                'kimi-sub :sanity-review
                :reservation-id "share-a" :amount 10
                :elapsed-seconds 18000))
      (is-true (hngh.plugins.quota-spreader::quota-settle
                "share-a" :actual-amount 40))
      ;; 40 settled + 20 projected = 60 > 55 -> the reservation itself refuses.
      (is-false (hngh.plugins.quota-spreader:quota-reserved-ok-p
                 'kimi-sub :sanity-review :amount 20))
      ;; 40 + 10 projected = 50 <= 55 -> still inside the share.
      (is-true (hngh.plugins.quota-spreader:quota-reserved-ok-p
                'kimi-sub :sanity-review :amount 10)))))
