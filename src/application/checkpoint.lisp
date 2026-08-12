(in-package #:hngh.application)

(defun accepted-checkpoint-evidence-p (verification manifest)
  (and (verification-result-p verification)
       (manifest-result-p manifest)
       (eq :passed (verification-result-status verification))
       (eq :complete (manifest-result-status manifest))))

(defun checkpoint-receipt (verification manifest)
  (hngh.domain:make-receipt
   :kind :checkpoint
   :facts (append (verification-result-labels verification)
                  (manifest-result-labels manifest))))

(defun checkpoint (ports run)
  (unless (run-checkpoint-ports-p ports)
    (error "checkpoint requires run checkpoint ports"))
  (let ((request (make-checkpoint-request :run run)))
    (multiple-value-bind (verification-status verification)
        (callback-value
         (lambda ()
           (funcall (%run-checkpoint-ports-tool-executor ports) request)))
      (unless (and (eq verification-status :returned)
                   (verification-result-p verification))
        (return-from checkpoint (callback-refusal)))
      (multiple-value-bind (manifest-status manifest)
          (callback-value
           (lambda ()
             (funcall (%run-checkpoint-ports-repository-inspector ports) request)))
        (unless (and (eq manifest-status :returned)
                     (manifest-result-p manifest))
          (return-from checkpoint (callback-refusal)))
        (unless (accepted-checkpoint-evidence-p verification manifest)
          (return-from checkpoint (callback-refusal)))
        (handler-case
            (let ((checkpointed-run (hngh.domain:advance-run run :checkpointed))
                  (receipt (checkpoint-receipt verification manifest)))
              (multiple-value-bind (record-status record-result)
                  (callback-value
                   (lambda ()
                     (funcall (%run-checkpoint-ports-record-run ports)
                              checkpointed-run receipt)))
                (unless (eq record-status :returned)
                  (return-from checkpoint (callback-refusal)))
                (case record-result
                  (:recorded
                   (make-application-result :accepted
                                            :run checkpointed-run
                                            :receipt receipt
                                            :facts (append
                                                    (verification-result-labels verification)
                                                    (manifest-result-labels manifest))))
                  (:conflict
                   (make-application-result :conflict
                                            :labels '("record-conflict")))
                  (otherwise (callback-refusal)))))
          (hngh.domain:invalid-run-transition ()
            (make-application-result :refused :labels '("invalid-transition"))))))))
