;;;; tests/unit/test-scheduler.lisp — Tests for Scheduler (A5)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.scheduler
  :description "Tests for Scheduler (A5)"
  :in :hngh)

(in-suite :hngh.scheduler)

(test scheduler-init-shutdown
  (hngh.core.scheduler:init)
  (is (hngh.core.scheduler:running-p))
  (hngh.core.scheduler:shutdown)
  (is (not (hngh.core.scheduler:running-p))))

(test schedule-delayed-fires
  (let ((fired nil)
        (tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.scheduler:init)
    (hngh.core.scheduler:schedule "test-delayed"
        '(:delayed 2)
        (list :function (lambda () (setf fired t))))
    (sleep 4)
    (is-true fired)
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test schedule-interval-fires-multiple
  (let ((fire-count 0)
        (tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.scheduler:init)
    (hngh.core.scheduler:schedule "test-interval"
        '(:interval 1)
        (list :function (lambda () (incf fire-count))))
    (sleep 3.5)
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (is (>= fire-count 2))
    (cleanup-tmp-home tmp)))

(test cancel-schedule
  (let ((fired nil)
        (tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.scheduler:init)
    (let ((id (hngh.core.scheduler:schedule "test-cancel"
                '(:delayed 3)
                (list :function (lambda () (setf fired t))))))
      (is (hngh.core.scheduler:cancel id))
      (sleep 4)
      (is (not fired)))
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test schedule-event-publishes
  (let ((received nil)
        (tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.event-bus:subscribe "test.scheduled"
        (lambda (evt)
          (push (hngh.core.event-bus:event-payload evt) received)))
    (hngh.core.scheduler:init)
    (hngh.core.scheduler:schedule "test-event"
        '(:delayed 2)
        '(:event "test.scheduled" "fired!"))
    (sleep 4)
    (is (not (null received)))
    (is (equal "fired!" (first received)))
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test list-schedules
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.scheduler:init)
    (hngh.core.scheduler:schedule "sched-a" '(:delayed 100) (list :function (lambda ())))
    (hngh.core.scheduler:schedule "sched-b" '(:delayed 100) (list :function (lambda ())))
    (is (equal 2 (length (hngh.core.scheduler:list-schedules))))
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))
