(in-package #:hngh.application)

(defun confirmed-admission-p (facts)
  (and (admission-facts-p facts)
       (every (lambda (status) (eq status :confirmed))
              (list (admission-facts-authority facts)
                    (admission-facts-ledger facts)
                    (admission-facts-loadout facts)
                    (admission-facts-exclusive-write facts)))))

(defun admission-receipt (facts)
  (declare (ignore facts))
  (hngh.domain:make-receipt :kind :admission :facts '("armed")))

(defun arm-run (ports run)
  (unless (run-admission-ports-p ports)
    (error "arm run requires run admission ports"))
  (multiple-value-bind (facts-status facts)
      (callback-value
       (lambda ()
         (funcall (%run-admission-ports-admission-facts ports) run)))
    (unless (and (eq facts-status :returned)
                 (confirmed-admission-p facts))
      (return-from arm-run (callback-refusal)))
    (handler-case
        (let ((armed-run (hngh.domain:advance-run run :armed))
              (receipt (admission-receipt facts)))
          (multiple-value-bind (record-status record-result)
              (callback-value
               (lambda ()
                 (funcall (%run-admission-ports-record-run ports)
                          armed-run receipt)))
            (unless (eq record-status :returned)
              (return-from arm-run (callback-refusal)))
            (case record-result
              (:recorded
               (make-application-result :accepted
                                        :run armed-run
                                        :receipt receipt
                                        :facts '("armed")))
              (:conflict
               (make-application-result :conflict
                                        :labels '("record-conflict")))
              (otherwise (callback-refusal)))))
      (hngh.domain:invalid-run-transition ()
        (make-application-result :refused :labels '("invalid-transition"))))))
