(in-package #:hngh.application)

(defun nonempty-label-p (value)
  (and (stringp value) (plusp (length value))))

(defun copy-labels (labels name)
  (unless (and (listp labels) (every #'nonempty-label-p labels))
    (error "~A must be a list of nonempty strings" name))
  (mapcar #'copy-seq labels))

(defstruct (application-result
            (:constructor %make-application-result
                (status run receipt facts labels))
            (:conc-name %application-result-))
  (status nil :read-only t)
  (run nil :read-only t)
  (receipt nil :read-only t)
  (facts nil :read-only t)
  (labels nil :read-only t))

(defun application-result-status (result)
  (%application-result-status result))

(defun application-result-run (result)
  (%application-result-run result))

(defun application-result-receipt (result)
  (%application-result-receipt result))

(defun application-result-facts (result)
  (copy-labels (%application-result-facts result) "application result facts"))

(defun application-result-labels (result)
  (copy-labels (%application-result-labels result) "application result labels"))

(defun make-application-result (status &key run receipt facts labels)
  (unless (member status '(:accepted :refused :invalid :conflict))
    (error "unknown application status: ~S" status))
  (if (eq status :accepted)
      (unless (and run receipt)
        (error "accepted application result requires a run and receipt"))
      (when (or run receipt)
        (error "non-accepted application result cannot carry a run or receipt")))
  (%make-application-result status run receipt
                            (copy-labels facts "application result facts")
                            (copy-labels labels "application result labels")))

(defun ensure-callback (callback name)
  (unless (functionp callback)
    (error "~A must be a function" name))
  callback)

(defstruct (run-creation-ports
            (:constructor %make-run-creation-ports
                (next-identifier clock-now record-run))
            (:conc-name %run-creation-ports-))
  (next-identifier nil :read-only t)
  (clock-now nil :read-only t)
  (record-run nil :read-only t))

(defun make-run-creation-ports (&key next-identifier clock-now record-run)
  (%make-run-creation-ports
   (ensure-callback next-identifier "next identifier callback")
   (ensure-callback clock-now "clock callback")
   (ensure-callback record-run "record callback")))
