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

(defun validate-principle-identifier (value)
  (validate-closed-value
   value '(:closed-authority :least-authority :dependency-direction
           :fail-closed :evidence-before-claim :atomic-mutation :reversibility
           :no-hidden-execution :cost-and-route-discipline :source-grounding)
   "principle identifier"))

(defun validate-failure-category (value)
  (validate-closed-value
   value '(:domain-policy-or-invariant :application-invariant
           :port-callback-fault-or-malformed-return :atomic-recording-conflict
           :insufficient-or-stale-evidence :tool-or-environment-fault
           :review-disagreement :mutation-precondition-mismatch-or-failure)
   "failure category"))

(defun validate-failure-disposition (value)
  (validate-closed-value
   value '(:propagate-to-test-gate :typed-domain-refusal
           :normalize-to-refusal-at-callback :normalize-to-conflict-without-retry
           :refuse :needs-escalation :stop-and-record-evidence)
   "failure disposition"))

(defun validate-evidence-state (value)
  (validate-closed-value value
                         '(:current :stale :missing :malformed :conflicting :unverifiable)
                         "evidence state"))

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
