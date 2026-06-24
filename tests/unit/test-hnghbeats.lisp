;;;; tests/unit/test-hnghbeats.lisp — Tests for Hnghbeats (B6)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.hnghbeats
  :description "Tests for Hnghbeats (B6)"
  :in :hngh)

(in-suite :hngh.hnghbeats)

;;; --- Helpers ---------------------------------------------------------------

(defun hnghbeats-date-string ()
  "Return today's date string as YYYY-MM-DD."
  (multiple-value-bind (sec min hr day mon yr)
      (decode-universal-time (get-universal-time))
    (declare (ignore sec min hr))
    (format nil "~4,'0D-~2,'0D-~2,'0D" yr mon day)))

(defun hnghbeats-yesterday-date-string ()
  "Return yesterday's date string as YYYY-MM-DD."
  (multiple-value-bind (sec min hr day mon yr)
      (decode-universal-time (- (get-universal-time) 86400))
    (declare (ignore sec min hr))
    (format nil "~4,'0D-~2,'0D-~2,'0D" yr mon day)))

(defun hnghbeats-setup (tmp)
  "Initialize dependencies and Hnghbeats plugin on TMP."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.core.scheduler:init)
  (hngh.plugins.hnghbeats:init :hngh-home tmp))

(defun hnghbeats-teardown (tmp)
  "Shutdown Hnghbeats and dependencies, then clean TMP."
  (ignore-errors (hngh.plugins.hnghbeats:shutdown))
  (ignore-errors (hngh.core.scheduler:shutdown))
  (ignore-errors (hngh.core.event-bus:shutdown))
  (ignore-errors (hngh.core.state-store:shutdown))
  (cleanup-tmp-home tmp))

(defmacro with-hnghbeats ((tmp-var) &body body)
  "Run BODY with temporary home and Hnghbeats initialized."
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn
            (hnghbeats-setup ,tmp-var)
            ,@body)
       (hnghbeats-teardown ,tmp-var))))

;;; --- Tests -----------------------------------------------------------------

(test hnghbeats-lifecycle-registers-and-cancels-schedule
  (with-hnghbeats (tmp)
    (is (hngh.plugins.hnghbeats:running-p)
        "Plugin should report running after init")
    (let* ((status (hngh.plugins.hnghbeats:status))
           (schedule-id (getf status :schedule-id))
           (schedules (hngh.core.scheduler:list-schedules))
           (has-job (find "hnghbeats.daily-condensation"
                          schedules
                          :test #'string=
                          :key #'hngh.core.scheduler:schedule-info-name)))
      (declare (ignore tmp))
      (is (integerp schedule-id) "Init should register daily scheduler job")
      (is (not (null has-job))
          "Scheduler should contain hnghbeats daily condensation job")
      (is (= 1 (getf status :subscriptions))
          "Plugin should subscribe to the *.* event stream"))
    (hngh.plugins.hnghbeats:shutdown)
    (is (not (hngh.plugins.hnghbeats:running-p))
        "Plugin should report not running after shutdown")
    (is (null (find "hnghbeats.daily-condensation"
                    (hngh.core.scheduler:list-schedules)
                    :test #'string=
                    :key #'hngh.core.scheduler:schedule-info-name))
        "Shutdown should cancel the scheduler job")
    (is (zerop (length (hngh.core.event-bus:list-subscriptions)))
        "Shutdown should unsubscribe cleanly")))

(test hnghbeats-condensation-persists-and-emits-beat
  (with-hnghbeats (tmp)
    (let ((received '()))
      (hngh.core.event-bus:subscribe
       "hnghbeats.beat"
       (lambda (evt)
         (push (hngh.core.event-bus:event-payload evt) received)))

      ;; System changes
      (hngh.core.event-bus:publish "resource.pressure" '(:level :high) :source 'test)
      (hngh.core.event-bus:publish "runtime.started" '(:id 1 :model "test") :source 'test)

      ;; Package operations
      (hngh.core.event-bus:publish "package.op-completed" '(:op :install :package "foo") :source 'test)

      ;; Agent activity (ai-tool-hub shape)
      (hngh.core.event-bus:publish "agent.completed"
                                   '(:invocation-id 11 :tool :claude :cost 1.25 :result "ok")
                                   :source 'ai-tool-hub)

      ;; Agent activity (ai-orchestrator shape)
      (hngh.core.event-bus:publish "agent.spawned"
                                   '(:id 12 :tool :openai :cost-estimate 0.75)
                                   :source 'ai-orchestrator)

      ;; Threat
      (hngh.core.event-bus:publish "threat.flag" '(:rule :suspicious-io) :source 'test)

      ;; User activity + errors
      (hngh.core.event-bus:publish "secret.denied"
                                   '(:name "api-key" :reason :not-authorized :error "denied")
                                   :source 'test)

      (let* ((date (hnghbeats-date-string))
             (beat (hngh.plugins.hnghbeats:perform-condensation :date date))
             (rel-path (format nil "journal/hnghbeats/~A.lisp" date))
             (persisted (hngh.core.state-store:read-state rel-path)))
        (is (listp beat) "perform-condensation should return a plist")
        (is (equal date (getf beat :date)) "Beat should include current date")
        (is (hngh.core.state-store:state-exists-p rel-path)
            "Condensation should persist under journal/hnghbeats/YYYY-MM-DD.lisp")
        (is (equal beat persisted)
            "Persisted beat payload should match returned payload")

        (is (>= (getf (getf beat :system-changes) :count) 2)
            "system-changes should include runtime/resource events")
        (is (>= (getf (getf beat :package-ops) :count) 1)
            "package-ops should include package events")
        (is (>= (getf (getf beat :agent-activity) :count) 2)
            "agent-activity should include normalized ai-tool-hub and ai-orchestrator events")
        (is (>= (getf (getf beat :costs) :count) 2)
            "costs should include :cost and :cost-estimate payload variants")
        (is (>= (getf (getf beat :threat-events) :count) 1)
            "threat-events should include threat.flag")
        (is (>= (getf (getf beat :user-activity) :count) 1)
            "user-activity should include secret.* events")
        (is (>= (getf (getf beat :errors) :count) 1)
            "errors should include denied/errored events")

        (is (= 1 (length received))
            "perform-condensation should emit a single hnghbeats.beat event")
        (let ((emitted (first received)))
          (is (listp emitted) "Emitted beat payload should be a plist")
          (is (equal date (getf emitted :date))
              "Emitted beat should include date")
          (is (member :system-changes emitted)
              "Emitted beat should include system-changes category")
          (is (member :package-ops emitted)
              "Emitted beat should include package-ops category")
          (is (member :agent-activity emitted)
              "Emitted beat should include agent-activity category")
          (is (member :costs emitted)
              "Emitted beat should include costs category")
          (is (member :threat-events emitted)
              "Emitted beat should include threat-events category")
          (is (member :user-activity emitted)
              "Emitted beat should include user-activity category")
          (is (member :errors emitted)
              "Emitted beat should include errors category"))))))

(test hnghbeats-condensation-with-no-events-is-deterministic
  (with-hnghbeats (tmp)
    (let* ((date (hnghbeats-yesterday-date-string))
           (rel-path (format nil "journal/hnghbeats/~A.lisp" date))
            (beat (hngh.plugins.hnghbeats:perform-condensation)))
      (declare (ignore tmp))
      (is (hngh.core.state-store:state-exists-p rel-path)
          "Even with no events, condensation should persist a beat file")
      (is (equal 0 (getf beat :event-count))
          "No-event condensation should report zero events")
      (is (equal 0 (getf (getf beat :system-changes) :count)))
      (is (equal 0 (getf (getf beat :package-ops) :count)))
      (is (equal 0 (getf (getf beat :agent-activity) :count)))
      (is (equal 0 (getf (getf beat :costs) :count)))
      (is (equal 0 (getf (getf beat :threat-events) :count)))
      (is (equal 0 (getf (getf beat :user-activity) :count)))
      (is (equal 0 (getf (getf beat :errors) :count))))))
