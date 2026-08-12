(in-package #:hngh.application)

(defun valid-domain-value-p (reader value)
  (handler-case
      (progn (funcall reader value) t)
    (error () nil)))

(defun invalid-creation-labels (mission role loadout)
  (let ((labels '()))
    (unless (valid-domain-value-p #'hngh.domain:mission-objective mission)
      (push "mission" labels))
    (unless (valid-domain-value-p #'hngh.domain:role-template-name role)
      (push "role" labels))
    (unless (valid-domain-value-p #'hngh.domain:loadout-route-label loadout)
      (push "loadout" labels))
    (nreverse labels)))

(defun callback-refusal ()
  (make-application-result :refused :labels '("callback-contract")))

(defun creation-receipt (identifier timestamp)
  (hngh.domain:make-receipt
   :kind :creation
   :facts (list (format nil "identifier: ~A" identifier)
                (format nil "timestamp: ~A" timestamp))))

(defun callback-value (callback)
  (handler-case
      (values :returned (funcall callback))
    (error () (values :failed nil))))

(defun create-run (ports mission role loadout)
  (unless (run-creation-ports-p ports)
    (error "create run requires run creation ports"))
  (let ((invalid-labels (invalid-creation-labels mission role loadout)))
    (when invalid-labels
      (return-from create-run
        (make-application-result :invalid :labels invalid-labels))))
  (multiple-value-bind (identifier-status identifier)
      (callback-value (%run-creation-ports-next-identifier ports))
    (unless (and (eq identifier-status :returned)
                 (nonempty-label-p identifier))
      (return-from create-run (callback-refusal)))
    (multiple-value-bind (timestamp-status timestamp)
        (callback-value (%run-creation-ports-clock-now ports))
      (unless (and (eq timestamp-status :returned)
                   (nonempty-label-p timestamp))
        (return-from create-run (callback-refusal)))
      (let* ((run (hngh.domain:make-run
                   :identifier identifier
                   :mission mission
                   :role role
                   :loadout loadout))
             (receipt (creation-receipt identifier timestamp)))
        (multiple-value-bind (record-status record-result)
            (callback-value
             (lambda ()
               (funcall (%run-creation-ports-record-run ports) run receipt)))
          (unless (eq record-status :returned)
            (return-from create-run (callback-refusal)))
          (case record-result
            (:recorded
             (make-application-result :accepted
                                      :run run
                                      :receipt receipt
                                      :facts '("created")))
            (:conflict
             (make-application-result :conflict
                                      :labels '("record-conflict")))
            (otherwise (callback-refusal))))))))
