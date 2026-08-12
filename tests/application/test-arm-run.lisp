(in-package :hngh.tests)

(defun admission-result-status (result)
  (application-result-value "APPLICATION-RESULT-STATUS" result))

(defun admission-result-run (result)
  (application-result-value "APPLICATION-RESULT-RUN" result))

(defun admission-result-receipt (result)
  (application-result-value "APPLICATION-RESULT-RECEIPT" result))

(defun arm-run-with (ports run)
  (application-call "ARM-RUN" ports run))

(defun admission-facts-with (&key
                              (authority :confirmed)
                              (ledger :confirmed)
                              (loadout :confirmed)
                              (exclusive-write :confirmed))
  (application-call "MAKE-ADMISSION-FACTS"
                    :authority authority
                    :ledger ledger
                    :loadout loadout
                    :exclusive-write exclusive-write))

(defun created-application-run ()
  (hngh.domain:make-run
   :identifier "run-admission-1"
   :mission (make-application-mission)
   :role (make-application-role)
   :loadout (make-application-loadout)))

(dolist (status '(:confirmed :unknown :refused))
  (let ((facts (admission-facts-with
                :authority status
                :ledger status
                :loadout status
                :exclusive-write status)))
    (check (eql status (application-call "ADMISSION-FACTS-AUTHORITY" facts))
           "admission facts preserve authority status")
    (check (eql status (application-call "ADMISSION-FACTS-LEDGER" facts))
           "admission facts preserve ledger status")
    (check (eql status (application-call "ADMISSION-FACTS-LOADOUT" facts))
           "admission facts preserve loadout status")
    (check (eql status
                (application-call "ADMISSION-FACTS-EXCLUSIVE-WRITE" facts))
           "admission facts preserve exclusive-write status")))

(dolist (arguments
         (list (list :ledger :confirmed :loadout :confirmed
                     :exclusive-write :confirmed)
               (list :authority :invalid :ledger :confirmed :loadout :confirmed
                     :exclusive-write :confirmed)
               (list :authority :confirmed :ledger "confirmed" :loadout :confirmed
                     :exclusive-write :confirmed)
               (list :authority :confirmed :ledger :confirmed :loadout nil
                     :exclusive-write :confirmed)
               (list :authority :confirmed :ledger :confirmed :loadout :confirmed
                     :exclusive-write :invalid)))
  (check (signals-error-p
          (lambda ()
            (apply (application-function "MAKE-ADMISSION-FACTS") arguments)))
         "admission facts reject missing or malformed statuses"))

(dolist (arguments
         (list (list :record-run (lambda (run receipt)
                                  (declare (ignore run receipt))
                                  :recorded))
               (list :admission-facts (lambda (run)
                                        (declare (ignore run))
                                        (admission-facts-with)))
               (list :admission-facts :invalid
                     :record-run (lambda (run receipt)
                                   (declare (ignore run receipt))
                                   :recorded))
               (list :admission-facts (lambda (run)
                                        (declare (ignore run))
                                        (admission-facts-with))
                     :record-run :invalid)))
  (check (signals-error-p
          (lambda ()
            (apply (application-function "MAKE-RUN-ADMISSION-PORTS") arguments)))
         "admission ports reject missing or non-function callbacks"))

(let ((facts (admission-facts-with)))
  (multiple-value-bind (ports snapshot)
      (make-admission-fake facts)
    (let ((result (arm-run-with ports (created-application-run)))
          (state (funcall snapshot)))
      (check (eql :accepted (admission-result-status result))
             "confirmed admission is accepted")
      (check (eql :armed (hngh.domain:run-state (admission-result-run result)))
             "confirmed admission returns an armed replacement run")
      (check (not (null (admission-result-receipt result)))
             "confirmed admission returns a receipt")
      (check (= 1 (getf state :facts-calls))
             "confirmed admission requests facts once")
      (check (= 1 (getf state :record-calls))
             "confirmed admission records once")
      (check (= 1 (length (getf state :runs)))
             "confirmed admission records one run")
      (check (= 1 (length (getf state :receipts)))
             "confirmed admission records one receipt")
      (check (eq (first (getf state :runs)) (admission-result-run result))
             "confirmed admission records its returned run")
      (check (eq (first (getf state :receipts))
                 (admission-result-receipt result))
             "confirmed admission records its returned receipt"))))

(dolist (field '(:authority :ledger :loadout :exclusive-write))
  (dolist (status '(:unknown :refused))
    (let ((arguments (list :authority :confirmed
                           :ledger :confirmed
                           :loadout :confirmed
                           :exclusive-write :confirmed)))
      (setf (getf arguments field) status)
      (multiple-value-bind (ports snapshot)
          (make-admission-fake (apply #'admission-facts-with arguments))
        (let* ((run (created-application-run))
               (result (arm-run-with ports run))
               (state (funcall snapshot)))
          (check (eql :refused (admission-result-status result))
                 "unknown or refused admission is closed")
          (check (eql :created (hngh.domain:run-state run))
                 "failed admission preserves the source run")
          (check (= 1 (getf state :facts-calls))
                 "failed admission requests facts once")
          (check (zerop (getf state :record-calls))
                 "failed admission does not record"))))))

(dolist (facts (list :malformed nil))
  (multiple-value-bind (ports snapshot)
      (make-admission-fake facts)
    (let ((result (arm-run-with ports (created-application-run)))
          (state (funcall snapshot)))
      (check (eql :refused (admission-result-status result))
             "malformed admission facts are refused")
      (check (zerop (getf state :record-calls))
             "malformed admission facts do not record"))))

(let ((record-calls 0)
      (facts (admission-facts-with)))
  (let ((ports (application-call
                "MAKE-RUN-ADMISSION-PORTS"
                :admission-facts (lambda (run)
                                   (declare (ignore run))
                                   (error "fact collection failed"))
                :record-run (lambda (run receipt)
                              (declare (ignore run receipt))
                              (incf record-calls)
                              :recorded))))
    (check (eql :refused
                (admission-result-status
                 (arm-run-with ports (created-application-run))))
           "admission callback errors are refused")
    (check (zerop record-calls)
           "admission callback errors do not record")))

(let ((facts (admission-facts-with)))
  (multiple-value-bind (ports snapshot)
      (make-admission-fake facts :record-result :conflict)
    (let ((result (arm-run-with ports (created-application-run)))
          (state (funcall snapshot)))
      (check (eql :conflict (admission-result-status result))
             "admission recording conflict is closed")
      (check (= 1 (getf state :record-calls))
             "admission recording conflict does not retry")
      (check (and (null (getf state :runs)) (null (getf state :receipts)))
             "admission recording conflict stays atomic"))))

(let ((facts (admission-facts-with)))
  (multiple-value-bind (ports snapshot)
      (make-admission-fake facts)
    (let* ((source (created-application-run))
           (run (hngh.domain:advance-run source :armed))
           (result (arm-run-with ports run))
           (state (funcall snapshot)))
      (check (eql :refused (admission-result-status result))
             "non-created run is refused")
      (check (eql :armed (hngh.domain:run-state run))
             "non-created run remains unchanged")
      (check (= 1 (getf state :facts-calls))
             "non-created run requests facts once")
      (check (zerop (getf state :record-calls))
             "non-created run does not record"))))

(let ((facts (admission-facts-with)))
  (multiple-value-bind (ports snapshot)
      (make-admission-fake facts)
    (let ((original (symbol-function 'hngh.domain:advance-run)))
      (unwind-protect
          (progn
            (setf (symbol-function 'hngh.domain:advance-run)
                  (lambda (&rest arguments)
                    (declare (ignore arguments))
                    (error "domain transition failed")))
            (check (signals-error-p
                    (lambda () (arm-run-with ports (created-application-run))))
                   "unexpected domain transition failure remains visible")
            (check (zerop (getf (funcall snapshot) :record-calls))
                   "unexpected domain transition failure does not record"))
        (setf (symbol-function 'hngh.domain:advance-run) original)))))

(let ((facts (admission-facts-with))
      (record-calls 0))
  (let ((ports (application-call
                "MAKE-RUN-ADMISSION-PORTS"
                :admission-facts (lambda (run)
                                   (declare (ignore run))
                                   facts)
                :record-run (lambda (run receipt)
                              (declare (ignore run receipt))
                              (incf record-calls)
                              (error "recording failed")))))
    (check (eql :refused
                (admission-result-status
                 (arm-run-with ports (created-application-run))))
           "admission recording callback errors are refused")
    (check (= 1 record-calls)
           "admission recording callback errors do not retry")))
