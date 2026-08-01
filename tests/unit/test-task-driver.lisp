;;;; tests/unit/test-task-driver.lisp — Tests for the M3 task driver
;;;;
;;;; Queue persistence, tick transitions, scheduler registration.
;;;; delegate is stubbed — no network, no real tool invocations.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.task-driver
  :description "Tests for the M3 task driver (queue + scheduler-driven execution)"
  :in :hngh)

(in-suite :hngh.task-driver)

;;; --- Helpers ---------------------------------------------------------------

(defun %stub-agent (task &key (status :completed) (result "stub-result"))
  "Build an agent-info that looks like a finished invocation. No network."
  (hngh.plugins.ai-orchestrator::make-agent-info
   :id 999 :tool :local-openai-api :task task
   :status status :result result :cost 0.0
   :started-at (get-universal-time)))

(defmacro with-delegate-stub ((status result) &body body)
  "Run BODY with ai-orchestrator::delegate stubbed (no network)."
  (let ((orig (gensym)))
    `(let ((,orig (symbol-function 'hngh.plugins.ai-orchestrator::delegate)))
       (unwind-protect
            (progn
              (setf (symbol-function 'hngh.plugins.ai-orchestrator::delegate)
                    (lambda (task &key preferences context)
                      (declare (ignore preferences context))
                      (%stub-agent task :status ,status :result ,result)))
              ,@body)
         (setf (symbol-function 'hngh.plugins.ai-orchestrator::delegate) ,orig)))))

;;; --- Tests -----------------------------------------------------------------

(test queue-record-normalizes-v1-entry
  "Old queue entries gain v2 control fields without losing recorded values."
  (let ((entry (hngh.plugins.ai-orchestrator::normalize-task-record
                '(:id 41 :task "keep this" :status :done :result "artifact"))))
    (is (= 2 (getf entry :schema-version)))
    (is (eq :advisory (getf entry :authority)))
    (is (null (getf entry :approval-at)))
    (is (equal '() (getf entry :depends-on)))
    (is (= 0 (getf entry :attempt)))
    (is (= 1 (getf entry :max-attempts)))
    (is (= 41 (getf entry :id)))
    (is (string= "keep this" (getf entry :task)))
    (is (string= "artifact" (getf entry :result)))))

(test queue-record-validation-rejects-invalid-fields
  "Queue records fail closed when their control fields are malformed."
  (labels ((valid ()
             (hngh.plugins.ai-orchestrator::normalize-task-record
              '(:id 1 :task "valid" :status :queued))))
    (is (hngh.plugins.ai-orchestrator::validate-task-record (valid)))
    (dolist (mutator
             (list (lambda (entry) (setf (getf entry :task) 7))
                   (lambda (entry) (setf (getf entry :status) :unknown))
                   (lambda (entry) (setf (getf entry :authority) :unknown))
                   (lambda (entry) (setf (getf entry :attempt) -1))
                   (lambda (entry) (setf (getf entry :max-attempts) 0))
                   (lambda (entry) (setf (getf entry :depends-on) :not-a-list))))
      (let ((entry (valid)))
        (funcall mutator entry)
        (signals error
          (hngh.plugins.ai-orchestrator::validate-task-record entry))))))

(test submit-persists-v2-defaults
  "submit-task persists the control fields required by the v2 queue format."
  (with-aio-light (tmp)
    (hngh.plugins.ai-orchestrator::submit-task "v2 task")
    (let ((entry (first (hngh.plugins.ai-orchestrator::list-tasks))))
      (is (= 2 (getf entry :schema-version)))
      (is (eq :advisory (getf entry :authority)))
      (is (null (getf entry :approval-at)))
      (is (equal '() (getf entry :depends-on)))
      (is (= 0 (getf entry :attempt)))
      (is (= 1 (getf entry :max-attempts)))
      (is (null (getf entry :not-before)))
      (is (null (getf entry :lease-until)))
      (is (null (getf entry :blocked-reason)))
      (is (null (getf entry :started-at))))))

(test submit-persists-task
  "submit-task writes a :queued entry to the state store."
  (with-aio-light (tmp)
    (let ((id (hngh.plugins.ai-orchestrator::submit-task "hello world")))
      (is (integerp id))
      (let ((tasks (hngh.plugins.ai-orchestrator::list-tasks)))
        (is (= 1 (length tasks)))
        (is (eq :queued (getf (first tasks) :status)))
        (is (string= "hello world" (getf (first tasks) :task)))
        (is (equal '(:prefer-tool :local-openai-api) (getf (first tasks) :policy)))))))

(test tick-completes-task
  "task-driver-tick transitions a queued task to :done on successful delegate."
  (with-aio-light (tmp)
    (with-delegate-stub (:completed "stub says ok")
      (hngh.plugins.ai-orchestrator::submit-task "do a thing")
      (let ((done-id (hngh.plugins.ai-orchestrator::task-driver-tick)))
        (is (integerp done-id))
        (let* ((tasks (hngh.plugins.ai-orchestrator::list-tasks))
               (entry (first tasks)))
          (is (eq :done (getf entry :status)))
          (is (string= "stub says ok" (getf entry :result)))
          (is (integerp (getf entry :finished-at)))
          (is (null (hngh.plugins.ai-orchestrator::list-tasks :status :queued))
              "no tasks left queued"))))))

(test tick-marks-failure
  "task-driver-tick marks :failed with an error when delegate fails."
  (with-aio-light (tmp)
    (with-delegate-stub (:failed "boom")
      (hngh.plugins.ai-orchestrator::submit-task "break something")
      (hngh.plugins.ai-orchestrator::task-driver-tick)
      (let ((entry (first (hngh.plugins.ai-orchestrator::list-tasks))))
        (is (eq :failed (getf entry :status)))
        (is (string= "boom" (getf entry :error)))))))

(test tick-empty-queue
  "task-driver-tick on an empty queue returns NIL and does not error."
  (with-aio-light (tmp)
    (is (null (hngh.plugins.ai-orchestrator::task-driver-tick)))))

(test driver-schedule-registration
  "start/stop-task-driver registers then deactivates a scheduler interval."
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.core.state-store:init :hngh-home tmp)
           (hngh.core.scheduler:init)
           (hngh.plugins.ai-orchestrator:init :hngh-home tmp)
          (let ((id (hngh.plugins.ai-orchestrator::start-task-driver)))
            (is (integerp id))
            (is (find id (hngh.core.scheduler:list-schedules)
                      :key #'hngh.core.scheduler::schedule-info-id))
            (hngh.plugins.ai-orchestrator::stop-task-driver)
            (is (null (find id (hngh.core.scheduler:list-schedules)
                            :key #'hngh.core.scheduler::schedule-info-id)))))
      (ignore-errors (hngh.plugins.ai-orchestrator:shutdown))
      (ignore-errors (hngh.core.scheduler:shutdown))
      (ignore-errors (hngh.core.state-store:shutdown))
      (ignore-errors (hngh.core.event-bus:shutdown))
      (cleanup-tmp-home tmp))))
