;;;; tests/unit/test-scheduler.lisp — Tests for Scheduler (A5)
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

(defun make-tmp-home ()
  (merge-pathnames (concatenate 'string "test-sched-"
                                  (format nil "~D" (random 1000000))
                                  "/")
                    (uiop:temporary-directory)))

(defun cleanup-tmp-home (home)
  (when (probe-file home)
    (uiop:delete-directory-tree home :validate #'identity)))

;; --- Lifecycle ---

(define-test scheduler-init-shutdown
  (hngh.core.scheduler:init)
  (assert-true (hngh.core.scheduler:running-p))
  (hngh.core.scheduler:shutdown)
  (assert-true (not (hngh.core.scheduler:running-p))))

;; --- Scheduling ---

(define-test schedule-delayed-fires
  (let ((fired nil)
        (tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.scheduler:init)
    (hngh.core.scheduler:schedule "test-delayed"
                                    '(:delayed 2)
                                    (list :function (lambda () (setf fired t))))
    ;; Wait for it to fire
    (sleep 4)
    (assert-true fired)
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(define-test schedule-interval-fires-multiple
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
    ;; Should have fired at least 2 times (at t=1 and t=2, maybe t=3)
    (assert-true (>= fire-count 2))
    (cleanup-tmp-home tmp)))

(define-test cancel-schedule
  (let ((fired nil)
        (tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.scheduler:init)
    (let ((id (hngh.core.scheduler:schedule "test-cancel"
                                              '(:delayed 3)
                                              (list :function (lambda () (setf fired t))))))
      (assert-true (hngh.core.scheduler:cancel id))
      (sleep 4)
      (assert-true (not fired)))
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(define-test schedule-event-publishes
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
    (assert-true (not (null received)))
    (assert-equal "fired!" (first received))
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(define-test list-schedules
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.scheduler:init)
    (hngh.core.scheduler:schedule "sched-a" '(:delayed 100) (list :function (lambda ())))
    (hngh.core.scheduler:schedule "sched-b" '(:delayed 100) (list :function (lambda ())))
    (assert-equal 2 (length (hngh.core.scheduler:list-schedules)))
    (hngh.core.scheduler:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))
