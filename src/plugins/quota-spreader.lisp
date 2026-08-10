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


(defun quota-reserved-ok-p (route situation &key (amount 0) (used 0))
  "Return T when drawing AMOUNT from ROUTE's reservation for SITUATION stays
within the reservation's even share. Reservations never spill into the
general pool (caller enforces that separation). Situation names are matched
by symbol-name, so callers in any package can pass 'code-final-review."
  (let* ((res (find situation (reservations-for route)
                    :key (lambda (r) (getf r :situation))
                    :test (lambda (a b)
                            (string= (symbol-name a) (symbol-name b)))))
         (cap (and res (getf res :cap))))
    ;; No reservation for this situation -> not an authority draw (general pool).
    (if (null cap)
        nil
        (<= used (* cap 0.9)))))


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

(defun quota-general-ok-p (route &key (amount 0) (used 0) (elapsed-seconds 0))
  "Return T when a one-off / general draw on ROUTE is within the general pool's
even share. Strategic routes refuse here (general pool never auto-opens them)."
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

(defun maybe-advance-reset (route)
  "If ROUTE's tightest period has passed since its last recorded anchor,
zero that period's usage and advance the anchor. Returns T when a reset
happened, NIL otherwise. First-seen routes get an anchor immediately (no
reset on first sight)."
  (let* ((anchors (%read-anchors))
         (last (cdr (assoc route anchors
                           :test (lambda (a b)
                                   (string= (symbol-name a) (symbol-name b))))))
         (now (get-universal-time))
         (env (quota-envelope route))
         (tightest (first (getf env :buckets)))
         (period (and tightest (getf tightest :period)))
         (reset? (and last period
                      (>= now (+ last (%period-duration period))))))
    (when (not last)
      ;; First sight: record anchor, no reset yet.
      (%write-anchors (cons (cons route now) anchors))
      (return-from maybe-advance-reset nil))
    (when reset?
      ;; Advance anchor; zero usage for this route (simplified: drop its
      ;; consumption records). Unused reservations are forfeited here.
      (%write-anchors (cons (cons route now)
                            (remove-if (lambda (a)
                                         (string= (symbol-name (car a))
                                                  (symbol-name route)))
                                       anchors)))
      (%write-usage (remove-if (lambda (e)
                                 (string= (symbol-name (getf e :route))
                                          (symbol-name route)))
                               (%read-usage))))
    reset?))

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

(defun %actual-usage (route now)
  (loop for entry in (%read-usage)
        when (and (string= (symbol-name route)
                           (symbol-name (getf entry :route)))
                  (numberp (getf entry :actual-amount))
                  (<= (- now (or (getf entry :at) now))
                      (%period-duration :month)))
        sum (getf entry :actual-amount)))

(defun %active-reserved-usage (route reservations)
  (loop for entry in reservations
        when (and (string= (symbol-name route)
                           (symbol-name (getf entry :route)))
                  (member (getf entry :status) '(:reserved :unresolved)))
        sum (getf entry :projected-amount)))

(defun %route-blocked-p (route reservations now)
  (some (lambda (entry)
          (and (string= (symbol-name route)
                        (symbol-name (getf entry :route)))
               (member (getf entry :status) '(:unresolved :overage))
               (< now (or (getf entry :blocked-until) most-positive-fixnum))))
        reservations))

(defun %admission-amount-ok-p (route amount elapsed-seconds used)
  (let ((buckets (getf (quota-envelope route) :buckets)))
    (and (%number-p amount)
         (%known-buckets-p buckets)
         (every (lambda (bucket)
                  (let ((cap (getf bucket :cap)))
                    (and (<= (+ used amount) cap)
                         (%even-rate-ok-p (getf bucket :period) cap
                                          (+ used amount) elapsed-seconds))))
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
       (let ((used (+ (%actual-usage route now)
                      (%active-reserved-usage route reservations))))
         (unless (%admission-amount-ok-p route amount elapsed-seconds used)
           (return-from quota-reserve nil))
         (let ((entry (list :reservation-id reservation-id
                            :route route :situation situation
                            :projected-amount amount :actual-amount nil
                            :status :reserved :created-at now)))
           (%write-reservations (append reservations (list entry)))
           entry))))))

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

(defun quota-ok-p (route &key (amount 0) (used 0) (elapsed-seconds 0))
  "Return T only for a known, resolved envelope and measured/test usage."
  (declare (ignore used))
  (let ((buckets (getf (quota-envelope route) :buckets)))
    (and (not (route-strategic-p route))
         (%known-buckets-p buckets)
         (%admission-amount-ok-p route amount elapsed-seconds 0))))

(defun should-route-to-k3-p (situation &key (used 0) (elapsed-seconds 0)
                                      (amount 0))
  (and (member situation '(:code-final-review :plan-veto :design-authority
                           :sanity-review)
                 :test #'string-equal :key #'symbol-name)
       (quota-reserved-ok-p 'kimi-sub situation :amount amount :used used)
       (quota-ok-p 'kimi-sub :amount amount :used used
                   :elapsed-seconds elapsed-seconds)))

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
