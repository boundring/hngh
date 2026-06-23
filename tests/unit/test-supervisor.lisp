;;;; tests/unit/test-supervisor.lisp — Tests for Supervisor (A6)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.supervisor
  :description "Tests for Supervisor (A6)"
  :in :hngh)

(in-suite :hngh.supervisor)

(test supervisor-init-shutdown
  (hngh.core.supervisor:init)
  (is (hngh.core.supervisor:running-p))
  (hngh.core.supervisor:shutdown)
  (is (not (hngh.core.supervisor:running-p))))

(test register-component
  (hngh.core.supervisor:init)
  (let ((info (hngh.core.supervisor:register "test-comp" :type :plugin)))
    (is (not (null info)))
    (is (equal "test-comp" (hngh.core.supervisor:component-info-id info)))
    (is (equal :running (hngh.core.supervisor:component-info-status info))))
  (hngh.core.supervisor:shutdown))

(test register-duplicate-returns-nil
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "dup-comp" :type :plugin)
  (is (null (hngh.core.supervisor:register "dup-comp" :type :plugin)))
  (hngh.core.supervisor:shutdown))

(test unregister-component
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "temp-comp" :type :plugin)
  (is (hngh.core.supervisor:unregister "temp-comp"))
  (is (null (hngh.core.supervisor:get-status "temp-comp")))
  (hngh.core.supervisor:shutdown))

(test health-check-no-fn-returns-true
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "healthy-comp" :type :plugin)
  (is (hngh.core.supervisor:check-health "healthy-comp"))
  (hngh.core.supervisor:shutdown))

(test health-check-with-fn
  (let ((healthy t))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "checked-comp" :type :plugin
        :health-check (lambda () healthy))
    (is (hngh.core.supervisor:check-health "checked-comp"))
    (setf healthy nil)
    (is (not (hngh.core.supervisor:check-health "checked-comp")))
    (hngh.core.supervisor:shutdown)))

(test report-failure-never-policy-no-restart
  (let ((restart-called nil))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "never-comp" :type :plugin
        :restart-policy :never
        :restart-fn (lambda () (setf restart-called t) t))
    (hngh.core.supervisor:report-failure "never-comp" "test failure")
    (is (not restart-called))
    (is (equal :failed (hngh.core.supervisor:get-status "never-comp")))
    (hngh.core.supervisor:shutdown)))

(test report-failure-always-policy-restarts
  (let ((restart-count 0))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "always-comp" :type :plugin
        :restart-policy :always
        :restart-fn (lambda () (incf restart-count) t)
        :max-restarts 10)
    (hngh.core.supervisor:report-failure "always-comp" "crash")
    (is (equal 1 restart-count))
    (is (equal :running (hngh.core.supervisor:get-status "always-comp")))
    (hngh.core.supervisor:shutdown)))

(test escalation-after-max-restarts
  (let ((restart-count 0))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "escalate-comp" :type :plugin
        :restart-policy :always
        :restart-fn (lambda () (incf restart-count) t)
        :max-restarts 2
        :window-duration 300)
    (hngh.core.supervisor:report-failure "escalate-comp" "crash 1")
    (is (equal 1 restart-count))
    (hngh.core.supervisor:report-failure "escalate-comp" "crash 2")
    (is (equal 2 restart-count))
    (hngh.core.supervisor:report-failure "escalate-comp" "crash 3")
    (is (equal 2 restart-count))
    (is (equal :escalated (hngh.core.supervisor:get-status "escalate-comp")))
    (hngh.core.supervisor:shutdown)))

(test list-components-shows-all
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "comp-a" :type :plugin)
  (hngh.core.supervisor:register "comp-b" :type :agent)
  (is (equal 2 (hngh.core.supervisor:component-count)))
  (let ((ids (mapcar #'hngh.core.supervisor:component-info-id
                     (hngh.core.supervisor:list-components))))
    (is (member "comp-a" ids :test #'string=))
    (is (member "comp-b" ids :test #'string=)))
  (hngh.core.supervisor:shutdown))

(test report-success-resets-window
  (let ((restart-count 0))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "success-comp" :type :plugin
        :restart-policy :always
        :restart-fn (lambda () (incf restart-count) t)
        :max-restarts 1)
    (hngh.core.supervisor:report-failure "success-comp" "crash")
    (is (equal 1 restart-count))
    (hngh.core.supervisor:report-success "success-comp")
    (hngh.core.supervisor:report-failure "success-comp" "crash 2")
    (is (equal 2 restart-count))
    (hngh.core.supervisor:shutdown)))
