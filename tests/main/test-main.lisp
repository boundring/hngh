(in-package :hngh.tests)

;;; Rung 7 composition root tests. The harness composes the five use cases
;;; with injected or default port adapters, main's coordinator functions wire
;;; the installed evidence, review, and mutation adapters through injected
;;; transports, and every result renders through hngh.presentation. Nothing
;;; starts a subprocess here: all transports are fakes.

(defun confirmed-admission-facts ()
  (hngh.application:make-admission-facts
   :authority :confirmed :ledger :confirmed :loadout :confirmed
   :exclusive-write :confirmed))

(defun passed-verification ()
  (hngh.application:make-verification-result :status :passed
                                             :labels '("tests-pass")))

(defun complete-manifest ()
  (hngh.application:make-manifest-result :status :complete
                                         :labels '("manifest-complete")))

(defun result-status (result)
  (hngh.application:application-result-status result))

(defun result-run (result)
  (hngh.application:application-result-run result))

;;; The full run lifecycle composes through one harness and renders each step.

(let ((harness
        (hngh.main:make-run-harness
         :next-identifier (lambda () "run-main-1")
         :clock-now (lambda () "2026-08-18T00:00:00Z")
         :admission-facts (lambda (run)
                            (declare (ignore run))
                            (confirmed-admission-facts))
         :tool-executor (lambda (request)
                          (declare (ignore request))
                          (passed-verification))
         :repository-inspector (lambda (request)
                                 (declare (ignore request))
                                 (complete-manifest)))))
  (let* ((created (hngh.main:harness-create-run
                   harness (make-application-mission)
                   (make-application-role) (make-application-loadout)))
         (armed (hngh.main:harness-arm-run harness (result-run created)))
         (started (hngh.main:harness-start-run harness (result-run armed)))
         (checkpointed (hngh.main:harness-checkpoint harness (result-run started)))
         (closed (hngh.main:harness-close-run
                  harness (result-run checkpointed) :evacuated
                  (admitted-close-proposal))))
    (check (eql :accepted (result-status created))
           "harness create-run accepts a complete run")
    (check (eql :accepted (result-status armed))
           "harness arm-run accepts under confirmed facts")
    (check (eql :accepted (result-status started))
           "harness start-run accepts an armed run")
    (check (eql :accepted (result-status checkpointed))
           "harness checkpoint accepts closed verification and manifest")
    (check (eql :accepted (result-status closed))
           "harness close-run accepts under an admitted proposal")
    (check (eql :created (hngh.domain:run-state (result-run created)))
           "harness creation returns a created run")
    (check (eql :armed (hngh.domain:run-state (result-run armed)))
           "harness arming returns an armed run")
    (check (eql :running (hngh.domain:run-state (result-run started)))
           "harness start returns a running run")
    (check (eql :checkpointed (hngh.domain:run-state (result-run checkpointed)))
           "harness checkpoint returns a checkpointed run")
    (check (eql :evacuated (hngh.domain:run-state (result-run closed)))
           "harness close returns an evacuated run")
    (check (= 5 (length (hngh.main:harness-records harness)))
           "each accepted use case records one atomic run-and-receipt pair")
    (check (search "accepted" (hngh.main:display created))
           "operator display renders the creation result")
    (check (search "state=evacuated" (hngh.main:display closed))
           "operator display renders the final terminal state")
    (check (search "run-main-1" (hngh.main:display created))
           "operator display names the recorded run")))

;;; Default-constructed ports: per-harness identifier source and in-memory
;;; record store keep the harness deterministic without any external root.

(let ((harness (hngh.main:make-run-harness
                :clock-now (lambda () "2026-08-18T00:00:00Z"))))
  (let ((first (hngh.main:harness-create-run
                harness (make-application-mission)
                (make-application-role) (make-application-loadout)))
        (second (hngh.main:harness-create-run
                 harness (make-application-mission)
                 (make-application-role) (make-application-loadout))))
    (check (eql :accepted (result-status first))
           "default harness creates a run")
    (check (eql :accepted (result-status second))
           "default harness creates a second run")
    (check (= 2 (length (hngh.main:harness-records harness)))
           "the default record store keeps every recorded pair")
    (check (search "run run-1" (hngh.main:display first))
           "the default identifier source names the first run")
    (check (search "run run-2" (hngh.main:display second))
           "the default identifier source names the second run")))

;;; Fail-closed default ports: nothing is admitted without composed authority.

(let ((harness (hngh.main:make-run-harness
                :next-identifier (lambda () "run-x")
                :clock-now (lambda () "2026-08-18T00:00:00Z"))))
  (let ((created (hngh.main:harness-create-run
                  harness (make-application-mission)
                  (make-application-role) (make-application-loadout))))
    (let ((armed (hngh.main:harness-arm-run harness (result-run created)))
          (started (hngh.main:harness-start-run harness (result-run created)))
          (checkpointed (hngh.main:harness-checkpoint harness (result-run created))))
      (check (eql :refused (result-status armed))
             "unconfirmed admission facts refuse arming by default")
      (check (eql :refused (result-status started))
             "undefined start authority refuses by default")
      (check (eql :refused (result-status checkpointed))
             "undefined checkpoint evidence refuses by default")
      (check (= 1 (length (hngh.main:harness-records harness)))
             "refused default-port calls record nothing beyond creation")
      (check (search "refused" (hngh.main:display armed))
             "operator display renders the default refusal"))))

;;; Installed adapters compose through main's coordinator functions.

(let* ((revision "0123456789abcdef0123456789abcdef01234567")
       (runner (multiple-value-bind (transport)
                   (make-evidence-ports-fake
                    :responses (list (list :return 0
                                           (format nil "~A~%" revision) "")))
                 transport))
       (ports (hngh.adapters.evidence:make-evidence-ports :run-process runner))
       (result (hngh.main:gather-run-evidence ports :repository-revision)))
  (check (eql :complete (hngh.adapters.evidence:evidence-result-status result))
         "the evidence coordinator gathers the fixed revision command")
  (check (search "evidence-bundle status=complete" (hngh.main:display result))
         "operator display renders the gathered evidence"))

(let* ((ports (multiple-value-bind (transport)
                   (make-review-ports-fake
                    :responses (list (list :return 0
                                           "{\"findings\":[{\"label\":\"spelling\",\"citation\":\"file.lisp:12\"}]}"
                                           "")))
                 transport))
       (result (hngh.main:request-run-review
                ports
                :candidate-paths '("src/a.lisp")
                :content-hash "hash-1"
                :policy-context '("policy-1"))))
  (check (eql :complete (hngh.adapters.review:review-result-status result))
         "the review coordinator sends a closed request and maps findings")
  (check (search "review status=complete" (hngh.main:display result))
         "operator display renders the review result"))

;;; Rung 10: the review coordinator maps every closed provider outcome --------

(let* ((ports (multiple-value-bind (transport)
                   (make-review-ports-fake
                    :responses (list (list :return 500 "provider error" "")))
                 transport))
       (result (hngh.main:request-run-review
                ports
                :candidate-paths '("src/a.lisp")
                :content-hash "hash-1"
                :policy-context '("policy-1"))))
  (check (eq :complete (hngh.adapters.review:review-result-status result))
         "a provider failure still completes the review bundle")
  (check (eql :unverifiable
              (hngh.domain:evidence-fact-state
               (hngh.adapters.review:review-result-fact result)))
         "a provider 500 becomes an unverifiable review fact")
  (check (equal "unavailable"
                (hngh.domain:evidence-fact-fingerprint
                 (hngh.adapters.review:review-result-fact result)))
         "the provider failure fact carries the unavailable fingerprint"))

(let* ((ports (multiple-value-bind (transport)
                   (make-review-ports-fake
                    :responses (list (list :error "provider blew up")))
                 transport))
       (result (hngh.main:request-run-review
                ports
                :candidate-paths '("src/a.lisp")
                :content-hash "hash-1"
                :policy-context '("policy-1"))))
  (check (eq :refused (hngh.adapters.review:review-result-status result))
         "a thrown provider fault refuses at the coordinator")
  (check (member "transport-fault"
                 (hngh.adapters.review:review-result-refusal-labels result)
                 :test #'string=)
         "the thrown provider fault names transport-fault"))

(let* ((ports (multiple-value-bind (transport)
                   (make-review-ports-fake
                    :responses (list (list :return 0 "not json" "")))
                 transport))
       (result (hngh.main:request-run-review
                ports
                :candidate-paths '("src/a.lisp")
                :content-hash "hash-1"
                :policy-context '("policy-1"))))
  (check (eq :refused (hngh.adapters.review:review-result-status result))
         "malformed provider output refuses at the coordinator")
  (check (member "malformed-output"
                 (hngh.adapters.review:review-result-refusal-labels result)
                 :test #'string=)
         "malformed output names the closed refusal"))

(let* ((certificate (make-mutation-certificate))
       (evidence (make-mutation-evidence))
       (ports (multiple-value-bind (transport) (make-mutation-fake) transport))
       (result (hngh.main:execute-run-mutation certificate evidence ports)))
  (check (eql :executed (hngh.adapters.mutation:mutation-result-status result))
         "the mutation coordinator rechecks and executes the certificate action")
  (check (search "mutation status=executed" (hngh.main:display result))
         "operator display renders the executed mutation"))

;;; Default-constructed adapter ports stay pure: construction composes the
;;; installed read-only process transport without starting a process.

(check (hngh.adapters.evidence:evidence-ports-p
        (hngh.main:default-evidence-ports))
       "default evidence ports compose the read-only process transport")
(check (hngh.adapters.mutation:mutation-ports-p
        (hngh.main:default-mutation-ports))
       "default mutation ports compose the evidence process transport")
