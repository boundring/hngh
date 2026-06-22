;;;; tests/unit/test-supervisor.lisp — Tests for Supervisor (A6)
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

;; --- Lifecycle ---

(define-test supervisor-init-shutdown
  (hngh.core.supervisor:init)
  (assert-true (hngh.core.supervisor:running-p))
  (hngh.core.supervisor:shutdown)
  (assert-true (not (hngh.core.supervisor:running-p))))

;; --- Registration ---

(define-test register-component
  (hngh.core.supervisor:init)
  (let ((info (hngh.core.supervisor:register "test-comp" :type :plugin)))
    (assert-true (not (null info)))
    (assert-equal "test-comp" (hngh.core.supervisor:component-info-id info))
    (assert-equal :running (hngh.core.supervisor:component-info-status info)))
  (hngh.core.supervisor:shutdown))

(define-test register-duplicate-returns-nil
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "dup-comp" :type :plugin)
  (assert-true (null (hngh.core.supervisor:register "dup-comp" :type :plugin)))
  (hngh.core.supervisor:shutdown))

(define-test unregister-component
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "temp-comp" :type :plugin)
  (assert-true (hngh.core.supervisor:unregister "temp-comp"))
  (assert-true (null (hngh.core.supervisor:get-status "temp-comp")))
  (hngh.core.supervisor:shutdown))

;; --- Health checking ---

(define-test health-check-no-fn-returns-true
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "healthy-comp" :type :plugin)
  (assert-true (hngh.core.supervisor:check-health "healthy-comp"))
  (hngh.core.supervisor:shutdown))

(define-test health-check-with-fn
  (let ((healthy t))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "checked-comp" :type :plugin
                                    :health-check (lambda () healthy))
    (assert-true (hngh.core.supervisor:check-health "checked-comp"))
    (setf healthy nil)
    (assert-true (not (hngh.core.supervisor:check-health "checked-comp")))
    (hngh.core.supervisor:shutdown)))

;; --- Restart logic ---

(define-test report-failure-never-policy-no-restart
  (let ((restart-called nil))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "never-comp" :type :plugin
                                    :restart-policy :never
                                    :restart-fn (lambda () (setf restart-called t) t))
    (hngh.core.supervisor:report-failure "never-comp" "test failure")
    (assert-true (not restart-called))
    (assert-equal :failed (hngh.core.supervisor:get-status "never-comp"))
    (hngh.core.supervisor:shutdown)))

(define-test report-failure-always-policy-restarts
  (let ((restart-count 0))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "always-comp" :type :plugin
                                    :restart-policy :always
                                    :restart-fn (lambda () (incf restart-count) t)
                                    :max-restarts 10)
    (hngh.core.supervisor:report-failure "always-comp" "crash")
    (assert-equal 1 restart-count)
    (assert-equal :running (hngh.core.supervisor:get-status "always-comp"))
    (hngh.core.supervisor:shutdown)))

(define-test escalation-after-max-restarts
  (let ((restart-count 0))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "escalate-comp" :type :plugin
                                    :restart-policy :always
                                    :restart-fn (lambda () (incf restart-count) t)
                                    :max-restarts 2
                                    :window-duration 300)
    ;; First failure — restart (count 1)
    (hngh.core.supervisor:report-failure "escalate-comp" "crash 1")
    (assert-equal 1 restart-count)
    ;; Second failure — restart (count 2)
    (hngh.core.supervisor:report-failure "escalate-comp" "crash 2")
    (assert-equal 2 restart-count)
    ;; Third failure — should escalate, not restart
    (hngh.core.supervisor:report-failure "escalate-comp" "crash 3")
    (assert-equal 2 restart-count) ; no new restart
    (assert-equal :escalated (hngh.core.supervisor:get-status "escalate-comp"))
    (hngh.core.supervisor:shutdown)))

;; --- Query ---

(define-test list-components-shows-all
  (hngh.core.supervisor:init)
  (hngh.core.supervisor:register "comp-a" :type :plugin)
  (hngh.core.supervisor:register "comp-b" :type :agent)
  (assert-equal 2 (hngh.core.supervisor:component-count))
  (let ((ids (mapcar #'hngh.core.supervisor:component-info-id
                      (hngh.core.supervisor:list-components))))
    (assert-true (member "comp-a" ids :test #'string=))
    (assert-true (member "comp-b" ids :test #'string=)))
  (hngh.core.supervisor:shutdown))

(define-test report-success-resets-window
  (let ((restart-count 0))
    (hngh.core.supervisor:init)
    (hngh.core.supervisor:register "success-comp" :type :plugin
                                    :restart-policy :always
                                    :restart-fn (lambda () (incf restart-count) t)
                                    :max-restarts 1)
    ;; Failure + restart
    (hngh.core.supervisor:report-failure "success-comp" "crash")
    (assert-equal 1 restart-count)
    ;; Report success — resets window
    (hngh.core.supervisor:report-success "success-comp")
    ;; Another failure should restart again (window was reset)
    (hngh.core.supervisor:report-failure "success-comp" "crash 2")
    (assert-equal 2 restart-count)
    (hngh.core.supervisor:shutdown)))
