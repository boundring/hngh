(defpackage #:hngh.domain
  (:use #:cl)
  (:export #:validate-profile
           #:mission
           #:make-mission
           #:mission-objective
           #:mission-writable-scopes
           #:role-template
           #:make-role-template
           #:role-template-name
           #:loadout
           #:make-loadout
           #:loadout-route-label
           #:loadout-time-limit
           #:run
           #:make-run
           #:run-state
           #:allowed-transition-p
           #:advance-run
           #:invalid-run-transition
           #:receipt
           #:make-receipt
           #:score-record
           #:make-score-record
           #:afterlife-record
           #:make-afterlife-record))

(defpackage #:hngh
  (:use #:cl)
  (:import-from #:hngh.domain #:validate-profile)
  (:export #:validate-profile))

(defpackage #:hngh.tests
  (:use #:cl))
