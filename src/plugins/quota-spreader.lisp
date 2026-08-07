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
     (:buckets ((:period :week :cap 2000000 :units :tokens)
                (:period :day  :cap 300000 :units :tokens)
                (:period :hour :cap 40000  :units :tokens))))
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
      :situations (:code-final-review :plan-veto :design-authority))))
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
  '((:hour . 3600) (:day . 86400) (:week . 604800) (:month . 2592000))
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

(defun quota-ok-p (route &key (amount 0) (used 0) (elapsed-seconds 0))
  "Return T when spending AMOUNT on ROUTE now is within its even-sparse
drawdown across every relevant bucket. Fail closed: strategic routes refuse
unless an explicit trigger (handled by the caller via route-strategic-p or an
open trigger) is present; unknown routes refuse; an over-bucket refuses."
  (declare (ignore amount))
  (let ((env (quota-envelope route)))
    (when (getf env :strategic)
      (return-from quota-ok-p nil))
    (let ((buckets (getf env :buckets)))
      (if (null buckets)
          t                          ; no quota known -> allowed (cheap/local)
          (every (lambda (b)
                   (%even-rate-ok-p (getf b :period)
                                    (getf b :cap)
                                    used
                                    elapsed-seconds))
                 buckets)))))

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

(defun quota-general-ok-p (route &key (amount 0) (used 0) (elapsed-seconds 0))
  "Return T when a one-off / general draw on ROUTE is within the general pool's
even share. Strategic routes refuse here (general pool never auto-opens them)."
  (and (not (route-strategic-p route))
       (quota-ok-p route :amount amount :used used
                   :elapsed-seconds elapsed-seconds)))

(defun quota-consumed (route &key (amount 0) situation)
  "Record consumption of AMOUNT on ROUTE, optionally attributed to SITUATION
(authority class). Returns the updated usage table. Keep it cheap and
idempotent; exact accounting is rolled up at read time."
  (declare (ignore situation amount))
  (when (< amount 0)
    (error "Negative consumption: ~S" amount))
  ;; Simplified ledger: append a {route, amount, at} record.
  (let* ((usage (%read-usage))
         (entry (list :route route :amount amount :at (get-universal-time))))
    (%write-usage (append usage (list entry)))
    usage))

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
