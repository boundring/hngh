(in-package :hngh.tests)

(defun start-run-with (ports run)
  (application-call "START-RUN" ports run))

(defun armed-application-run ()
  (hngh.domain:advance-run (created-application-run) :armed))

(let ((constructor
        (lambda (&rest arguments)
          (apply (application-function "MAKE-RUN-START-PORTS") arguments))))
  (dolist (arguments
           (list '()
                 (list :record-run :invalid)))
    (check (signals-error-p (lambda () (apply constructor arguments)))
           "start ports reject missing or non-function recording callbacks")))

(multiple-value-bind (ports snapshot)
    (make-start-fake)
  (let ((result (start-run-with ports (armed-application-run)))
        (state (funcall snapshot)))
    (check (eql :accepted (application-result-value "APPLICATION-RESULT-STATUS" result))
           "armed run start is accepted")
    (check (eql :running
                (hngh.domain:run-state
                 (application-result-value "APPLICATION-RESULT-RUN" result)))
           "armed run start returns a running replacement")
    (check (not (null (application-result-value "APPLICATION-RESULT-RECEIPT" result)))
           "armed run start returns a receipt")
    (check (= 1 (getf state :record-calls))
           "armed run start records once")
    (check (eq (first (getf state :runs))
               (application-result-value "APPLICATION-RESULT-RUN" result))
           "armed run start records its returned run")
    (check (eq (first (getf state :receipts))
               (application-result-value "APPLICATION-RESULT-RECEIPT" result))
           "armed run start records its returned receipt")))

(let ((source (created-application-run)))
  (multiple-value-bind (ports snapshot)
      (make-start-fake)
    (let ((result (start-run-with ports source))
          (state (funcall snapshot)))
      (check (eql :refused
                  (application-result-value "APPLICATION-RESULT-STATUS" result))
             "non-armed run start is refused")
      (check (eql :created (hngh.domain:run-state source))
             "refused start preserves its source run")
      (check (zerop (getf state :record-calls))
             "refused start does not record"))))

(multiple-value-bind (ports snapshot)
    (make-start-fake :record-result :conflict)
  (let ((result (start-run-with ports (armed-application-run)))
        (state (funcall snapshot)))
    (check (eql :conflict
                (application-result-value "APPLICATION-RESULT-STATUS" result))
           "start recording conflict is closed")
    (check (= 1 (getf state :record-calls))
           "start recording conflict does not retry")
    (check (and (null (getf state :runs)) (null (getf state :receipts)))
           "start recording conflict stays atomic")))

(let ((record-calls 0))
  (let ((ports (application-call
                "MAKE-RUN-START-PORTS"
                :record-run (lambda (run receipt)
                              (declare (ignore run receipt))
                              (incf record-calls)
                              (error "recording failed")))))
    (check (eql :refused
                (application-result-value
                 "APPLICATION-RESULT-STATUS"
                 (start-run-with ports (armed-application-run))))
           "start recording callback errors are refused")
    (check (= 1 record-calls)
           "start recording callback errors do not retry")))

(multiple-value-bind (ports snapshot)
    (make-start-fake)
  (let ((original (symbol-function 'hngh.domain:advance-run)))
    (unwind-protect
        (progn
          (setf (symbol-function 'hngh.domain:advance-run)
                (lambda (&rest arguments)
                  (declare (ignore arguments))
                  (error "domain transition failed")))
          (check (signals-error-p
                  (lambda () (start-run-with ports (armed-application-run))))
                 "unexpected start transition failure remains visible")
          (check (zerop (getf (funcall snapshot) :record-calls))
                 "unexpected start transition failure does not record"))
      (setf (symbol-function 'hngh.domain:advance-run) original))))
