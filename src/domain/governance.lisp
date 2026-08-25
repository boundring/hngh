(in-package #:hngh.domain)

(defun validate-closed-value (value allowed name)
  (unless (member value allowed :test #'eq)
    (error "Unknown ~A: ~S" name value))
  value)

(defun validate-proposal-class (value)
  (validate-closed-value
   value '(:feature :scope-broadening :capability-request
           :failure-disposition :review-request :commit-request :push-request)
   "proposal class"))

;; List-valued vocabularies use defparameter, not defconstant: SBCL evaluates
;; defconstant at compile time and again when the fasl loads, and the two
;; literal objects are not eql, so an ASDF recompile raises
;; DEFCONSTANT-UNEQL. Immutability is enforced by the closed-vocabulary
;; tests, not the Lisp constant mechanism.
(defparameter +matrix-principles+
  '(:closed-authority :least-authority :dependency-direction
    :fail-closed :evidence-before-claim :atomic-mutation :reversibility
    :no-hidden-execution :cost-and-route-discipline :source-grounding))

(defun validate-principle-identifier (value)
  (validate-closed-value value +matrix-principles+ "principle identifier"))

(defparameter +failure-categories+
  '(:domain-policy-or-invariant :application-invariant
    :port-callback-fault-or-malformed-return :atomic-recording-conflict
    :insufficient-or-stale-evidence :tool-or-environment-fault
    :review-disagreement :mutation-precondition-mismatch-or-failure))
(defparameter +admitted-transports+
  '(:filesystem :model :terminal :federation)
  "The closed set of transport kinds a run may be admitted for. :filesystem is the local record transport; :model is the bounded
model-review transport (advisory only, requires a non-local route and
the model-review network label on the run loadout); :terminal is the
bounded operator statement input (advisory only, requires the
terminal-input tool label on the run loadout); :federation is the
bounded remote-evidence / carrier-bundle transport (advisory only,
requires the remote-evidence network label or the carrier-bundle tool
label on the run loadout).")


(defun validate-failure-category (value)
  (validate-closed-value value +failure-categories+ "failure category"))

(defun validate-failure-disposition (value)
  (validate-closed-value
   value '(:propagate-to-test-gate :typed-domain-refusal
           :normalize-to-refusal-at-callback :normalize-to-conflict-without-retry
           :refuse :needs-escalation :stop-and-record-evidence)
   "failure disposition"))

(defparameter +failure-dispositions+
  '((:domain-policy-or-invariant . :propagate-to-test-gate)
    (:application-invariant . :propagate-to-test-gate)
    (:port-callback-fault-or-malformed-return
     . :normalize-to-refusal-at-callback)
    (:atomic-recording-conflict . :normalize-to-conflict-without-retry)
    (:insufficient-or-stale-evidence . :refuse)
    (:tool-or-environment-fault . :refuse)
    (:review-disagreement . :needs-escalation)
    (:mutation-precondition-mismatch-or-failure
     . :stop-and-record-evidence)))

(defun evaluate-failure-disposition (category)
  "Return the closed disposition for a failure category, refusing unknown
categories. The two conditionally worded table rows resolve to their primary
default in this pure policy."
  (validate-failure-category category)
  (or (cdr (assoc category +failure-dispositions+))
      (error "No failure disposition for category: ~S" category)))

(defun validate-evidence-state (value)
  (validate-closed-value value
                         '(:current :stale :missing :malformed :conflicting :unverifiable)
                         "evidence state"))

(defun validate-evidence-requirement-kind (value)
  (validate-closed-value
   value '(:purpose :caller :input-contract :output-contract :failure-contract
           :capability-set :capability-diff :static-source
           :closed-failure-disposition :claim-proof :base-revision
           :candidate-manifest :content-hash :reversion-or-containment
           :component-import :route :budget :token-limit :expiry
           :source-manifest :conclusion-link
           :remote-attestation :federated-claim)
   "evidence requirement kind"))


(defun validate-principle-result-state (value)
  (validate-closed-value value '(:passed :refused :needs-escalation)
                         "principle result state"))

(defun validate-policy-verdict-state (value)
  (validate-closed-value value '(:admitted :refused :needs-escalation)
                         "policy verdict state"))

(defstruct (source-manifest-entry
            (:constructor %make-source-manifest-entry (relative-path content-hash source-role))
            (:conc-name %source-manifest-entry-))
  (relative-path nil :read-only t)
  (content-hash nil :read-only t)
  (source-role nil :read-only t))

(defun source-manifest-entry-relative-path (entry)
  (copy-seq (%source-manifest-entry-relative-path entry)))
(defun source-manifest-entry-content-hash (entry)
  (copy-seq (%source-manifest-entry-content-hash entry)))
(defun source-manifest-entry-source-role (entry)
  (copy-seq (%source-manifest-entry-source-role entry)))

(defun make-source-manifest-entry (&key relative-path content-hash source-role)
  (%make-source-manifest-entry
   (ensure-nonempty-string relative-path "relative path")
   (ensure-nonempty-string content-hash "content hash")
   (ensure-nonempty-string source-role "source role")))

(defstruct (evidence-fact
            (:constructor %make-evidence-fact (kind fingerprint state))
            (:conc-name %evidence-fact-))
  (kind nil :read-only t)
  (fingerprint nil :read-only t)
  (state nil :read-only t))

(defun evidence-fact-kind (fact) (%evidence-fact-kind fact))
(defun evidence-fact-fingerprint (fact)
  (copy-seq (%evidence-fact-fingerprint fact)))
(defun evidence-fact-state (fact) (%evidence-fact-state fact))

(defun make-evidence-fact (&key kind fingerprint state)
  (%make-evidence-fact
   (ensure-keyword kind "evidence kind")
   (ensure-nonempty-string fingerprint "evidence fingerprint")
   (validate-evidence-state state)))

(defun ensure-evidence-facts (value)
  (unless (and (listp value) (every #'evidence-fact-p value)
               (= (length value)
                  (length (remove-duplicates value :test #'string=
                                             :key #'evidence-fact-fingerprint))))
    (error "Evidence facts must be a duplicate-free list of evidence facts"))
  (copy-list value))

(defstruct (evidence-requirement
            (:constructor %make-evidence-requirement
                (principle kind required-fingerprints evidence-facts))
            (:conc-name %evidence-requirement-))
  (principle nil :read-only t)
  (kind nil :read-only t)
  (required-fingerprints nil :read-only t)
  (evidence-facts nil :read-only t))

(defun evidence-requirement-principle (requirement)
  (%evidence-requirement-principle requirement))
(defun evidence-requirement-kind (requirement)
  (%evidence-requirement-kind requirement))
(defun evidence-requirement-required-fingerprints (requirement)
  (mapcar #'copy-seq (%evidence-requirement-required-fingerprints requirement)))
(defun evidence-requirement-evidence-facts (requirement)
  (copy-list (%evidence-requirement-evidence-facts requirement)))

(defun make-evidence-requirement
    (&key (principle nil principle-p) (kind nil kind-p)
       (required-fingerprints nil required-fingerprints-p)
       (evidence-facts nil evidence-facts-p))
  (unless (and principle-p kind-p required-fingerprints-p evidence-facts-p)
    (error "Evidence requirement fields are required"))
  (let ((fingerprints (ensure-label-list required-fingerprints
                                         "required fingerprints")))
    (unless fingerprints
      (error "Required fingerprints must be nonempty"))
    (%make-evidence-requirement
     (validate-principle-identifier principle)
     (validate-evidence-requirement-kind kind)
     fingerprints
     (ensure-evidence-facts evidence-facts))))

(defun ensure-source-manifest (value)
  (unless (and (listp value) value (every #'source-manifest-entry-p value)
               (= (length value)
                  (length (remove-duplicates value :test #'string=
                                             :key #'source-manifest-entry-relative-path))))
    (error "Source manifest must be a nonempty duplicate-free list of entries"))
  (copy-list value))

(defun ensure-evidence-requirements (value)
  (unless (and (listp value) value (every #'evidence-requirement-p value)
               (= (length value)
                  (length (remove-duplicates
                           value :test #'equal
                           :key (lambda (requirement)
                                  (list (evidence-requirement-principle requirement)
                                        (evidence-requirement-kind requirement)))))))
    (error "Evidence requirements must be a nonempty duplicate-free list"))
  (copy-list value))

(defstruct (policy-proposal
            (:constructor %make-policy-proposal
                (class problem outcome purpose caller input-contract output-contract
                 failure-contract declared-capabilities capability-diff source-manifest
                 risk-note dependency evidence-trigger evidence-requirements))
            (:conc-name %policy-proposal-))
  (class nil :read-only t)
  (problem nil :read-only t)
  (outcome nil :read-only t)
  (purpose nil :read-only t)
  (caller nil :read-only t)
  (input-contract nil :read-only t)
  (output-contract nil :read-only t)
  (failure-contract nil :read-only t)
  (declared-capabilities nil :read-only t)
  (capability-diff nil :read-only t)
  (source-manifest nil :read-only t)
  (risk-note nil :read-only t)
  (dependency nil :read-only t)
  (evidence-trigger nil :read-only t)
  (evidence-requirements nil :read-only t))

(defun policy-proposal-class (proposal) (%policy-proposal-class proposal))
(defun policy-proposal-problem (proposal) (copy-seq (%policy-proposal-problem proposal)))
(defun policy-proposal-outcome (proposal) (copy-seq (%policy-proposal-outcome proposal)))
(defun policy-proposal-purpose (proposal) (copy-seq (%policy-proposal-purpose proposal)))
(defun policy-proposal-caller (proposal) (copy-seq (%policy-proposal-caller proposal)))
(defun policy-proposal-input-contract (proposal)
  (copy-seq (%policy-proposal-input-contract proposal)))
(defun policy-proposal-output-contract (proposal)
  (copy-seq (%policy-proposal-output-contract proposal)))
(defun policy-proposal-failure-contract (proposal)
  (copy-seq (%policy-proposal-failure-contract proposal)))
(defun policy-proposal-declared-capabilities (proposal)
  (mapcar #'copy-seq (%policy-proposal-declared-capabilities proposal)))
(defun policy-proposal-capability-diff (proposal)
  (copy-seq (%policy-proposal-capability-diff proposal)))
(defun policy-proposal-source-manifest (proposal)
  (copy-list (%policy-proposal-source-manifest proposal)))
(defun policy-proposal-risk-note (proposal) (copy-seq (%policy-proposal-risk-note proposal)))
(defun policy-proposal-dependency (proposal) (copy-seq (%policy-proposal-dependency proposal)))
(defun policy-proposal-evidence-trigger (proposal)
  (copy-seq (%policy-proposal-evidence-trigger proposal)))
(defun policy-proposal-evidence-requirements (proposal)
  (copy-list (%policy-proposal-evidence-requirements proposal)))

(defun make-policy-proposal
    (&key (class nil class-p) (problem nil problem-p) (outcome nil outcome-p)
       (purpose nil purpose-p) (caller nil caller-p)
       (input-contract nil input-contract-p) (output-contract nil output-contract-p)
       (failure-contract nil failure-contract-p)
       (declared-capabilities nil declared-capabilities-p)
       (capability-diff nil capability-diff-p) (source-manifest nil source-manifest-p)
       (risk-note nil risk-note-p) (dependency nil dependency-p)
       (evidence-trigger nil evidence-trigger-p)
       (evidence-requirements nil evidence-requirements-p))
  (unless (and class-p problem-p outcome-p purpose-p caller-p input-contract-p
               output-contract-p failure-contract-p declared-capabilities-p
               capability-diff-p source-manifest-p risk-note-p dependency-p
               evidence-trigger-p evidence-requirements-p)
    (error "Policy proposal fields are required"))
  (%make-policy-proposal
   (validate-proposal-class class)
   (ensure-nonempty-string problem "problem")
   (ensure-nonempty-string outcome "outcome")
   (ensure-nonempty-string purpose "purpose")
   (ensure-nonempty-string caller "caller")
   (ensure-nonempty-string input-contract "input contract")
   (ensure-nonempty-string output-contract "output contract")
   (ensure-nonempty-string failure-contract "failure contract")
   (ensure-label-list declared-capabilities "declared capabilities")
   (ensure-nonempty-string capability-diff "capability diff")
   (ensure-source-manifest source-manifest)
   (ensure-nonempty-string risk-note "risk note")
   (ensure-nonempty-string dependency "dependency")
   (ensure-nonempty-string evidence-trigger "evidence trigger")
   (ensure-evidence-requirements evidence-requirements)))

(defstruct (principle-result
            (:constructor %make-principle-result (principle state evidence-fingerprints))
            (:conc-name %principle-result-))
  (principle nil :read-only t)
  (state nil :read-only t)
  (evidence-fingerprints nil :read-only t))

(defun principle-result-principle (result) (%principle-result-principle result))
(defun principle-result-state (result) (%principle-result-state result))
(defun principle-result-evidence-fingerprints (result)
  (mapcar #'copy-seq (%principle-result-evidence-fingerprints result)))

(defun make-principle-result (&key principle state evidence-fingerprints)
  (%make-principle-result
   (validate-principle-identifier principle)
   (validate-principle-result-state state)
   (ensure-label-list evidence-fingerprints "evidence fingerprints")))

(defstruct (policy-verdict
            (:constructor %make-policy-verdict (state principle-results reason-labels))
            (:conc-name %policy-verdict-))
  (state nil :read-only t)
  (principle-results nil :read-only t)
  (reason-labels nil :read-only t))

(defun policy-verdict-state (verdict) (%policy-verdict-state verdict))
(defun policy-verdict-principle-results (verdict)
  (copy-list (%policy-verdict-principle-results verdict)))
(defun policy-verdict-reason-labels (verdict)
  (mapcar #'copy-seq (%policy-verdict-reason-labels verdict)))

(defun ensure-principle-results (value)
  (unless (and (listp value)
               (every #'principle-result-p value)
               (= (length value)
                  (length (remove-duplicates value
                                             :test #'eq
                                             :key #'principle-result-principle))))
    (error "Principle results must be a duplicate-free list of principle results"))
  (copy-list value))

(defun make-policy-verdict (&key state principle-results reason-labels)
  (%make-policy-verdict
   (validate-policy-verdict-state state)
   (ensure-principle-results principle-results)
   (ensure-label-list reason-labels "reason labels")))


(defun evidence-requirement-passed-p (requirement)
  "Return (values passed-p refusal-labels) for one evidence requirement."
  (let ((facts (evidence-requirement-evidence-facts requirement))
        (fingerprints (evidence-requirement-required-fingerprints requirement))
        (labels '()))
    (dolist (fact facts)
      (case (evidence-fact-state fact)
        (:current nil)
        (:stale (pushnew "stale-evidence" labels :test #'string=))
        (:missing (pushnew "missing-evidence" labels :test #'string=))
        (:malformed (pushnew "malformed-evidence" labels :test #'string=))
        (:conflicting (pushnew "conflicting-evidence" labels :test #'string=))
        (:unverifiable (pushnew "unverifiable-evidence" labels :test #'string=))))
    (dolist (required fingerprints)
      (unless (member required (mapcar #'evidence-fact-fingerprint facts)
                      :test #'string=)
        (pushnew "missing-evidence" labels :test #'string=)))
    (values (and (every (lambda (fact)
                          (eql :current (evidence-fact-state fact)))
                        facts)
                 (every (lambda (required)
                          (member required
                                  (mapcar #'evidence-fact-fingerprint facts)
                                  :test #'string=))
                        fingerprints))
            (nreverse labels))))

(defun evaluate-policy-proposal (proposal)
  (unless (policy-proposal-p proposal)
    (error "Policy proposal must be a policy proposal: ~S" proposal))
  (let ((requirements (policy-proposal-evidence-requirements proposal))
        (principle-results '())
        (reason-labels '()))
    (dolist (principle +matrix-principles+)
      (let ((for-principle
              (remove-if-not (lambda (requirement)
                               (eql principle
                                    (evidence-requirement-principle requirement)))
                             requirements)))
        (if (null for-principle)
            (progn
              (push (make-principle-result
                     :principle principle :state :refused
                     :evidence-fingerprints '())
                    principle-results)
              (pushnew "missing-principle-result" reason-labels :test #'string=))
            (let ((fingerprints '())
                  (labels '())
                  (all-passed t))
              (dolist (requirement for-principle)
                (multiple-value-bind (passed-p refusal-labels)
                    (evidence-requirement-passed-p requirement)
                  (unless passed-p
                    (setf all-passed nil))
                  (dolist (label refusal-labels)
                    (pushnew label labels :test #'string=))
                  (dolist (fingerprint
                           (evidence-requirement-required-fingerprints
                            requirement))
                    (pushnew fingerprint fingerprints :test #'string=))))
              (push (make-principle-result
                     :principle principle
                     :state (if all-passed :passed :refused)
                     :evidence-fingerprints (nreverse fingerprints))
                    principle-results)
              (dolist (label labels)
                (pushnew label reason-labels :test #'string=))))))
    (make-policy-verdict
     :state (if (every (lambda (result)
                         (eql :passed (principle-result-state result)))
                       principle-results)
                :admitted :refused)
     :principle-results (nreverse principle-results)
     :reason-labels (nreverse reason-labels))))

(defun ensure-nonempty-label-list (value name)
  (unless value
    (error "~A must be nonempty" name))
  (ensure-label-list value name))

(defun validate-certificate-action (value)
  (validate-closed-value value '(:none :prepare-candidate :stage :commit :push)
                         "certificate action"))

(defstruct (candidate-certificate
            (:constructor %make-candidate-certificate
                (action repository-identity base-revision candidate-paths
                 content-hash evidence-hashes principle-verdicts
                 review-findings source-manifest policy-profile expiry))
            (:conc-name %candidate-certificate-))
  (action nil :read-only t)
  (repository-identity nil :read-only t)
  (base-revision nil :read-only t)
  (candidate-paths nil :read-only t)
  (content-hash nil :read-only t)
  (evidence-hashes nil :read-only t)
  (principle-verdicts nil :read-only t)
  (review-findings nil :read-only t)
  (source-manifest nil :read-only t)
  (policy-profile nil :read-only t)
  (expiry nil :read-only t))

(defun candidate-certificate-action (cert) (%candidate-certificate-action cert))
(defun candidate-certificate-repository-identity (cert)
  (copy-seq (%candidate-certificate-repository-identity cert)))
(defun candidate-certificate-base-revision (cert)
  (copy-seq (%candidate-certificate-base-revision cert)))
(defun candidate-certificate-candidate-paths (cert)
  (mapcar #'copy-seq (%candidate-certificate-candidate-paths cert)))
(defun candidate-certificate-content-hash (cert)
  (copy-seq (%candidate-certificate-content-hash cert)))
(defun candidate-certificate-evidence-hashes (cert)
  (mapcar #'copy-seq (%candidate-certificate-evidence-hashes cert)))
(defun candidate-certificate-principle-verdicts (cert)
  (copy-list (%candidate-certificate-principle-verdicts cert)))
(defun candidate-certificate-review-findings (cert)
  (mapcar #'copy-seq (%candidate-certificate-review-findings cert)))
(defun candidate-certificate-source-manifest (cert)
  (copy-list (%candidate-certificate-source-manifest cert)))
(defun candidate-certificate-policy-profile (cert)
  (copy-seq (%candidate-certificate-policy-profile cert)))
(defun candidate-certificate-expiry (cert)
  (copy-seq (%candidate-certificate-expiry cert)))

(defun ensure-candidate-certificate-verdicts (value)
  (unless (and (listp value) value
               (every #'policy-verdict-p value)
               (= (length value)
                  (length (remove-duplicates value :test #'eq))))
    (error "Principle verdicts must be a nonempty duplicate-free list of policy verdicts"))
  (copy-list value))

(defun make-candidate-certificate
    (&key (action nil action-p) (repository-identity nil repository-identity-p)
       (base-revision nil base-revision-p) (candidate-paths nil candidate-paths-p)
       (content-hash nil content-hash-p) (evidence-hashes nil evidence-hashes-p)
       (principle-verdicts nil principle-verdicts-p)
       (review-findings nil review-findings-p)
       (source-manifest nil source-manifest-p)
       (policy-profile nil policy-profile-p) (expiry nil expiry-p))
  (unless (and action-p repository-identity-p base-revision-p candidate-paths-p
               content-hash-p evidence-hashes-p principle-verdicts-p
               review-findings-p source-manifest-p policy-profile-p expiry-p)
    (error "Candidate certificate fields are required"))
  (%make-candidate-certificate
   (validate-certificate-action action)
   (ensure-nonempty-string repository-identity "repository identity")
   (ensure-nonempty-string base-revision "base revision")
   (ensure-nonempty-label-list candidate-paths "candidate paths")
   (ensure-nonempty-string content-hash "content hash")
   (ensure-nonempty-label-list evidence-hashes "evidence hashes")
   (ensure-candidate-certificate-verdicts principle-verdicts)
   (ensure-label-list review-findings "review findings")
   (ensure-source-manifest source-manifest)
   (ensure-nonempty-string policy-profile "policy profile")
   (ensure-nonempty-string expiry "expiry")))

(defun issue-candidate-certificate (verdict &key action repository-identity
                                       base-revision candidate-paths content-hash
                                       evidence-hashes review-findings
                                       source-manifest policy-profile expiry)
  "Mint a non-mutating candidate authorization certificate from an :admitted
policy verdict. The issuer is mechanical: it binds one closed action and the
supplied facts into an immutable certificate. Action-admission policy (for
example a commit certificate never authorizing a push) is enforced later by
the executor, not here."
  (unless (policy-verdict-p verdict)
    (error "Issue requires a policy verdict, got: ~S" verdict))
  (unless (eql :admitted (policy-verdict-state verdict))
    (error "Certificate requires an admitted verdict, got: ~S"
           (policy-verdict-state verdict)))
  (make-candidate-certificate
   :action action :repository-identity repository-identity
   :base-revision base-revision :candidate-paths candidate-paths
   :content-hash content-hash :evidence-hashes evidence-hashes
   :principle-verdicts (list verdict)
   :review-findings review-findings
   :source-manifest source-manifest
   :policy-profile policy-profile
   :expiry expiry))

