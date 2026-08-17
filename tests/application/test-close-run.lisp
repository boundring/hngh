(in-package :hngh.tests)

(defun close-run-with (ports request)
  (application-call "CLOSE-RUN" ports request))

(defun close-result-status (result)
  (application-result-value "APPLICATION-RESULT-STATUS" result))

(defun close-result-run (result)
  (application-result-value "APPLICATION-RESULT-RUN" result))

(defun close-result-receipt (result)
  (application-result-value "APPLICATION-RESULT-RECEIPT" result))

(defun close-result-labels (result)
  (application-result-value "APPLICATION-RESULT-LABELS" result))

;; A ten-principle proposal whose every requirement is satisfied by a current
;; fact evaluates to :admitted, so the policy gate opens.
(defun admitted-close-proposal ()
  (let ((principles '(:closed-authority :least-authority :dependency-direction
                      :fail-closed :evidence-before-claim :atomic-mutation
                      :reversibility :no-hidden-execution
                      :cost-and-route-discipline :source-grounding)))
    (make-fixture-proposal
     (loop for principle in principles
           for n from 1
           collect (make-fixture-requirement
                    principle (if (member principle '(:purpose :caller))
                                  :purpose :claim-proof)
                    (list (format nil "fp-~D" n))
                    (list (hngh.domain:make-evidence-fact
                           :kind :fixture
                           :fingerprint (format nil "fp-~D" n)
                           :state :current)))))))

;; A proposal with one missing principle evaluates to :refused and records the
;; missing-principle-result label, so the policy gate stays closed.
(defun refused-close-proposal ()
  (let ((principles '(:closed-authority :least-authority :dependency-direction
                      :fail-closed :evidence-before-claim :atomic-mutation
                      :reversibility :no-hidden-execution
                      :cost-and-route-discipline)))
    (make-fixture-proposal
     (loop for principle in principles
           for n from 1
           collect (make-fixture-requirement
                    principle :claim-proof
                    (list (format nil "fp-~D" n))
                    (list (hngh.domain:make-evidence-fact
                           :kind :fixture
                           :fingerprint (format nil "fp-~D" n)
                           :state :current)))))))

(defun running-close-source ()
  (hngh.domain:advance-run (armed-application-run) :running))

(defun close-request-with (&key (run (running-close-source))
                           (target :cancelled)
                           (proposal (admitted-close-proposal)))
  (application-call "MAKE-CLOSE-REQUEST"
                    :run run :target target :proposal proposal))

;; (a) request rejects missing, non-run, unknown-target, or non-proposal input.
(dolist (arguments
         (list '()
               (list :run :invalid :target :cancelled
                     :proposal (admitted-close-proposal))
               (list :run (running-close-source) :target :invalid
                     :proposal (admitted-close-proposal))
               (list :run (running-close-source) :target :afterlife
                     :proposal (admitted-close-proposal))
               (list :run (running-close-source) :target :cancelled
                     :proposal :not-a-proposal)))
  (check (signals-error-p
          (lambda ()
            (apply (application-function "MAKE-CLOSE-REQUEST") arguments)))
         "close requests reject missing or malformed fields"))

;; (b) close ports reject missing or non-function record callbacks.
(dolist (arguments
         (list '()
               (list :record-run :invalid)))
  (check (signals-error-p
          (lambda ()
            (apply (application-function "MAKE-RUN-CLOSE-PORTS") arguments)))
         "close ports reject missing or non-function record callback"))

;; (c) a running run closes to :cancelled only under an admitted proposal.
(multiple-value-bind (ports snapshot)
    (make-close-fake)
  (let ((result (close-run-with ports (close-request-with :target :cancelled)))
        (state (funcall snapshot)))
    (check (eql :accepted (close-result-status result))
           "admitted proposal accepts a run close to cancelled")
    (check (eql :cancelled
                (hngh.domain:run-state (close-result-run result)))
           "accepted close returns a cancelled run")
    (check (not (null (close-result-receipt result)))
           "accepted close returns a receipt")
    (check (= 1 (getf state :record-calls))
           "accepted close records once")
    (check (eq (first (getf state :runs)) (close-result-run result))
           "accepted close records its returned run")
    (check (eq (first (getf state :receipts)) (close-result-receipt result))
           "accepted close records its returned receipt")))

;; (d) every closed terminal target is reachable from a running run.
(dolist (target '(:cancelled :evacuated :dead))
  (multiple-value-bind (ports snapshot)
      (make-close-fake)
    (let ((result (close-run-with ports (close-request-with :target target)))
          (state (funcall snapshot)))
      (check (eql :accepted (close-result-status result))
             "admitted proposal accepts every terminal close target")
      (check (eql target (hngh.domain:run-state (close-result-run result)))
             "accepted close advances to the requested target")
      (check (= 1 (getf state :record-calls))
             "terminal close records once"))))

;; (e) a refused proposal refuses the close and preserves the source run.
(multiple-value-bind (ports snapshot)
    (make-close-fake)
  (let* ((source (running-close-source))
         (result (close-run-with ports
                                 (close-request-with
                                  :run source
                                  :proposal (refused-close-proposal))))
         (state (funcall snapshot)))
    (check (eql :refused (close-result-status result))
           "refused proposal refuses the run close")
    (check (member "missing-principle-result" (close-result-labels result)
                   :test #'string=)
           "refused close carries the verdict reason labels")
    (check (eql :running (hngh.domain:run-state source))
           "refused close preserves the source run")
    (check (zerop (getf state :record-calls))
           "refused close does not record")))

;; (f) an illegal transition refuses with the closed transition label.
(multiple-value-bind (ports snapshot)
    (make-close-fake)
  (let ((result (close-run-with ports
                                (close-request-with
                                 :run (created-application-run)
                                 :target :evacuated)))
        (state (funcall snapshot)))
    (check (eql :refused (close-result-status result))
           "illegal close transition is refused")
    (check (member "invalid-transition" (close-result-labels result)
                   :test #'string=)
           "illegal close carries the invalid-transition label")
    (check (zerop (getf state :record-calls))
           "illegal close transition does not record")))

;; (g) record conflict is closed and atomic.
(multiple-value-bind (ports snapshot)
    (make-close-fake :record-result :conflict)
  (let ((result (close-run-with ports (close-request-with)))
        (state (funcall snapshot)))
    (check (eql :conflict (close-result-status result))
           "close recording conflict is closed")
    (check (= 1 (getf state :record-calls))
           "close recording conflict does not retry")
    (check (and (null (getf state :runs)) (null (getf state :receipts)))
           "close recording conflict stays atomic")))

;; (h) record callback errors are refused.
(let ((ports (application-call
              "MAKE-RUN-CLOSE-PORTS"
              :record-run (lambda (run receipt)
                            (declare (ignore run receipt))
                            (error "record failed")))))
  (check (eql :refused (close-result-status
                        (close-run-with ports (close-request-with))))
         "close record callback errors are refused"))

;; (i) malformed callback returns are refused.
(multiple-value-bind (ports snapshot)
    (make-close-fake :record-result :malformed)
  (let ((result (close-run-with ports (close-request-with)))
        (state (funcall snapshot)))
    (check (eql :refused (close-result-status result))
           "malformed close record return is refused")
    (check (= 1 (getf state :record-calls))
           "malformed close record return invokes record once")
    (check (and (null (getf state :runs)) (null (getf state :receipts)))
           "malformed close record return stays atomic")))

;; (j) wrong-typed ports and requests are refused.
(check (signals-error-p
        (lambda ()
          (hngh.application:close-run :not-ports (close-request-with))))
       "close-run rejects non-ports input")
(check (signals-error-p
        (lambda ()
          (multiple-value-bind (ports) (make-close-fake)
            (hngh.application:close-run ports :not-a-request))))
       "close-run rejects non-request input")
