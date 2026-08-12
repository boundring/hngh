(in-package #:hngh.application)

(defun start-receipt ()
  (hngh.domain:make-receipt :kind :start :facts '("running")))

(defun start-run (ports run)
  (unless (run-start-ports-p ports)
    (error "start run requires run start ports"))
  (handler-case
      (let ((running-run (hngh.domain:advance-run run :running))
            (receipt (start-receipt)))
        (multiple-value-bind (record-status record-result)
            (callback-value
             (lambda ()
               (funcall (%run-start-ports-record-run ports) running-run receipt)))
          (unless (eq record-status :returned)
            (return-from start-run (callback-refusal)))
          (case record-result
            (:recorded
             (make-application-result :accepted
                                      :run running-run
                                      :receipt receipt
                                      :facts '("running")))
            (:conflict
             (make-application-result :conflict
                                      :labels '("record-conflict")))
            (otherwise (callback-refusal)))))
    (hngh.domain:invalid-run-transition ()
      (make-application-result :refused :labels '("invalid-transition")))))
