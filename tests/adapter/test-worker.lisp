(in-package :hngh.tests)

;;;; Rung 18: the bounded read-only worker task (worker-rung first slice).
;;;; Covers the worker adapter (src/adapter/worker.lisp): a closed
;;;; WORKER-REQUEST (one task through an injected transport) mapping to a
;;;; WORKER-RESULT with a :worker evidence fact when complete; the
;;;; :worker transport admission label; and the operator-surface
;;;; run-worker command. Everything is fixture-backed; no subprocess and
;;;; no wire anywhere in this file.

;;; Adapter: request / ports / result --------------------------------------

(defun worker-run (&key (task "scout candidate evidence") payload
                        (exit-code 0) (fault nil))
  "Run the worker adapter with a fixture transport; returns (values
result seen-args)."
  (let ((seen nil))
    (let ((ports (hngh.adapters.worker:make-worker-ports
                  (lambda (request)
                    (setf seen
                          (list (hngh.adapters.worker:worker-request-task request)
                                (hngh.adapters.worker:worker-request-payload request)))
                    (when fault (error "worker transport fault"))
                    (values exit-code "worker done" "")))))
      (values
       (hngh.adapters.worker:run-worker-task
        (hngh.adapters.worker:make-worker-request
         :task task :payload payload)
        ports)
       seen))))

(defun worker-status (result)
  (hngh.adapters.worker:worker-result-status result))
(defun worker-labels (result)
  (hngh.adapters.worker:worker-result-refusal-labels result))

(check (signals-error-p
        (lambda () (hngh.adapters.worker:make-worker-ports "not-a-function")))
       "worker ports refuse a non-function transport")

(multiple-value-bind (result seen)
    (worker-run)
  (check (eq :complete (worker-status result))
         "a worker task through the injected transport completes")
  (check (equal '("scout candidate evidence" nil) seen)
         "the transport sees the request task and payload")
  (let ((fact (hngh.adapters.worker:worker-result-fact result)))
    (check (and (eql :worker (hngh.domain:evidence-fact-kind fact))
                (eql :current (hngh.domain:evidence-fact-state fact)))
           "a completed task binds a :worker :current evidence fact")))

(multiple-value-bind (result seen)
    (worker-run :exit-code 1)
  (check (eq :refused (worker-status result))
         "a nonzero worker exit refuses")
  (check (and (equal '("worker-refused") (worker-labels result)) seen)
         "the refused run names worker-refused and reached the transport"))

(multiple-value-bind (result seen)
    (worker-run :fault t)
  (check (eq :fault (worker-status result))
         "a thrown worker transport faults")
  (check (equal '("worker-fault") (worker-labels result))
         "the thrown task names worker-fault"))

(multiple-value-bind (result seen)
    (worker-run :payload "needs-wake")
  (check (equal '("scout candidate evidence" "needs-wake") seen)
         "the payload travels to the transport"))

;;; Admission: :worker needs the worker-task tool label ---------------------

(multiple-value-bind (ports reporter) (make-admit-fake)
  (let ((result (admit-with ports
                            (make-federation-run
                             :tool-labels '("worker-task"))
                            :worker "repository")))
    (check (eq :accepted (admit-result-status result))
           "worker is admitted with the worker-task tool label")
    (let ((state (funcall reporter)))
      (check (= 1 (getf state :record-calls))
             "worker admission records exactly one pair"))))

(multiple-value-bind (ports reporter) (make-admit-fake)
  (let ((result (admit-with ports (make-federation-run)
                            :worker "repository")))
    (check (eq :refused (admit-result-status result))
           "worker without the worker-task label is refused")
    (check (member "loadout-refuses-transport" (admit-result-labels result)
                   :test #'string=)
           "the loadout gate names loadout-refuses-transport")
    (let ((state (funcall reporter)))
      (check (zerop (getf state :record-calls))
             "an unlabeled worker admission records nothing"))))

;;; Operator surface: run-worker ---------------------------------------------

(defun worker-dispatch-root ()
  "A fresh scratch store root."
  (let ((path (uiop:with-temporary-file (:pathname path :keep t)
                (delete-file path)
                (ensure-directories-exist (uiop:ensure-directory-pathname path)))))
    path))

(defun worker-dispatch (argv &key root worker-ports)
  (let ((*error-output* (make-string-output-stream)))
    (multiple-value-list
     (hngh.main:dispatch-command
      (if root (cons (format nil "--store=~A" root) argv) argv)
      :clock-now (lambda () "2026-08-25T00:00:00Z")
      :worker-ports worker-ports))))

(defun worker-exit (result) (second result))
(defun worker-has (needle result) (search needle (first result)))

(defparameter +worker-create-args+
  '("create-run" "worker slice" "builder"
    "loadout-route-label=local" "loadout-context-limit=1" "loadout-token-limit=2"
    "loadout-cost-limit=3" "loadout-time-limit=4"
    "loadout-tool-labels=worker-task"
    "loadout-network-labels=none" "loadout-writable-scopes=repository"))

(defun worker-fixture ()
  (hngh.adapters.worker:make-worker-ports
   (lambda (request) (declare (ignore request))
     (values 0 "scout complete" ""))))

;; run-worker lifecycle: admitted + injected ports
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (let ((result (worker-dispatch '("run-worker" "run-1" "task=scout")
                                 :root root :worker-ports (worker-fixture))))
    (check (= 0 (worker-exit result))
           "run-worker runs through injected ports")
    (check (worker-has "worker status=complete" result)
           "the complete worker run renders"))
  (uiop:delete-directory-tree root :validate t))

;; run-worker refuses without ports
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (let ((result (worker-dispatch '("run-worker" "run-1" "task=scout")
                                 :root root)))
    (check (= 1 (worker-exit result))
           "run-worker without ports refuses")
    (check (worker-has "no-worker-transport" result)
           "the refusal names no-worker-transport"))
  (uiop:delete-directory-tree root :validate t))

;; run-worker refuses an unadmitted run
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (let ((result (worker-dispatch '("run-worker" "run-1" "task=scout")
                                 :root root :worker-ports (worker-fixture))))
    (check (= 1 (worker-exit result))
           "run-worker serves only a worker-admitted run")
    (check (worker-has "not admitted for worker" result)
           "the refusal names the missing admission"))
  (uiop:delete-directory-tree root :validate t))