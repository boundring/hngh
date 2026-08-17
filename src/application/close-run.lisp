(in-package #:hngh.application)

(defun close-run-receipt (target verdict)
  (hngh.domain:make-receipt
   :kind :close
   :facts (cons (format nil "closed-to-~(~A~)" target)
                (hngh.domain:policy-verdict-reason-labels verdict))))

(defun close-run (ports request)
  "Close a run to a terminal state under the admitted policy proposal and
evidence process. The request carries the run, a closed terminal target
(:cancelled, :evacuated, or :dead), and a policy proposal. The proposal is
evaluated deterministically; only an :admitted verdict advances the run. A
refused verdict refuses the close and carries the verdict reason labels. An
illegal target for the run's state refuses with the closed
invalid-transition label. No certificate is issued here: the hash-bound
certificate vocabulary serves the future mutation executor, not run-state
transitions."
  (unless (run-close-ports-p ports)
    (error "close-run requires run close ports"))
  (unless (close-request-p request)
    (error "close-run requires a close request"))
  (let ((verdict (hngh.domain:evaluate-policy-proposal
                  (close-request-proposal request))))
    (unless (eql :admitted (hngh.domain:policy-verdict-state verdict))
      (return-from close-run
        (make-application-result :refused
                                 :labels (hngh.domain:policy-verdict-reason-labels
                                          verdict))))
    (handler-case
        (let ((closed-run (hngh.domain:advance-run
                           (close-request-run request)
                           (close-request-target request)))
              (receipt (close-run-receipt (close-request-target request)
                                          verdict)))
          (multiple-value-bind (record-status record-result)
              (callback-value
               (lambda ()
                 (funcall (%run-close-ports-record-run ports)
                          closed-run receipt)))
            (unless (eq record-status :returned)
              (return-from close-run (callback-refusal)))
            (case record-result
              (:recorded
               (make-application-result :accepted
                                        :run closed-run
                                        :receipt receipt
                                        :facts '("close-recorded")))
              (:conflict
               (make-application-result :conflict
                                        :labels '("record-conflict")))
              (otherwise (callback-refusal)))))
      (hngh.domain:invalid-run-transition ()
        (make-application-result :refused
                                 :labels '("invalid-transition"))))))
