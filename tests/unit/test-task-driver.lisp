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
