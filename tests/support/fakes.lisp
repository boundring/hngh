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

(defun adapter-symbol (name)
  (let ((package (find-package :hngh.adapters.evidence)))
    (unless package
      (error "adapter package is unavailable"))
    (multiple-value-bind (symbol status) (find-symbol name package)
      (unless (and symbol (eq status :external))
        (error "adapter symbol is unavailable: ~A" name))
      symbol)))

(defun adapter-value (name)
  (symbol-value (adapter-symbol name)))

(defun adapter-function (name)
  (let ((symbol (adapter-symbol name)))
    (unless (fboundp symbol)
      (error "adapter function is unavailable: ~A" name))
    (symbol-function symbol)))

(defun adapter-call (name &rest arguments)
  (apply (adapter-function name) arguments))

(defun make-evidence-ports-fake (&key responses)
  "Evidence transport fake. RESPONSES is a list; each element is
(:return exit-code stdout stderr) or (:error message). Answers are
consumed in order; the reporter returns call count, argv history,
and remaining response count."
  (let ((calls 0)
        (argv-seen '())
        (remaining (copy-list responses)))
    (values
     (lambda (argv)
       (incf calls)
       (push (copy-list argv) argv-seen)
       (let ((response (pop remaining)))
         (ecase (first response)
           (:error (error (second response)))
           (:return (values (second response)
                            (third response)
                            (fourth response))))))
     (lambda ()
       (list :calls calls
             :argv-seen (nreverse argv-seen)
             :remaining (length remaining))))))

(defun make-mutation-ports-fake (&key (exit-code 0) (stdout "ok\n")
                                      (stderr "") fault gather-result)
  "Mutation transport fake. It records exact argv and returns bounded fixture
output; GATHER-RESULT, when supplied, is returned by the evidence callback."
  (let ((calls 0)
        (argv-seen '()))
    (values
     (hngh.adapters.mutation:make-mutation-ports
      :run-process
      (lambda (argv)
        (incf calls)
        (push (copy-list argv) argv-seen)
        (when fault (error "mutation transport fault"))
        (values exit-code stdout stderr))
      :gather-evidence
      (when gather-result
        (lambda (certificate)
          (declare (ignore certificate))
          gather-result)))
     (lambda ()
       (list :calls calls :argv-seen (nreverse argv-seen))))))

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

(defun make-checkpoint-fake (&key
                              (verification
                               (application-call
                                "MAKE-VERIFICATION-RESULT"
                                :status :passed
                                :labels '("tests-pass")))
                              (manifest
                               (application-call
                                "MAKE-MANIFEST-RESULT"
                                :status :complete
                                :labels '("manifest-complete")))
                              (record-result :recorded))
  (let ((tool-calls 0)
        (repository-calls 0)
        (record-calls 0)
        (runs '())
        (receipts '()))
    (values
     (application-call
      "MAKE-RUN-CHECKPOINT-PORTS"
      :tool-executor
      (lambda (request)
        (declare (ignore request))
        (incf tool-calls)
        verification)
      :repository-inspector
      (lambda (request)
        (declare (ignore request))
        (incf repository-calls)
        manifest)
      :record-run
      (lambda (run receipt)
        (incf record-calls)
        (when (eql record-result :recorded)
          (setf runs (append runs (list run))
                receipts (append receipts (list receipt))))
        record-result))
     (lambda ()
       (list :tool-calls tool-calls
             :repository-calls repository-calls
             :record-calls record-calls
             :runs (copy-list runs)
             :receipts (copy-list receipts))))))

(defun make-close-fake (&key (record-result :recorded))
  (let ((record-calls 0)
        (runs '())
        (receipts '()))
    (values
     (application-call
      "MAKE-RUN-CLOSE-PORTS"
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
