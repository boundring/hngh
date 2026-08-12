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
           #:make-afterlife-record
           #:validate-proposal-class
           #:validate-principle-identifier
           #:validate-failure-category
           #:validate-failure-disposition
           #:source-manifest-entry
           #:make-source-manifest-entry
           #:source-manifest-entry-relative-path
           #:source-manifest-entry-content-hash
           #:source-manifest-entry-source-role
           #:evidence-fact
           #:make-evidence-fact
           #:evidence-fact-kind
           #:evidence-fact-fingerprint
           #:evidence-fact-state
           #:principle-result
           #:make-principle-result
           #:principle-result-principle
           #:principle-result-state
           #:principle-result-evidence-fingerprints
           #:policy-verdict
           #:make-policy-verdict
           #:policy-verdict-state
           #:policy-verdict-principle-results
           #:policy-verdict-reason-labels))

(defpackage #:hngh
  (:use #:cl)
  (:import-from #:hngh.domain #:validate-profile)
  (:export #:validate-profile))

(defpackage #:hngh.application
  (:use #:cl)
  (:export #:application-result
           #:application-result-p
           #:application-result-status
           #:application-result-run
           #:application-result-receipt
           #:application-result-facts
           #:application-result-labels
           #:make-run-creation-ports
           #:make-admission-facts
           #:admission-facts-authority
           #:admission-facts-ledger
           #:admission-facts-loadout
           #:admission-facts-exclusive-write
           #:make-run-admission-ports
           #:make-run-start-ports
           #:make-verification-result
           #:verification-result-status
           #:verification-result-labels
           #:make-manifest-result
           #:manifest-result-status
           #:manifest-result-labels
           #:make-checkpoint-request
           #:checkpoint-request-run
           #:make-run-checkpoint-ports
           #:create-run
           #:arm-run
           #:start-run
           #:checkpoint))

(defpackage #:hngh.tests
  (:use #:cl))
