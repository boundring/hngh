;;;; src/plugins/quota-spreader.lisp — Per-route quota envelopes + even-sparse
;;;; drawdown + recurring-authority reservations + strategic reserve.
;;;;
;;;; Design: docs/design/quota-spreader.md.
;;;; Every knob is config-first (code defaults, user-overridable via
;;;; ~/.hngh/quotas.lisp); expensive/authority routes are a strategic reserve
;;;; reached only by explicit trigger, never by default or accident.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.quota-spreader)

(defvar *running* nil
  "Whether the quota-spreader plugin is active.")

(defparameter *quotas-path* "quotas.lisp"
  "State-store relative path of the merged (defaults + overrides) envelope
configuration.")

(defparameter *quota-usage-path* "quota-usage.lisp"
  "State-store relative path of recorded per-route consumption.")

;;; --- Configuration (config-first, defaults second) ------------------------

(defparameter *route-defaults*
  '((kimi-sub
     (:buckets ((:period :five-hour :cap :unknown :units :tokens)
                (:period :week :cap 2000000 :units :tokens)
                (:period :day  :cap 300000 :units :tokens)
                (:period :hour :cap 40000  :units :tokens)
                (:period :month :cap 8000000 :units :tokens))))
    (frontier
     (:strategic t
      :buckets ((:period :week :cap 5.0 :units :cents))))
    (anthropic
     (:strategic t
      :buckets ((:period :week :cap 7.0 :units :cents)))))
  "Conservative code defaults per route. :STRATEGIC routes are the expensive
reserve — refused unless an explicit trigger opens them. Values are
rubrics; every field is overridable via ~/.hngh/quotas.lisp.")

(defparameter *reservation-defaults*
  '((kimi-authority
   (:route kimi-sub :cap 333000 :units :tokens :even-over 7
    :situations (:code-final-review :plan-veto :design-author
                  :sanity-review))))
  "Code defaults for recurring-authority reservations. Each reservation is a
situation-CLASS name mapped to a route + cap; the class stays available all
period via even drawdown and never spills into the general pool.")

(defparameter *sparse-defaults*
  '(:safety-margin 0.9      ; spend up to 90% of even-rate projection
    :cheapest-capable 0.75) ; escalation threshold (cheapest wins below this)
  "Sparse-rule defaults: even-drawdown safety margin and the cheapest-capable
escalation threshold.")

(defvar *overrides* nil
  "Parsed user overrides from ~/.hngh/quotas.lisp (state key quotas-override).")

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the quota-spreader plugin and load overrides."
  (declare (ignore hngh-home))
  (setf *running* t)
  (handler-case
      (setf *overrides* (hngh.core.state-store:read-state "quotas-override"))
    (error () (setf *overrides* nil)))
  (hngh.core:log-info "Quota spreader initialized")
  t)

(defun shutdown ()
  "Shut down the quota-spreader plugin."
  (setf *running* nil)
  t)

(defun running-p ()
  "Return T when the quota-spreader plugin is active."
  *running*)

(defun status ()
  "Return a one-line status summary."
  (if *running*
      "quota-spreader: envelopes loaded (n routes)"
      "quota-spreader: inactive"))

;;; --- Envelope resolution --------------------------------------------------

(defun %route-config (route)
  "Return the merged config plist for ROUTE: user overrides layered on code
defaults. Unknown routes get an empty envelope (no quota knowledge -> fail
closed). Route names are matched by symbol-name (string), so callers in any
package can pass 'frontier and match the plugin's frontier. The stored
default/override is a single plist under the assoc key; we unwrap it so the
caller gets a flat plist, not a one-element list holding one."
  (flet ((find-cell (table)
           (cdr (assoc route table
                       :test (lambda (a b)
                               (string= (symbol-name a) (symbol-name b)))))))
    (let* ((default-pair (find-cell *route-defaults*))
           (override-pair (find-cell (or *overrides* '())))
           ;; Each assoc value is (plist) — unwrap the single plist.
           (defaults (and default-pair (first default-pair)))
           (override (and override-pair (first override-pair)))
           (base (or defaults '())))
      (append base override))))

(defun route-strategic-p (route)
  "Return T when ROUTE is a strategic reserve (expensive, refused by default)."
  (getf (%route-config route) :strategic))

(defun quota-envelope (route)
  "Return the envelope plist for ROUTE: (:route <kw> :strategic <bool> :buckets <list>).
Always returns a plist; unknown routes yield an empty (fail-closed) envelope."
  (let ((cfg (%route-config route)))
    (list :route route
          :strategic (or (getf cfg :strategic) nil)
          :buckets (or (getf cfg :buckets) '()))))

(defun reservations-for (route)
  "Return the list of reservation entries that draw from ROUTE's quota, one
per situation-class. Each entry: (:situation <kw> :cap <n> :units <kw>
:even-over <n>). The defaults group several situations under one named
reservation; we flatten so each situation is independently addressable."
  (loop for (name cell) in (or *reservation-defaults* '())
        when (string= (symbol-name (getf cell :route))
                      (symbol-name route))
          nconc (loop for sit in (getf cell :situations)
                      collect (list :situation sit
                                    :cap (getf cell :cap)
                                    :units (getf cell :units)
                                    :even-over (getf cell :even-over)))))

;;; --- Usage tracking -------------------------------------------------------

(defun %read-usage ()
  "Read the per-route consumption table, or '() when absent/corrupt."
  (handler-case (or (hngh.core.state-store:read-state *quota-usage-path*) '())
    (error () '())))

(defun %write-usage (usage)
  "Persist the per-route consumption table."
  (hngh.core.state-store:write-state *quota-usage-path* usage))

(defparameter *period-seconds*
  '((:five-hour . 18000) (:hour . 3600) (:day . 86400)
    (:week . 604800) (:month . 2592000))
  "Nominal period durations in seconds.")

(defun %period-duration (period)
  "Return the nominal SECONDS for a PERIOD keyword, or 1 if unknown."
  (or (cdr (assoc period *period-seconds*)) 1))

(defun %even-rate-ok-p (period cap used elapsed-seconds)
  "Return T when USED stays at/below the even-sparse projection for the
portion of PERIOD that has ELAPSED-SECONDS. Even rate: by the time fraction
f = elapsed/period has passed, you should have used at most f * cap (with a
small safety margin, so slight over-use doesn't spuriously block). Fail
closed: unknown period or unusable math treats used > cap as over."
  (let* ((duration (%period-duration period))
         (fraction (min 1.0 (max 0.0 (/ elapsed-seconds duration))))
         (fair (* cap fraction))
         (margin (* fair 1.1)))
    (<= used margin)))


(defun %settled-usage-for-situation (route situation start end)
  "Sum settled actuals for ROUTE/SITUATION within [START, END)."
  (loop for entry in (%read-usage)
        when (and (string= (symbol-name route)
                           (symbol-name (getf entry :route)))
                  (string= (symbol-name situation)
                           (symbol-name (getf entry :situation)))
                  (numberp (getf entry :actual-amount))
                  (numberp (getf entry :at))
                  (>= (getf entry :at) start)
                  (< (getf entry :at) end))
        sum (getf entry :actual-amount)))

(defun %active-reserved-usage-for-situation (route situation reservations
                                              start end)
  "Sum active reservation projections for ROUTE/SITUATION within [START, END)."
  (loop for entry in reservations
        when (and (string= (symbol-name route)
                           (symbol-name (getf entry :route)))
                  (string= (symbol-name situation)
                           (symbol-name (getf entry :situation)))
                  (member (getf entry :status) '(:reserved :unresolved))
                  (numberp (getf entry :created-at))
                  (>= (getf entry :created-at) start)
                  (< (getf entry :created-at) end))
        sum (getf entry :projected-amount)))

(defun quota-reserved-ok-p (route situation &key (amount 0) (used 0))
  "Return T when AMOUNT plus the authority class's settled actuals and active
reservations stays within SITUATION's even share of ROUTE's reservation over
its even-over window, paced from the route's :week reset anchor (elapsed is
clamped to the window). USED is retained only as an explicit test offset;
production callers omit it. Reservations never spill into the general pool
(caller enforces that separation). Situation names are matched by symbol-name,
so callers in any package can pass 'code-final-review."
  (let* ((res (find situation (reservations-for route)
                    :key (lambda (r) (getf r :situation))
                    :test (lambda (a b)
                            (string= (symbol-name a) (symbol-name b)))))
         (cap (and res (getf res :cap))))
    ;; No reservation for this situation -> not an authority draw (general pool).
    (if (null cap)
        nil
        (let* ((even-over (or (getf res :even-over) 1))
               (window (* even-over 86400))
               (now (get-universal-time))
               (anchor-entry (%anchor-for route :week (%read-anchors)))
               (start (if anchor-entry
                          (getf anchor-entry :anchor)
                          (- now window)))
               (elapsed (max 0 (min window (- now start))))
               (fraction (min 1.0 (max 0.0 (/ elapsed window))))
               (share (* cap fraction 1.1))
               (settled (%settled-usage-for-situation
                         route situation start (+ start window)))
               (reserved (%active-reserved-usage-for-situation
                          route situation (%read-reservations)
                          start (+ start window)))
               (drawn (+ settled reserved amount (or used 0))))
          (<= drawn share)))))


(defun quota-available-p (route &key (used 0) (elapsed-seconds 0)
                                  (amount 0))
  "Return T when ROUTE has room for AMOUNT under its even-rate envelope."
  (quota-ok-p route :amount amount :used used :elapsed-seconds elapsed-seconds))

(defun quota-status (route &key (used 0) (elapsed-seconds 0))
  "Return a readable route availability status for planner/watchers."
  (let ((available (quota-available-p route :used used
                                      :elapsed-seconds elapsed-seconds)))
    (format nil "~A: ~A (used=~A elapsed=~A)"
            route (if available "available-now" "over-even-rate")
            used elapsed-seconds)))

(defun quota-general-ok-p (route &key (amount 0) (used 0) (elapsed-seconds :derive))
  "Return T when a one-off / general draw on ROUTE is within the general pool's
live even-rate envelope. Strategic routes refuse here (general pool never
auto-opens them)."
  (and (not (route-strategic-p route))
       (quota-ok-p route :amount amount :used used
                   :elapsed-seconds elapsed-seconds)))

(defun %read-anchors ()
  "Read the per-route reset-anchor table, or '() when absent/corrupt."
  (handler-case (or (hngh.core.state-store:read-state "quota-anchors") '())
    (error () '())))

(defun %write-anchors (anchors)
  "Persist the per-route reset-anchor table."
  (hngh.core.state-store:write-state "quota-anchors" anchors))

(defun %anchor-for (route period anchors)
  (find-if (lambda (entry)
             (and (string= (symbol-name route)
                           (symbol-name (getf entry :route)))
                  (eql period (getf entry :period))))
           anchors))

(defun %bucket-elapsed (route period now)
  "Elapsed seconds into PERIOD for ROUTE, derived from the bucket's reset
anchor and clamped to [0, DURATION). A missing anchor fails closed to 0
(fresh window, no pacing credit). Never caller-supplied."
  (let* ((duration (%period-duration period))
         (entry (%anchor-for route period (%read-anchors)))
         (anchor (and entry (getf entry :anchor))))
    (if (numberp anchor)
        (max 0 (min duration (- now anchor)))
        0)))

(defun %advance-resets-under-lock (route now)
  (let ((anchors (%read-anchors))
        (changed nil))
    (dolist (bucket (getf (quota-envelope route) :buckets))
      (let* ((period (getf bucket :period))
             (entry (%anchor-for route period anchors))
             (duration (%period-duration period)))
        (if (null entry)
            (progn
              (push (list :route route :period period :anchor now) anchors)
              (setf changed t))
            (let ((anchor (getf entry :anchor)))
              (when (and (numberp anchor)
                         (>= now (+ anchor duration)))
                (setf (getf entry :anchor)
                      (+ anchor (* duration
                                   (1+ (floor (- now anchor) duration)))))
                (setf changed t))))))
    (when changed
      (%write-anchors anchors))
    changed))

(defun maybe-advance-reset (route)
  "Advance every bucket reset anchor for ROUTE independently of bucket order."
  (%with-quota-lock
   (lambda ()
     (%advance-resets-under-lock route (get-universal-time)))))

;;; --- Card 128 authoritative settlement ------------------------------------

(defparameter *quota-reservations-path* "quota-reservations.lisp")
(defparameter *quota-lock-holder* "quota-spreader")

(defun %number-p (value)
  (and (numberp value) (not (minusp value))))

(defun %known-buckets-p (buckets)
  (and buckets
       (every (lambda (bucket)
               (and (keywordp (getf bucket :period))
                    (%number-p (getf bucket :cap))
                    (keywordp (getf bucket :units))))
             buckets)))

(defun %read-reservations ()
  (handler-case
      (or (hngh.core.state-store:read-state *quota-reservations-path*) '())
    (error () nil)))

(defun %write-reservations (reservations)
  (hngh.core.state-store:write-state *quota-reservations-path* reservations))

(defun %with-quota-lock (thunk)
  (if (hngh.core.state-store:acquire-lock
       "quota-reservations" :holder *quota-lock-holder* :ttl 60)
      (unwind-protect
           (funcall thunk)
        (hngh.core.state-store:release-lock
         "quota-reservations" :holder *quota-lock-holder*))
      nil))

(defun %reservation-by-id (id reservations)
  (find id reservations :key (lambda (entry) (getf entry :reservation-id))
        :test #'equal))

(defun %actual-usage (route period now)
  (let* ((anchors (%read-anchors))
         (anchor-entry (%anchor-for route period anchors))
         (start (if anchor-entry
                    (getf anchor-entry :anchor)
                    (- now (%period-duration period)))))
    (loop for entry in (%read-usage)
          when (and (string= (symbol-name route)
                             (symbol-name (getf entry :route)))
                    (numberp (getf entry :actual-amount))
                    (numberp (getf entry :at))
                    (>= (getf entry :at) start)
                    (< (getf entry :at) (+ start (%period-duration period))))
          sum (getf entry :actual-amount))))

(defun %active-reserved-usage (route period reservations now)
  (let ((anchor-entry (%anchor-for route period (%read-anchors)))
        (start (- now (%period-duration period))))
    (when anchor-entry
      (setf start (getf anchor-entry :anchor)))
    (loop for entry in reservations
          when (and (string= (symbol-name route)
                             (symbol-name (getf entry :route)))
                    (member (getf entry :status) '(:reserved :unresolved))
                    (numberp (getf entry :created-at))
                    (>= (getf entry :created-at) start)
                    (< (getf entry :created-at)
                       (+ start (%period-duration period))))
          sum (getf entry :projected-amount))))

(defun %route-blocked-p (route reservations now)
  (some (lambda (entry)
          (and (string= (symbol-name route)
                        (symbol-name (getf entry :route)))
               (member (getf entry :status) '(:unresolved :overage))
               (< now (or (getf entry :blocked-until) most-positive-fixnum))))
        reservations))

(defun %admission-amount-ok-p (route amount elapsed-seconds &optional used)
  (let ((buckets (getf (quota-envelope route) :buckets))
        (now (get-universal-time)))
    (and (%number-p amount)
         (%known-buckets-p buckets)
         (every (lambda (bucket)
                  (let* ((period (getf bucket :period))
                         (cap (getf bucket :cap))
                         (settled (%actual-usage route period now))
                         (reserved (%active-reserved-usage
                                    route period (%read-reservations) now))
                         (total (+ settled reserved amount
                                   (or used 0))))
                    (and (<= total cap)
                         (%even-rate-ok-p period cap total elapsed-seconds))))
                buckets))))

(defun quota-reserve (route situation &key reservation-id (amount 0)
                                             (elapsed-seconds 0))
  "Atomically reserve a projected call amount, keyed by RESERVATION-ID."
  (unless (and reservation-id
               (member situation (getf (first (reservations-for route)) :situations)
                       :test (lambda (a b) (string= (symbol-name a)
                                                    (symbol-name b)))))
    (unless (find situation (reservations-for route)
                  :key (lambda (entry) (getf entry :situation))
                  :test (lambda (a b) (string= (symbol-name a)
                                                (symbol-name b))))
      (return-from quota-reserve nil)))
  (%with-quota-lock
   (lambda ()
     (let* ((now (get-universal-time))
            (reservations (%read-reservations))
            (existing (%reservation-by-id reservation-id reservations))
            (buckets (getf (quota-envelope route) :buckets)))
       (when (or (not (%known-buckets-p buckets))
                 (not (%number-p amount)))
         (return-from quota-reserve nil))
       (when existing
         (return-from quota-reserve
           (and (equal route (getf existing :route))
                (equal situation (getf existing :situation))
                (= amount (getf existing :projected-amount))
                existing)))
       (when (%route-blocked-p route reservations now)
        (return-from quota-reserve nil))
      (%advance-resets-under-lock route now)
      (unless (%admission-amount-ok-p route amount elapsed-seconds)
        (return-from quota-reserve nil))
      (let ((entry (list :reservation-id reservation-id
                         :route route :situation situation
                         :projected-amount amount :actual-amount nil
                         :status :reserved :created-at now)))
        (%write-reservations (append reservations (list entry)))
        entry)))))

(defun quota-settle (reservation-id &key actual-amount provider-response-id)
  "Settle a reservation with provider-measured usage, fail-closed on absence."
  (%with-quota-lock
   (lambda ()
     (let* ((reservations (%read-reservations))
            (entry (%reservation-by-id reservation-id reservations)))
       (unless entry (return-from quota-settle nil))
       (when (member (getf entry :status) '(:settled :overage))
         (return-from quota-settle entry))
       (unless (%number-p actual-amount)
         (setf (getf entry :status) :unresolved)
         (%write-reservations reservations)
         (return-from quota-settle nil))
       (let* ((route (getf entry :route))
              (now (get-universal-time))
              (projected (getf entry :projected-amount))
              (overage (> actual-amount projected))
              (status (if overage :overage :settled))
              (updated (list :reservation-id reservation-id
                             :route route
                             :situation (getf entry :situation)
                             :projected-amount projected
                             :actual-amount actual-amount
                             :provider-response-id provider-response-id
                             :status status :settled-at now
                             :blocked-until
                             (and overage (+ now (%period-duration :five-hour))))))
         (%write-usage
          (append (%read-usage)
                  (list (list :route route
                              :situation (getf entry :situation)
                              :amount actual-amount
                              :actual-amount actual-amount
                              :units :tokens :at now
                              :reservation-id reservation-id))))
         (%write-reservations
          (mapcar (lambda (item)
                    (if (equal reservation-id (getf item :reservation-id))
                        updated
                        item))
                  reservations))
         updated)))))

(defun %quota-state-ready-p ()
  (hngh.core.state-store:running-p))

(defun %quota-ok-under-lock (route &key (amount 0) (elapsed-seconds :derive))
  (let ((buckets (getf (quota-envelope route) :buckets))
        (now (get-universal-time)))
    (and (not (route-strategic-p route))
         (%known-buckets-p buckets)
         (not (%route-blocked-p route (%read-reservations) now))
         (every (lambda (bucket)
                  (let* ((period (getf bucket :period))
                         (cap (getf bucket :cap))
                         (elapsed (if (eq elapsed-seconds :derive)
                                      (%bucket-elapsed route period now)
                                      elapsed-seconds))
                         (settled (%actual-usage route period now))
                         (reserved (%active-reserved-usage
                                    route period (%read-reservations) now))
                         (total (+ settled reserved amount)))
                    (and (<= total cap)
                         (%even-rate-ok-p period cap total elapsed))))
                buckets))))

(defun quota-ok-p (route &key (amount 0) (used 0) (elapsed-seconds :derive))
  "Return T only when current ledger and active reservations admit AMOUNT.
USED is retained only as an explicit test offset; production callers omit it.
ELAPSED-SECONDS is an internal test seam only (:derive by default); pacing is
never caller-controlled under the lock."
  (and (%quota-state-ready-p)
       (%with-quota-lock
        (lambda ()
          (%advance-resets-under-lock route (get-universal-time))
          (and (or (zerop used)
                   (%number-p used))
               (%quota-ok-under-lock route :amount (+ amount used)
                                     :elapsed-seconds elapsed-seconds))))))

(defun should-route-to-k3-p (situation &key (used 0) (elapsed-seconds :derive)
                                      (amount 0))
  "Return T only when authority SITUATION has live ledger headroom, paced by
the ledger and the bucket reset anchors under the lock. Caller USED and
ELAPSED-SECONDS are never production authority: the reservation share and the
even-rate envelope derive from ledger/reservation truth and the anchors."
  (declare (ignore used elapsed-seconds))
  (and (%quota-state-ready-p)
       (%with-quota-lock
        (lambda ()
          (%advance-resets-under-lock 'kimi-sub (get-universal-time))
          (and (member situation '(:code-final-review :plan-veto :design-authority
                                   :sanity-review)
                       :test #'string-equal :key #'symbol-name)
               (quota-reserved-ok-p 'kimi-sub situation :amount amount)
               (%quota-ok-under-lock 'kimi-sub :amount amount))))))

(defun quota-consumed (route &key (amount 0) situation actual-amount
                                      provider-response-id reservation-id)
  "Record measured consumption; caller projections are never accounting truth."
  (let ((measured (or actual-amount amount)))
    (unless (%number-p measured)
      (error "Invalid measured consumption: ~S" measured))
    (if reservation-id
        (quota-settle reservation-id :actual-amount measured
                      :provider-response-id provider-response-id)
        (%with-quota-lock
         (lambda ()
           (let ((entry (list :route route :situation situation
                              :amount measured :actual-amount measured
                              :units :tokens :at (get-universal-time))))
             (%write-usage (append (%read-usage) (list entry)))
             entry))))))
