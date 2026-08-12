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
