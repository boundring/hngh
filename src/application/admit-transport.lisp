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