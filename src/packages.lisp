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
           #:run-identifier
           #:run-mission
           #:run-role
           #:run-loadout
           #:run-state
           #:allowed-transition-p
           #:advance-run
           #:invalid-run-transition
           #:receipt
           #:make-receipt
           #:receipt-kind
           #:receipt-facts
           #:score-record
           #:make-score-record
           #:afterlife-record
           #:make-afterlife-record
           #:validate-proposal-class
           #:validate-principle-identifier
           #:validate-failure-category
           #:validate-failure-disposition
           #:validate-evidence-requirement-kind
           #:+admitted-transports+
           #:source-manifest-entry
           #:source-manifest-entry-p
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
           #:principle-result-p
           #:make-principle-result
           #:principle-result-principle
           #:principle-result-state
           #:principle-result-evidence-fingerprints
           #:policy-verdict
           #:policy-verdict-p
           #:make-policy-verdict
           #:policy-verdict-state
           #:policy-verdict-principle-results
           #:policy-verdict-reason-labels
           #:evidence-requirement
           #:make-evidence-requirement
           #:evidence-requirement-principle
           #:evidence-requirement-kind
           #:evidence-requirement-required-fingerprints
           #:evidence-requirement-evidence-facts
           #:policy-proposal
           #:make-policy-proposal
           #:policy-proposal-class
           #:policy-proposal-problem
           #:policy-proposal-outcome
           #:policy-proposal-purpose
           #:policy-proposal-caller
           #:policy-proposal-input-contract
           #:policy-proposal-output-contract
           #:policy-proposal-failure-contract
           #:policy-proposal-declared-capabilities
           #:policy-proposal-capability-diff
           #:policy-proposal-source-manifest
           #:policy-proposal-risk-note
           #:policy-proposal-dependency
           #:policy-proposal-evidence-trigger
           #:policy-proposal-evidence-requirements
           #:evaluate-policy-proposal
           #:evaluate-failure-disposition
           #:validate-certificate-action
           #:candidate-certificate
           #:make-candidate-certificate
           #:candidate-certificate-p
           #:candidate-certificate-action
           #:candidate-certificate-repository-identity
           #:candidate-certificate-base-revision
           #:candidate-certificate-candidate-paths
           #:candidate-certificate-content-hash
           #:candidate-certificate-evidence-hashes
           #:candidate-certificate-principle-verdicts
           #:candidate-certificate-review-findings
           #:candidate-certificate-source-manifest
           #:candidate-certificate-policy-profile
           #:candidate-certificate-expiry
           #:issue-candidate-certificate
           ;; distributed attestation (src/domain/attestation.lisp)
           #:remote-attestation
           #:remote-attestation-p
           #:make-remote-attestation
           #:remote-attestation-peer
           #:remote-attestation-key-identifier
           #:remote-attestation-payload
           #:remote-attestation-signature
           #:remote-attestation-claims
           #:remote-attestation-not-before
           #:remote-attestation-not-after
           #:remote-attestation-skew
           #:remote-claim
           #:remote-claim-p
           #:make-remote-claim
           #:remote-claim-kind
           #:remote-claim-fingerprint
           #:verify-attestation-shape
           #:utc-string-p
           #:+remote-claim-kinds+
           ;; pinned-key registry (src/domain/attestation.lisp)
           #:key-pin
           #:key-pin-p
           #:make-key-pin
           #:key-pin-key-identifier
           #:key-pin-key-path
           #:key-pin-algorithm
           #:+key-algorithms+
           #:key-pin-registry
           #:key-pin-registry-p
           #:make-key-pin-registry
           #:lookup-key-pin
           #:key-pin-registry-pins))

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
           #:admit-transport
           #:make-run-start-ports
           #:make-verification-result
           #:verification-result
           #:verification-result-status
           #:verification-result-labels
           #:make-manifest-result
           #:manifest-result
           #:manifest-result-status
           #:manifest-result-labels
           #:make-checkpoint-request
           #:checkpoint-request-run
           #:make-run-checkpoint-ports
           #:create-run
           #:arm-run
           #:start-run
           #:checkpoint
           #:close-request
           #:make-close-request
           #:close-request-run
           #:close-request-target
           #:close-request-proposal
           #:run-close-ports
           #:make-run-close-ports
           #:close-run))

(defpackage #:hngh.adapters.evidence
  (:use #:cl)
  (:export #:+evidence-commands+
           #:evidence-request
           #:evidence-request-p
           #:make-evidence-request
           #:evidence-request-command
           #:evidence-request-targets
           #:evidence-request-source-role
           #:evidence-ports
           #:evidence-ports-p
           #:make-evidence-ports
           #:evidence-result
           #:evidence-result-p
           #:evidence-result-status
           #:evidence-result-facts
           #:evidence-result-manifest
           #:evidence-result-refusal-labels
           #:gather-evidence
           #:process-run))

(defpackage #:hngh.adapters.run-gather
  (:use #:cl)
  (:export #:candidate-gather-ports
           #:make-candidate-gather-ports
           #:parse-candidate-report
           #:run-candidate-evidence))

(defpackage #:hngh.adapters.mutation
  (:use #:cl)
  (:export #:+mutation-actions+
           #:mutation-evidence
           #:mutation-evidence-p
           #:make-mutation-evidence
           #:mutation-evidence-repository-identity
           #:mutation-evidence-base-revision
           #:mutation-evidence-candidate-paths
           #:mutation-evidence-content-hash
           #:mutation-evidence-evidence-hashes
           #:mutation-evidence-principle-verdicts
           #:mutation-evidence-review-findings
           #:mutation-evidence-source-manifest
           #:mutation-evidence-policy-profile
           #:mutation-evidence-now
           #:mutation-ports
           #:mutation-ports-p
           #:make-mutation-ports
           #:mutation-result
           #:mutation-result-p
           #:mutation-result-status
           #:mutation-result-action
           #:mutation-result-command
           #:mutation-result-refusal-labels
           #:mutation-result-exit-code
           #:mutation-result-stdout
           #:mutation-result-stderr
           #:execute-mutation))

(defpackage #:hngh.adapters.review
  (:use #:cl)
  (:export #:review-request
           #:review-request-p
           #:make-review-request
           #:review-request-candidate-paths
           #:review-request-content-hash
           #:review-request-policy-context
           #:review-finding
           #:review-finding-p
           #:review-finding-label
           #:review-finding-citation
           #:review-ports
           #:review-ports-p
           #:make-review-ports
           #:review-result
           #:review-result-p
           #:review-result-status
           #:review-result-findings
           #:review-result-fact
           #:review-result-refusal-labels
           #:request-review
           #:json-escape-string))

(defpackage #:hngh.adapters.model
  (:use #:cl)
  (:export #:make-model-transports
           #:model-request-body
           #:model-response-content))

(defpackage #:hngh.adapters.terminal
  (:use #:cl)
  (:export #:operator-ports
           #:operator-ports-p
           #:make-operator-ports
           #:operator-result
           #:operator-result-p
           #:operator-result-status
           #:operator-result-statement
           #:operator-result-fact
           #:operator-result-refusal-labels
           #:capture-operator-statement
           #:sha256-hex))

(defpackage #:hngh.adapters.filesystem
  (:use #:cl)
  (:export #:filesystem-store
           #:filesystem-store-p
           #:make-filesystem-store
           #:store-record-run
           #:store-entries
           #:store-refusal
           #:transport-fault))

(defpackage #:hngh.adapters.federation
  (:use #:cl)
  (:export #:+federation-methods+
           ;; request
           #:federation-request
           #:federation-request-p
           #:make-federation-request
           #:federation-request-peer
           #:federation-request-method
           #:federation-request-time-window
           #:federation-request-max-facts
           ;; gather ports + result
           #:federation-ports
           #:federation-ports-p
           #:make-federation-ports
           #:federation-result
           #:federation-result-p
           #:federation-result-status
           #:federation-result-facts
           #:federation-result-manifest
           #:federation-result-refusal-labels
           #:gather-federated-evidence
           ;; attestation ports + result
           #:attestation-ports
           #:attestation-ports-p
           #:make-attestation-ports
           #:attestation-result
           #:attestation-result-p
           #:attestation-result-status
           #:attestation-result-verified
           #:attestation-result-key-identifier
           #:attestation-result-fact
           #:attestation-result-refusal-labels
           #:verify-remote-attestation
           #:parse-attestation-envelope
           #:utc-seconds
           ;; pinned-key registry parsing + signature transport (rung 12)
           #:parse-pinned-keys
           #:hex-decode
           #:make-pinned-attestation-ports))

(defpackage #:hngh.presentation
  (:use #:cl)
  (:export #:render
           #:render-run
           #:render-pin-list
           #:render-receipt
           #:render-evidence-fact
           #:render-source-manifest-entry
           #:render-principle-result
           #:render-policy-verdict
           #:render-candidate-certificate
           #:render-application-result
           #:render-evidence-result
           #:render-verification-result
           #:render-manifest-result
           #:render-mutation-result
           #:render-review-result
           #:render-operator-result
           #:render-federation-result
           #:render-attestation-result
           #:render-review-finding
           #:render-report
           #:render-status-label
           #:reference-lexicon-p
           #:render-with-lexicon))

(defpackage #:hngh.main
  (:use #:cl)
  (:export #:run-harness
           #:make-run-harness
           #:harness-create-run
           #:harness-arm-run
           #:harness-start-run
           #:harness-checkpoint
           #:harness-close-run
           #:harness-records
           #:default-evidence-ports
           #:default-mutation-ports
           #:gather-run-evidence
           #:request-run-review
           #:execute-run-mutation
           #:gather-federated-evidence
           #:verify-remote-attestation
           #:harness-admit-transport
           #:dispatch-command
           #:fetch-evidence
           #:verify-attestation
           #:display))

(defpackage #:hngh.tests
  (:use #:cl))
