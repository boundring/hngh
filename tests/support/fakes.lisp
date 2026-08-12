(in-package :hngh.tests)

(defun application-function (name)
  (let ((package (find-package :hngh.application)))
    (unless package
      (error "application package is unavailable"))
    (multiple-value-bind (symbol status) (find-symbol name package)
      (unless (and symbol (eq status :external) (fboundp symbol))
        (error "application function is unavailable: ~A" name))
      (symbol-function symbol))))

(defun application-call (name &rest arguments)
  (apply (application-function name) arguments))

(defun make-application-mission ()
  (hngh.domain:make-mission
   :objective "Create a valid run"
   :non-objectives '("Persist a partial record")
   :source-references '("docs/core/run-contract.md")
   :acceptance-criteria '("One atomic record")
   :writable-scopes '("repository")
   :verification "make test"
   :evacuation-condition "Creation is refused"))

(defun make-application-role ()
  (hngh.domain:make-role-template
   :name "builder"
   :capabilities '("edit")
   :required-review-role "reviewer"
   :permitted-loadout-classes '("manual")))

(defun make-application-loadout ()
  (hngh.domain:make-loadout
   :route-label :local
   :context-limit 1
   :token-limit 2
   :cost-limit 3
   :time-limit 4
   :tool-labels '("make-test")
   :network-labels '("none")
   :writable-scopes '("repository")))

(defun created-application-run ()
  (hngh.domain:make-run
   :identifier "run-application-1"
   :mission (make-application-mission)
   :role (make-application-role)
   :loadout (make-application-loadout)))

(defun make-creation-fake (&key
                             (identifier "run-created-1")
                             (timestamp "2026-08-11T00:00:00Z")
                             (record-result :recorded))
  (let ((identifier-calls 0)
        (clock-calls 0)
        (record-calls 0)
        (runs '())
        (receipts '()))
    (values
     (application-call
      "MAKE-RUN-CREATION-PORTS"
      :next-identifier
      (lambda ()
        (incf identifier-calls)
        identifier)
      :clock-now
      (lambda ()
        (incf clock-calls)
        timestamp)
      :record-run
      (lambda (run receipt)
        (incf record-calls)
        (when (eql record-result :recorded)
          (setf runs (append runs (list run))
                receipts (append receipts (list receipt))))
        record-result))
     (lambda ()
       (list :identifier-calls identifier-calls
             :clock-calls clock-calls
             :record-calls record-calls
             :runs (copy-list runs)
             :receipts (copy-list receipts))))))

(defun make-admission-fake (facts &key (record-result :recorded))
  (let ((facts-calls 0)
        (record-calls 0)
        (runs '())
        (receipts '()))
    (values
     (application-call
      "MAKE-RUN-ADMISSION-PORTS"
      :admission-facts
      (lambda (run)
        (declare (ignore run))
        (incf facts-calls)
        facts)
      :record-run
      (lambda (run receipt)
        (incf record-calls)
        (when (eql record-result :recorded)
          (setf runs (append runs (list run))
                receipts (append receipts (list receipt))))
        record-result))
     (lambda ()
       (list :facts-calls facts-calls
             :record-calls record-calls
             :runs (copy-list runs)
             :receipts (copy-list receipts))))))

(defun make-start-fake (&key (record-result :recorded))
  (let ((record-calls 0)
        (runs '())
        (receipts '()))
    (values
     (application-call
      "MAKE-RUN-START-PORTS"
      :record-run
      (lambda (run receipt)
        (incf record-calls)
        (when (eql record-result :recorded)
          (setf runs (append runs (list run))
                receipts (append receipts (list receipt))))
        record-result))
     (lambda ()
       (list :record-calls record-calls
             :runs (copy-list runs)
             :receipts (copy-list receipts))))))
