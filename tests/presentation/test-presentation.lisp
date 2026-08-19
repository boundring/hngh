(in-package :hngh.tests)

;;; Rung 7 presentation tests. Renderers consume application and domain values
;;; plus installed adapter results and emit plain factual strings. Rendering
;;; never mutates canonical state, refusals stay literal refusals, and the
;;; optional reference lexicon applies only display copy at a named surface.

(defun rendered-p (text &rest fragments)
  (every (lambda (fragment) (search fragment text)) fragments))

;;; Reference lexicon --------------------------------------------------

(let ((lexicon (read-fixture "tests/fixtures/reference-lexicon/presentation-only.lisp"))
      (canonical (read-fixture "tests/fixtures/reference-lexicon/attempts-canonical-control.lisp")))
  (check (hngh.presentation:reference-lexicon-p lexicon)
         "renderer accepts the four-field reference lexicon fixture")
  (check (not (hngh.presentation:reference-lexicon-p canonical))
         "renderer rejects a lexicon carrying canonical control fields")
  (check (string= "new run"
                  (hngh.presentation:render-with-lexicon lexicon :status "created"))
         "a known surface returns its reference copy")
  (check (string= "created"
                  (hngh.presentation:render-with-lexicon lexicon :lifecycle "created"))
         "an unknown surface falls back to the original copy")
  (check (string= "created"
                  (hngh.presentation:render-status-label :created nil))
         "status label defaults to the canonical state term")
  (check (string= "new run"
                  (hngh.presentation:render-status-label :created lexicon))
         "status label uses the reference copy when a pack is active")
  (check (string= "evacuated"
                  (hngh.presentation:render-status-label :evacuated nil))
         "evacuated status stays canonical without a pack")
  (check (signals-error-p
          (lambda ()
            (hngh.presentation:render-with-lexicon '(:junk) :status "created")))
         "malformed lexicon input refuses"))

(let ((run (created-application-run))
      (lexicon (read-fixture "tests/fixtures/reference-lexicon/presentation-only.lisp")))
  (hngh.presentation:render-status-label (hngh.domain:run-state run) lexicon)
  (check (eql :created (hngh.domain:run-state run))
         "reference display copy does not alter canonical run state"))

;;; Renderers over pure domain values ---------------------------------

(let ((run (created-application-run)))
  (check (rendered-p (hngh.presentation:render-run run)
                     "run run-application-1" "state=created"
                     "role=builder" "loadout=local"
                     "mission=Create a valid run")
         "run rendering shows identifier, state, role, loadout, and mission")
  (check (eql :created (hngh.domain:run-state run))
         "rendering a run does not mutate its state"))

(let ((run (hngh.domain:advance-run
            (hngh.domain:advance-run
             (hngh.domain:advance-run (created-application-run) :armed)
             :running)
            :evacuated)))
  (check (rendered-p (hngh.presentation:render-run run) "state=evacuated")
         "evacuated state renders literally")
  (check (eql :evacuated (hngh.domain:run-state run))
         "rendering an evacuated run leaves its state unchanged"))

(let ((receipt (hngh.domain:make-receipt
                :kind :creation
                :facts '("identifier: run-1" "timestamp: 2026-08-18T00:00:00Z"))))
  (check (rendered-p (hngh.presentation:render-receipt receipt)
                     "receipt kind=creation" "identifier: run-1"
                     "timestamp: 2026-08-18T00:00:00Z")
         "receipt rendering shows kind and recorded facts")
  (check (equal '("identifier: run-1" "timestamp: 2026-08-18T00:00:00Z")
                (hngh.domain:receipt-facts receipt))
         "rendering a receipt does not mutate its facts"))

(let ((fact (hngh.domain:make-evidence-fact
             :kind :repository-revision :fingerprint "abc123" :state :current)))
  (check (rendered-p (hngh.presentation:render-evidence-fact fact)
                     "evidence kind=repository-revision"
                     "fingerprint=abc123" "state=current")
         "evidence rendering shows kind, fingerprint, and state"))

(let ((entry (hngh.domain:make-source-manifest-entry
              :relative-path "policy.md"
              :content-hash "policy-hash"
              :source-role "policy")))
  (check (rendered-p (hngh.presentation:render-source-manifest-entry entry)
                     "path=policy.md" "hash=policy-hash" "role=policy")
         "manifest entry rendering shows path, hash, and role"))

(let ((result (hngh.domain:make-principle-result
               :principle :closed-authority :state :passed
               :evidence-fingerprints '("fp-1"))))
  (check (rendered-p (hngh.presentation:render-principle-result result)
                     "principle closed-authority" "state=passed")
         "principle result rendering shows principle and state"))

(let ((admitted (make-fixture-admitted-verdict)))
  (check (rendered-p (hngh.presentation:render-policy-verdict admitted)
                     "verdict state=admitted" "principle closed-authority"
                     "reasons=none")
         "admitted verdict rendering is literal and complete"))

(let ((refused (hngh.domain:evaluate-policy-proposal (refused-close-proposal))))
  (check (rendered-p (hngh.presentation:render-policy-verdict refused)
                     "verdict state=refused" "missing-principle-result")
         "refused verdict rendering keeps its literal refusals"))

(let ((certificate
        (hngh.domain:make-candidate-certificate
         :action :commit
         :repository-identity "repo"
         :base-revision "base-1"
         :candidate-paths '("src/candidate.lisp")
         :content-hash "content-1"
         :evidence-hashes '("evidence-1")
         :principle-verdicts (list (make-fixture-admitted-verdict))
         :review-findings '("review-1")
         :source-manifest (list (hngh.domain:make-source-manifest-entry
                                 :relative-path "src/candidate.lisp"
                                 :content-hash "content-1"
                                 :source-role "candidate"))
         :policy-profile "profile-1"
         :expiry "2026-08-19T00:00:00Z")))
  (check (rendered-p (hngh.presentation:render-candidate-certificate certificate)
                     "certificate action=commit" "repository=repo"
                     "base=base-1" "paths=src/candidate.lisp"
                     "content-hash=content-1" "evidence-hashes=evidence-1"
                     "verdicts=1" "findings=review-1" "manifest=1"
                     "policy-profile=profile-1" "expiry=2026-08-19T00:00:00Z")
         "certificate rendering shows every bound fact"))

;;; Application results ----------------------------------------------------

(multiple-value-bind (ports snapshot)
    (make-creation-fake)
  (declare (ignore snapshot))
  (let ((result (create-run-with ports (make-application-mission)
                                 (make-application-role)
                                 (make-application-loadout))))
    (let ((rendered (hngh.presentation:render-application-result result)))
      (check (rendered-p rendered "accepted" "state=created"
                         "kind=creation" "facts=created")
             "accepted result rendering is factual and complete")
      (check (eql :accepted (hngh.application:application-result-status result))
             "rendering an accepted result does not change its status")
      (check (eql :created (hngh.domain:run-state
                            (hngh.application:application-result-run result)))
             "rendering an accepted result does not change the run"))))

(let ((result (hngh.application::make-application-result
               :refused :labels '("invalid-transition"))))
  (let ((rendered (hngh.presentation:render-application-result result)))
    (check (rendered-p rendered "refused" "invalid-transition")
           "a refusal renders as a literal refusal")
    (check (search "refused"
                   (hngh.presentation:render-application-result result))
           "a refusal remains a literal refusal on re-render")
    (check (eql :refused (hngh.application:application-result-status result))
           "rendering a refused result does not change its status")))

(let ((conflict (hngh.application::make-application-result
                 :conflict :labels '("record-conflict"))))
  (check (rendered-p (hngh.presentation:render-application-result conflict)
                     "conflict" "record-conflict")
         "conflict result renders its closed status and label"))

;;; Application checkpoint values ------------------------------------------

(let ((verification (hngh.application:make-verification-result
                     :status :passed :labels '("tests-pass"))))
  (check (rendered-p (hngh.presentation:render-verification-result verification)
                     "verification status=passed" "tests-pass")
         "verification rendering shows status and labels"))

(let ((manifest (hngh.application:make-manifest-result
                 :status :complete :labels '("manifest-complete"))))
  (check (rendered-p (hngh.presentation:render-manifest-result manifest)
                     "manifest status=complete" "manifest-complete")
         "manifest rendering shows status and labels"))

;;; Installed adapter results ----------------------------------------------

(let* ((revision "0123456789abcdef0123456789abcdef01234567")
       (ports (multiple-value-bind (runner)
                  (make-evidence-ports-fake
                   :responses (list (list :return 0
                                          (format nil "~A~%" revision) "")))
                (hngh.adapters.evidence:make-evidence-ports :run-process runner)))
       (result (hngh.adapters.evidence:gather-evidence
                (hngh.adapters.evidence:make-evidence-request
                 :command :repository-revision)
                ports)))
  (check (rendered-p (hngh.presentation:render-evidence-result result)
                     "evidence-bundle status=complete"
                     "evidence kind=repository-revision" "state=current")
         "complete evidence bundle rendering shows facts and states"))

(let ((result
        (hngh.adapters.evidence:gather-evidence
         (hngh.adapters.evidence:make-evidence-request
          :command :working-tree-status)
         (multiple-value-bind (runner)
             (make-evidence-ports-fake :responses (list (list :error "boom")))
           (hngh.adapters.evidence:make-evidence-ports :run-process runner)))))
  (check (rendered-p (hngh.presentation:render-evidence-result result)
                     "evidence-bundle status=refused" "transport-fault")
         "refused evidence bundle rendering keeps its refusal labels"))

(let* ((certificate (make-mutation-certificate))
       (evidence (make-mutation-evidence))
       (ports (multiple-value-bind (process-fake) (make-mutation-fake)
                process-fake))
       (result (execute-mutation-fixture certificate evidence ports)))
  (check (eq :executed (hngh.adapters.mutation:mutation-result-status result))
         "mutation fixture executes before rendering")
  (check (rendered-p (hngh.presentation:render-mutation-result result)
                     "mutation status=executed" "action=stage"
                     "\"git\"" "exit=0")
         "executed mutation rendering shows action, command, and exit"))

(let* ((certificate (make-mutation-certificate))
       (ports (multiple-value-bind (process-fake) (make-mutation-fake)
                process-fake))
       (result (execute-mutation-fixture certificate nil ports)))
  (check (eq :refused (hngh.adapters.mutation:mutation-result-status result))
         "missing fresh evidence refuses before rendering")
  (check (rendered-p (hngh.presentation:render-mutation-result result)
                     "mutation status=refused" "missing-fresh-evidence")
         "refused mutation rendering keeps the literal refusal"))

(let* ((ports (multiple-value-bind (reviewer)
                  (make-review-ports-fake
                   :responses (list (list :return 0
                                          "{\"findings\":[{\"label\":\"spelling\",\"citation\":\"file.lisp:12\"}]}"
                                          "")))
                reviewer))
       (result (hngh.adapters.review:request-review
                (hngh.adapters.review:make-review-request
                 :candidate-paths '("src/a.lisp")
                 :content-hash "hash-1"
                 :policy-context '("policy-1"))
                ports)))
  (check (eq :complete (hngh.adapters.review:review-result-status result))
         "review fixture completes before rendering")
  (check (rendered-p (hngh.presentation:render-review-result result)
                     "review status=complete" "findings=1"
                     "finding label=spelling citation=file.lisp:12"
                     "kind=review" "state=current")
         "complete review rendering shows findings and the review fact"))

(let* ((ports (multiple-value-bind (reviewer)
                  (make-review-ports-fake :responses (list (list :error "boom")))
                reviewer))
       (result (hngh.adapters.review:request-review
                (hngh.adapters.review:make-review-request
                 :candidate-paths '("src/a.lisp")
                 :content-hash "hash-1"
                 :policy-context '("policy-1"))
                ports)))
  (check (eq :refused (hngh.adapters.review:review-result-status result))
         "review transport fault refuses before rendering")
  (check (rendered-p (hngh.presentation:render-review-result result)
                     "review status=refused" "transport-fault")
         "refused review rendering keeps the literal refusal"))

;;; Dispatch, reports, and fallback ----------------------------------------

(let ((run (created-application-run))
      (receipt (hngh.domain:make-receipt :kind :creation
                                         :facts '("identifier: run-1"))))
  (let ((rendered (hngh.presentation:render-report run receipt)))
    (check (rendered-p rendered "run run-application-1" "receipt kind=creation")
           "report composes multiple values into one operator report"))
  (check (rendered-p (hngh.presentation:render run)
                     "run run-application-1" "state=created")
         "default render dispatches to the run renderer"))

(check (rendered-p (hngh.presentation:render :unknown) ":UNKNOWN")
       "unknown values render as their printed representation")
