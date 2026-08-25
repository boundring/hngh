(in-package #:hngh.adapters.worker)

;;;; Rung 18: the bounded read-only worker task.
;;;; The worker-rung first slice: ONE closed, read-only worker task through
;;;; an injected transport, mapping to a WORKER-RESULT that binds a :worker
;;;; evidence fact when complete. The worker executes no mutation and never
;;;; carries a certificate: a worker self-report is evidence, never
;;;; acceptance (per the Pi survey). The request is bounded (a short task
;;;; label plus an optional small payload); the transport is injected and
;;;; no default exists, so nothing runs a worker by accident. The adapter
;;;; never decides policy and never contacts a worker directly.

(defparameter +max-worker-task-length+ 256
  "Bound on one worker task label.")
(defparameter +max-worker-payload-length+ 65536
  "Bound on one worker payload (MITRE: bounded, never streamed).")

(defun worker-task-p (task)
  "A task label is a nonempty printable string within the bound (plain
prose allowed; only control characters refuse)."
  (and (stringp task)
       (plusp (length task))
       (<= (length task) +max-worker-task-length+)
       (notany (lambda (char)
                 (or (char< char #\Space) (char= char (code-char 127))))
               task)))

(defun worker-payload-p (payload)
  "A payload is NIL or a bounded printable string."
  (or (null payload)
      (and (stringp payload)
           (plusp (length payload))
           (<= (length payload) +max-worker-payload-length+))))

;;; Request -----------------------------------------------------------

(defstruct (worker-request
            (:constructor %make-worker-request (task payload))
            (:conc-name %worker-request-))
  (task nil :read-only t)
  (payload nil :read-only t))

(defun worker-request-task (request) (copy-seq (%worker-request-task request)))
(defun worker-request-payload (request)
  (let ((payload (%worker-request-payload request)))
    (and payload (copy-seq payload))))

(defun make-worker-request (&key task payload)
  (unless (worker-task-p task)
    (error "worker task must be a bounded task label: ~S" task))
  (unless (worker-payload-p payload)
    (error "worker payload must be nil or a bounded string"))
  (%make-worker-request task payload))

;;; Ports + result --------------------------------------------------------
(defstruct (worker-ports
            (:constructor %make-worker-ports (execute-worker))
              (:conc-name %worker-ports-))
  (execute-worker nil :read-only t))

(defun make-worker-ports (execute-worker)
  "WORKER-PORTS over one injected EXECUTE-WORKER callback. The callback is
called (EXECUTE-WORKER REQUEST) and must return (values exit-code stdout
stderr); a throw is a worker-fault."
  (unless (functionp execute-worker)
    (error "worker ports require an execute-worker callback"))
  (%make-worker-ports execute-worker))

(defstruct (worker-result
            (:constructor %make-worker-result (status task fact refusal-labels))
              (:conc-name %worker-result-))
  (status nil :read-only t)         ;; :complete | :refused | :fault
  (task nil :read-only t)
  (fact nil :read-only t)           ;; :worker evidence fact when complete
  (refusal-labels nil :read-only t))

(defun worker-result-status (result) (%worker-result-status result))
(defun worker-result-task (result) (copy-seq (%worker-result-task result)))
(defun worker-result-fact (result) (%worker-result-fact result))
(defun worker-result-refusal-labels (result)
  (mapcar #'copy-seq (%worker-result-refusal-labels result)))

(defun complete-worker (request stdout)
  "Bind the completed task to a :worker evidence fact (the fingerprint is
the task label; state :current). A worker completion is evidence only."
  (%make-worker-result
   :complete (%worker-request-task request)
   (hngh.domain:make-evidence-fact
    :kind :worker
    :fingerprint (%worker-request-task request)
    :state :current)
   nil))
(defun refused-worker ()
  (%make-worker-result :refused nil nil '("worker-refused")))
(defun faulted-worker (labels)
  (%make-worker-result :fault nil nil labels))

(defun run-worker-task (request ports)
  "Run one WORKER-REQUEST through PORTS' injected transport. A zero exit
completes (binding a :worker :current evidence fact), a nonzero exit
refuses, and a throw faults. No default transport exists."
  (unless (worker-request-p request)
    (error "run-worker-task requires a worker request"))
  (unless (worker-ports-p ports)
    (error "run-worker-task requires worker ports"))
  (multiple-value-bind (exit-code stdout stderr)
      (handler-case
          (funcall (%worker-ports-execute-worker ports) request)
        (error () (values nil nil nil)))
    (declare (ignore stdout stderr))
    (unless (integerp exit-code)
      (return-from run-worker-task (faulted-worker '("worker-fault"))))
    (unless (zerop exit-code)
      (return-from run-worker-task (refused-worker)))
    (complete-worker request stdout)))