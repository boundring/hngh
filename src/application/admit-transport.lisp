(in-package #:hngh.application)

;;;; admit-transport: Layer-2 admission use case.
;;;; Mirrors src/application/arm-run.lisp conventions: public entry point,
;;;; admission ports via MAKE-RUN-ADMISSION-PORTS, refusal results via
;;;; MAKE-APPLICATION-RESULT with quoted label lists, port callbacks via
;;;; CALLBACK-VALUE, failures closed via CALLBACK-REFUSAL.

(defun admitted-transport-p (transport)
  (member transport hngh.domain:+admitted-transports+ :test #'eq))

(defun admitted-scope-p (scope writable-scopes)
  (member scope writable-scopes :test #'string=))

(defun name-string (value)
  (if (stringp value)
      value
      (string-downcase (symbol-name value))))

(defun transport-loadout-refused-p (transport run)
  "True when TRANSPORT cannot be admitted because the run's loadout lacks
the required route or label. :terminal requires the terminal-input tool
label; :model requires a non-local route label and the model-review network
label; :federation requires the remote-evidence network label or the
carrier-bundle tool label. Other admitted kinds (filesystem) have no
loadout requirement."
  (let ((loadout (hngh.domain:run-loadout run)))
    (case transport
      (:terminal
       (not (member "terminal-input" (hngh.domain::%loadout-tool-labels
                                      loadout)
                    :test #'string=)))
      (:model
       (or (eq :local (hngh.domain:loadout-route-label loadout))
           (not (member "model-review" (hngh.domain::%loadout-network-labels
                                         loadout)
                        :test #'string=))))
      (:federation
       (and (not (member "remote-evidence"
                         (hngh.domain::%loadout-network-labels loadout)
                         :test #'string=))
            (not (member "carrier-bundle"
                         (hngh.domain::%loadout-tool-labels loadout)
                         :test #'string=))))
      (:worker
       (not (member "worker-task" (hngh.domain::%loadout-tool-labels loadout)
                    :test #'string=)))
      (t nil))))

(defun transport-admission-receipt (run transport scope timestamp)
  (hngh.domain:make-receipt
   :kind :admission
   :facts (list (format nil "transport: ~A" (name-string transport))
                (format nil "scope: ~A" (name-string scope))
                (format nil "route: ~A"
                        (name-string (hngh.domain:loadout-route-label
                                      (hngh.domain:run-loadout run))))
                (format nil "run: ~A" (hngh.domain:run-identifier run))
                (format nil "timestamp: ~A" timestamp))))

(defun admit-transport (ports run transport &optional scope)
  (unless (run-admission-ports-p ports)
    (error "admit transport requires run admission ports"))
  (unless (and (keywordp transport)
               (admitted-transport-p transport))
    (return-from admit-transport
      (make-application-result :refused :labels '("unknown-transport"))))
  (unless (member (hngh.domain:run-state run) '(:created :armed))
    (return-from admit-transport
      (make-application-result :refused :labels '("invalid-transition"))))
  (when (transport-loadout-refused-p transport run)
    (return-from admit-transport
      (make-application-result :refused :labels '("loadout-refuses-transport"))))
  (let* ((writable-scopes (hngh.domain::%loadout-writable-scopes
                            (hngh.domain:run-loadout run)))
         (effective-scope (or scope (first writable-scopes))))
    (unless (and effective-scope
                 (admitted-scope-p effective-scope writable-scopes))
      (return-from admit-transport
        (make-application-result :refused :labels '("unauthorized-scope"))))
    (multiple-value-bind (clock-status timestamp)
        (callback-value
         (lambda ()
           (funcall (%run-admission-ports-clock-now ports))))
      (unless (and (eq clock-status :returned)
                   (stringp timestamp))
        (return-from admit-transport (callback-refusal)))
      (let ((receipt (transport-admission-receipt
                      run transport effective-scope timestamp)))
        (multiple-value-bind (record-status record-result)
            (callback-value
             (lambda ()
               (funcall (%run-admission-ports-record-run ports)
                        run receipt)))
          (unless (eq record-status :returned)
            (return-from admit-transport (callback-refusal)))
          (case record-result
            (:recorded
             (make-application-result :accepted
                                      :run run
                                      :receipt receipt
                                      :facts '("admitted")))
            (:conflict
             (make-application-result :conflict
                                      :labels '("duplicate-admission")))
            (otherwise (callback-refusal))))))))