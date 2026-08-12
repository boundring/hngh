(in-package :hngh.tests)

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

(defun application-result-value (name result)
  (application-call name result))

(defun creation-result-status (result)
  (application-result-value "APPLICATION-RESULT-STATUS" result))

(defun creation-result-run (result)
  (application-result-value "APPLICATION-RESULT-RUN" result))

(defun creation-result-receipt (result)
  (application-result-value "APPLICATION-RESULT-RECEIPT" result))

(defun creation-result-labels (result)
  (application-result-value "APPLICATION-RESULT-LABELS" result))

(defun create-run-with (ports mission role loadout)
  (application-call "CREATE-RUN" ports mission role loadout))

(let ((constructor (lambda (&rest arguments)
                     (apply (application-function "MAKE-RUN-CREATION-PORTS")
                            arguments))))
  (dolist (arguments
           (list
            (list :next-identifier (lambda () "run")
                  :clock-now (lambda () "time"))
            (list :next-identifier (lambda () "run")
                  :record-run (lambda (run receipt)
                                (declare (ignore run receipt))
                                :recorded))
            (list :clock-now (lambda () "time")
                  :record-run (lambda (run receipt)
                                (declare (ignore run receipt))
                                :recorded))
            (list :next-identifier "run"
                  :clock-now (lambda () "time")
                  :record-run (lambda (run receipt)
                                (declare (ignore run receipt))
                                :recorded))
            (list :next-identifier (lambda () "run")
                  :clock-now "time"
                  :record-run (lambda (run receipt)
                                (declare (ignore run receipt))
                                :recorded))
            (list :next-identifier (lambda () "run")
                  :clock-now (lambda () "time")
                  :record-run :recorded)))
    (check (signals-error-p (lambda () (apply constructor arguments)))
           "creation ports reject missing or non-function callbacks")))

(check (signals-error-p
        (lambda () (hngh.application::make-application-result :accepted)))
       "accepted application result requires a run and receipt")

(let ((run (hngh.domain:make-run
            :identifier "inconsistent-result"
            :mission (make-application-mission)
            :role (make-application-role)
            :loadout (make-application-loadout))))
  (check (signals-error-p
          (lambda () (hngh.application::make-application-result
                      :refused :run run)))
         "non-accepted application result rejects a run"))

(let ((mission (make-application-mission))
      (role (make-application-role))
      (loadout (make-application-loadout)))
  (multiple-value-bind (ports snapshot)
      (make-creation-fake)
    (let ((result (create-run-with ports mission role loadout)))
      (let ((state (funcall snapshot)))
        (check (eql :accepted (creation-result-status result))
               "creation accepts a complete fake")
        (check (eql :created (hngh.domain:run-state (creation-result-run result)))
               "creation returns a created run")
        (check (not (null (creation-result-receipt result)))
               "creation returns one receipt")
        (check (= 1 (getf state :identifier-calls))
               "creation requests one identifier")
        (check (= 1 (getf state :clock-calls))
               "creation requests one timestamp")
        (check (= 1 (getf state :record-calls))
               "creation records once")
        (check (= 1 (length (getf state :runs)))
               "creation fake records one run")
        (check (= 1 (length (getf state :receipts)))
               "creation fake records one receipt")
        (check (eq (first (getf state :runs)) (creation-result-run result))
               "creation records its returned run")
        (check (eq (first (getf state :receipts)) (creation-result-receipt result))
               "creation records its returned receipt")))))

(dolist (invalid-input
         (list (list nil (make-application-role) (make-application-loadout) "mission")
               (list (make-application-mission) :not-a-role
                     (make-application-loadout) "role")
               (list (make-application-mission) (make-application-role)
                     :not-a-loadout "loadout")))
  (multiple-value-bind (ports snapshot)
      (make-creation-fake)
    (let* ((result (apply #'create-run-with ports (subseq invalid-input 0 3)))
           (state (funcall snapshot))
           (labels (creation-result-labels result)))
      (check (eql :invalid (creation-result-status result))
             "invalid top-level input is closed")
      (check (member (fourth invalid-input) labels :test #'string=)
             "invalid result identifies its top-level label")
      (setf (first labels) "changed")
      (check (member (fourth invalid-input) (creation-result-labels result)
                     :test #'string=)
             "application result labels are defensive copies")
      (check (and (zerop (getf state :identifier-calls))
                  (zerop (getf state :clock-calls))
                  (zerop (getf state :record-calls)))
             "invalid input makes no callback call"))))

(let ((mission (make-application-mission))
      (role (make-application-role))
      (loadout (make-application-loadout)))
  (multiple-value-bind (ports snapshot)
      (make-creation-fake :record-result :conflict)
    (let ((result (create-run-with ports mission role loadout))
          (state (funcall snapshot)))
      (check (eql :conflict (creation-result-status result))
             "recording conflict is closed")
      (check (= 1 (getf state :record-calls))
             "recording conflict does not retry")
      (check (and (null (getf state :runs)) (null (getf state :receipts)))
             "recording conflict leaves the fake atomic"))))

(let ((mission (make-application-mission))
      (role (make-application-role))
      (loadout (make-application-loadout)))
  (dolist (arguments (list (list :identifier "" :timestamp "time")
                           (list :identifier "run" :timestamp "")))
    (multiple-value-bind (ports snapshot)
        (apply #'make-creation-fake arguments)
      (let ((result (create-run-with ports mission role loadout))
            (state (funcall snapshot)))
        (check (eql :refused (creation-result-status result))
               "malformed identifier or timestamp is refused")
        (check (zerop (getf state :record-calls))
               "malformed identifier or timestamp does not record")))))

(let ((mission (make-application-mission))
      (role (make-application-role))
      (loadout (make-application-loadout)))
  (multiple-value-bind (ports snapshot)
      (make-creation-fake)
    (let ((original (symbol-function 'hngh.domain:make-run)))
      (unwind-protect
          (progn
            (setf (symbol-function 'hngh.domain:make-run)
                  (lambda (&rest arguments)
                    (declare (ignore arguments))
                    (error "domain construction failed")))
            (check (signals-error-p
                    (lambda () (create-run-with ports mission role loadout)))
                   "domain construction failure remains visible")
            (check (zerop (getf (funcall snapshot) :record-calls))
                   "domain construction failure does not record"))
        (setf (symbol-function 'hngh.domain:make-run) original)))))

(let ((mission (make-application-mission))
      (role (make-application-role))
      (loadout (make-application-loadout))
      (record-calls 0))
  (let ((ports (application-call
                "MAKE-RUN-CREATION-PORTS"
                :next-identifier (lambda () "run-created-1")
                :clock-now (lambda () "2026-08-11T00:00:00Z")
                :record-run (lambda (run receipt)
                              (declare (ignore run receipt))
                              (incf record-calls)
                              (error "recording failed")))))
    (check (eql :refused
                (creation-result-status
                 (create-run-with ports mission role loadout)))
           "callback error is refused")
    (check (= 1 record-calls)
           "callback error does not retry")))

(let ((mission (make-application-mission))
      (role (make-application-role))
      (loadout (make-application-loadout)))
  (multiple-value-bind (ports snapshot)
      (make-creation-fake :record-result :unexpected)
    (let ((result (create-run-with ports mission role loadout))
          (state (funcall snapshot)))
      (check (eql :refused (creation-result-status result))
             "malformed callback result is refused")
      (check (= 1 (getf state :record-calls))
             "malformed callback result does not retry")
      (check (and (null (getf state :runs)) (null (getf state :receipts)))
             "malformed callback result records nothing"))))
