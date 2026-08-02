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

;;; --- H-A3: Pause/Resume and Stale-Lease Recovery tests ---------------------
;;;
;;; Tests cover:
;;;   - Dispatch pause with optional resume_at timestamp.
;;;   - Dispatch resume clears pause state.
;;;   - task-driver-tick is a no-op while paused (before resume_at).
;;;   - task-driver-tick resumes automatically when resume_at has passed.
;;;   - recover-stale-task-leases transitions :running tasks with expired
;;;     leases to :blocked with a deterministic blocked-reason.
;;;   - recover-stale-task-leases ignores :running tasks with nil lease-until.
;;;   - recover-stale-task-leases ignores non-:running tasks.
;;;   - task-driver-tick calls recover-stale-task-leases before dispatch.

;;; --- Pause / Resume state tests -------------------------------------------

(test pause-dispatch-sets-paused-state
  "pause-dispatch marks the driver as paused with an optional resume_at."
  (with-aio-light (tmp)
    (let ((resume-at (+ (get-universal-time) 300)))
      (is (null (hngh.plugins.ai-orchestrator::dispatch-paused-p))
          "not paused before pause-dispatch")
      (hngh.plugins.ai-orchestrator::pause-dispatch :resume-at resume-at)
      (is (hngh.plugins.ai-orchestrator::dispatch-paused-p)
          "paused after pause-dispatch")
      (is (= resume-at (hngh.plugins.ai-orchestrator::dispatch-resume-at))
          "resume_at is stored"))))

(test pause-dispatch-without-resume-at
  "pause-dispatch without :resume-at pauses indefinitely (resume_at is nil)."
  (with-aio-light (tmp)
    (hngh.plugins.ai-orchestrator::pause-dispatch)
    (is (hngh.plugins.ai-orchestrator::dispatch-paused-p))
    (is (null (hngh.plugins.ai-orchestrator::dispatch-resume-at))))

(test resume-dispatch-clears-paused-state
  "resume-dispatch clears the pause flag and resume_at."
  (with-aio-light (tmp)
    (hngh.plugins.ai-orchestrator::pause-dispatch
      :resume-at (+ (get-universal-time) 300))
    (is (hngh.plugins.ai-orchestrator::dispatch-paused-p))
    (hngh.plugins.ai-orchestrator::resume-dispatch)
    (is (null (hngh.plugins.ai-orchestrator::dispatch-paused-p))
        "no longer paused after resume-dispatch")
    (is (null (hngh.plugins.ai-orchestrator::dispatch-resume-at))
        "resume_at cleared after resume-dispatch")))

;;; --- Tick respects pause state --------------------------------------------

(test tick-no-op-when-paused
  "task-driver-tick is a no-op when paused and resume_at has not passed."
  (with-aio-light (tmp)
    (with-delegate-stub (:completed "stub")
      (hngh.plugins.ai-orchestrator::submit-task "should not run")
      (hngh.plugins.ai-orchestrator::pause-dispatch
        :resume-at (+ (get-universal-time) 3600))
      (is (null (hngh.plugins.ai-orchestrator::task-driver-tick)))
      (let ((tasks (hngh.plugins.ai-orchestrator::list-tasks)))
        (is (= 1 (length tasks)))
        (is (eq :queued (getf (first tasks) :status))
            "task remains queued when paused")))))

(test tick-resumes-after-resume-at-passed
  "task-driver-tick auto-resumes when resume_at is in the past."
  (with-aio-light (tmp)
    (with-delegate-stub (:completed "stub says ok")
      (hngh.plugins.ai-orchestrator::submit-task "should run after resume")
      (hngh.plugins.ai-orchestrator::pause-dispatch
        :resume-at (- (get-universal-time) 1))
      ;; First tick auto-resumes, but we also need it to dispatch.
      (hngh.plugins.ai-orchestrator::task-driver-tick)
      (let ((tasks (hngh.plugins.ai-orchestrator::list-tasks)))
        (is (eq :done (getf (first tasks) :status))
            "task dispatched after auto-resume")
        (is (null (hngh.plugins.ai-orchestrator::dispatch-paused-p))
            "pause cleared after auto-resume")))))

;;; --- recover-stale-task-leases tests --------------------------------------

(test recover-stale-transitions-expired-running-to-blocked
  "A :running task with an expired lease-until is transitioned to :blocked."
  (with-aio-light (tmp)
    (let ((past (- (get-universal-time) 120)))
      (hngh.plugins.ai-orchestrator::submit-task "will go stale")
      ;; Manually mark it :running with an expired lease.
      (bt:with-lock-held (hngh.plugins.ai-orchestrator::*task-queue-lock*)
        (let* ((queue (or (hngh.plugins.ai-orchestrator::read-task-queue) '()))
               (id (getf (first queue) :id)))
          (hngh.plugins.ai-orchestrator::write-task-queue
            (list (append (first queue)
                         (list :status :running :lease-until past
                               :started-at (- (get-universal-time) 180))))))
        ;; recover
        (let ((count (hngh.plugins.ai-orchestrator::recover-stale-task-leases)))
          (is (= 1 count) "one stale task recovered"))
        (let* ((queue (hngh.plugins.ai-orchestrator::read-task-queue))
               (entry (first queue)))
          (is (eq :blocked (getf entry :status)))
          (is (stringp (getf entry :blocked-reason))
              "blocked-reason is a string"))))))

(test recover-stale-ignores-nil-lease-until
  "A :running task with nil lease-until is NOT stale (holds slot indefinitely)."
  (with-aio-light (tmp)
    (hngh.plugins.ai-orchestrator::submit-task "running forever")
    (bt:with-lock-held (hngh.plugins.ai-orchestrator::*task-queue-lock*)
      (let* ((queue (hngh.plugins.ai-orchestrator::read-task-queue))
             (entry (first queue)))
        (setf (getf entry :status) :running
              (getf entry :lease-until) nil
              (getf entry :started-at) (- (get-universal-time) 999))
        (hngh.plugins.ai-orchestrator::write-task-queue queue)))
    (is (null (hngh.plugins.ai-orchestrator::recover-stale-task-leases))
        "no tasks recovered when lease-until is nil")
    (let ((entry (first (hngh.plugins.ai-orchestrator::list-tasks))))
      (is (eq :running (getf entry :status))
          "still running — nil lease means indefinite")))))

(test recover-stale-ignores-non-running
  "Non-:running tasks are never touched by recover-stale-task-leases."
  (with-aio-light (tmp)
    (hngh.plugins.ai-orchestrator::submit-task "queued task")
    (is (zerop (hngh.plugins.ai-orchestrator::recover-stale-task-leases)))
    (let ((entry (first (hngh.plugins.ai-orchestrator::list-tasks))))
      (is (eq :queued (getf entry :status)))))

  (with-aio-light (tmp)
    (hngh.plugins.ai-orchestrator::submit-task "done task")
    (bt:with-lock-held (hngh.plugins.ai-orchestrator::*task-queue-lock*)
      (let* ((queue (hngh.plugins.ai-orchestrator::read-task-queue))
             (entry (first queue)))
        (setf (getf entry :status) :done
              (getf entry :finished-at) (get-universal-time))
        (hngh.plugins.ai-orchestrator::write-task-queue queue)))
    (is (zerop (hngh.plugins.ai-orchestrator::recover-stale-task-leases)))
    (let ((entry (first (hngh.plugins.ai-orchestrator::list-tasks))))
      (is (eq :done (getf entry :status))))))

(test recover-stale-ignores-unexpired-lease
  "A :running task whose lease-until is still in the future is NOT stale."
  (with-aio-light (tmp)
    (let ((future (+ (get-universal-time) 300)))
      (hngh.plugins.ai-orchestrator::submit-task "actively running")
      (bt:with-lock-held (hngh.plugins.ai-orchestrator::*task-queue-lock*)
        (let* ((queue (hngh.plugins.ai-orchestrator::read-task-queue))
               (entry (first queue)))
          (setf (getf entry :status) :running
                (getf entry :lease-until) future
                (getf entry :started-at) (- (get-universal-time) 10))
          (hngh.plugins.ai-orchestrator::write-task-queue queue)))
      (is (zerop (hngh.plugins.ai-orchestrator::recover-stale-task-leases)))
      (let ((entry (first (hngh.plugins.ai-orchestrator::list-tasks))))
        (is (eq :running (getf entry :status)))))))

(test recover-stale-multiple-stale-tasks
  "Multiple stale tasks are all recovered in one pass."
  (with-aio-light (tmp)
    (let ((past (- (get-universal-time) 60)))
      (hngh.plugins.ai-orchestrator::submit-task "stale 1")
      (hngh.plugins.ai-orchestrator::submit-task "stale 2")
      (bt:with-lock-held (hngh.plugins.ai-orchestrator::*task-queue-lock*)
        (let* ((queue (hngh.plugins.ai-orchestrator::read-task-queue))
               (e1 (first queue))
               (e2 (second queue)))
          (setf (getf e1 :status) :running
                (getf e1 :lease-until) past
                (getf e1 :started-at) (- (get-universal-time) 120))
          (setf (getf e2 :status) :running
                (getf e2 :lease-until) past
                (getf e2 :started-at) (- (get-universal-time) 100))
          (hngh.plugins.ai-orchestrator::write-task-queue queue)))
      (is (= 2 (hngh.plugins.ai-orchestrator::recover-stale-task-leases)))
      (let ((blocked (hngh.plugins.ai-orchestrator::list-tasks :status :blocked)))
        (is (= 2 (length blocked)))))))

(test tick-recovers-stale-before-dispatch
  "task-driver-tick recovers stale leases before attempting dispatch."
  (with-aio-light (tmp)
    (let ((past (- (get-universal-time) 120)))
      ;; Queue a stale running task.
      (hngh.plugins.ai-orchestrator::submit-task "stale")
      (bt:with-lock-held (hngh.plugins.ai-orchestrator::*task-queue-lock*)
        (let* ((queue (hngh.plugins.ai-orchestrator::read-task-queue))
               (entry (first queue)))
          (setf (getf entry :status) :running
                (getf entry :lease-until) past
                (getf entry :started-at) (- (get-universal-time) 180))
          (hngh.plugins.ai-orchestrator::write-task-queue queue)))
      ;; Queue a fresh task that should dispatch.
      (with-delegate-stub (:completed "fresh result")
        (hngh.plugins.ai-orchestrator::submit-task "fresh task")
        (hngh.plugins.ai-orchestrator::task-driver-tick)
        (let* ((tasks (hngh.plugins.ai-orchestrator::list-tasks))
               (stale (find-if (lambda (e) (eq :blocked (getf e :status))) tasks))
               (fresh (find-if (lambda (e) (eq :done (getf e :status))) tasks)))
          (is (not (null stale)) "stale task was recovered to :blocked")
          (is (not (null fresh)) "fresh task was dispatched to :done"))))))

;;; --- H-B1: Maintenance Coordinator tests -----------------------------------
;;;
;;; Tests for the read-maintenance-state pure function.

;;; --- Test helpers for maintenance state ---

(defmacro with-pacman-lock ((tmp exists) &body body)
  "Run BODY with *pacman-lock-path* bound to a test lock file in TMP.
If EXISTS is T, create the lock file; if NIL, ensure it doesn't exist."
  `(let ((lock-path (merge-pathnames "test-pacman.lock" ,tmp)))
     (when ,exists (ensure-directories-exist lock-path) (close (open lock-path :direction :output :if-exists :supersede)))
     (let ((hngh.plugins.maintenance-coordinator::*pacman-lock-path* lock-path))
       ,@body)))


;;; --- Test cases ---

(test maintenance-state-clear-when-store-ready-no-lock
  "State store initialized, no active flag, no pacman lock -> :clear."
  (with-aio-light (tmp)
    (is (eq :clear (hngh.plugins.maintenance-coordinator::read-maintenance-state)))))

(test maintenance-state-pending-when-pacman-lock-exists
  "State store initialized, no active flag, pacman lock exists -> :maintenance-pending."
  (with-aio-light (tmp)
    (with-pacman-lock (tmp t)
      (is (eq :maintenance-pending (hngh.plugins.maintenance-coordinator::read-maintenance-state))))))

(test maintenance-state-active-when-flag-set
  "State store has active flag -> :maintenance-active (overrides pacman lock)."
  (with-aio-light (tmp)
    ;; Write active flag to state store
    (hngh.core.state-store:write-state "state/maintenance/active.lisp" t)
    (with-pacman-lock (tmp t)
      (is (eq :maintenance-active (hngh.plugins.maintenance-coordinator::read-maintenance-state))))))

(test maintenance-state-unknown-when-store-not-initialized
  "State store not initialized -> :unknown."
  ;; Call with no state store initialized (fresh image, no init called)
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (is (eq :unknown (hngh.plugins.maintenance-coordinator::read-maintenance-state)))))


(test maintenance-state-pending-overrides-clear
  "Pacman lock exists, store ready, no active flag -> :maintenance-pending (not :clear)."
  (with-aio-light (tmp)
    (with-pacman-lock (tmp t)
      (is (eq :maintenance-pending (hngh.plugins.maintenance-coordinator::read-maintenance-state))))))

(test maintenance-state-active-overrides-pending
  "Both active flag set AND pacman lock exists -> :maintenance-active (priority: active > pending > clear)."
  (with-aio-light (tmp)
    (hngh.core.state-store:write-state "state/maintenance/active.lisp" t)
    (with-pacman-lock (tmp t)
      (is (eq :maintenance-active (hngh.plugins.maintenance-coordinator::read-maintenance-state))))))

(test maintenance-state-read-only-no-writes
  "Verify no state-store write functions are called during read-maintenance-state."
  (with-aio-light (tmp)
    (let ((write-called nil)
          (orig-write (symbol-function 'hngh.core.state-store:write-state)))
      (unwind-protect
           (progn
             (setf (symbol-function 'hngh.core.state-store:write-state)
                   (lambda (&rest args)
                     (declare (ignore args))
                     (setf write-called t)))
             (hngh.plugins.maintenance-coordinator::read-maintenance-state)
             (is (null write-called) "write-state was not called"))
        (setf (symbol-function 'hngh.core.state-store:write-state) orig-write)))))

