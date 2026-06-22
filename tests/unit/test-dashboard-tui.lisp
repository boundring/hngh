;;;; tests/unit/test-dashboard-tui.lisp — Tests for Dashboard TUI (B9)
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

(defun make-tmp-home ()
  (merge-pathnames (concatenate 'string "test-tui-"
                                  (format nil "~D" (random 1000000))
                                  "/")
                    (uiop:temporary-directory)))

(defun cleanup-tmp-home (home)
  (when (probe-file home)
    (uiop:delete-directory-tree home :validate #'identity)))

;; --- Lifecycle (headless mode only — no terminal needed for tests) ---

(define-test tui-init-shutdown-headless
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (assert-true (hngh.plugins.dashboard-tui:running-p))
    (hngh.plugins.dashboard-tui:shutdown)
    (assert-true (not (hngh.plugins.dashboard-tui:running-p)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(define-test tui-status-returns-plist
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (assert-true (listp status))
      (assert-true (getf status :running))
      (assert-true (getf status :headless)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

;; --- Event subscription ---

(define-test tui-receives-events
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.core.event-bus:publish "test.tui" "hello")
    ;; Event buffer should have at least 1 event
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (assert-true (> (getf status :events-buffered) 0)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(define-test tui-buffer-capped-at-100
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    ;; Publish 150 events
    (dotimes (i 150)
      (hngh.core.event-bus:publish "test.flood" i))
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (assert-true (<= (getf status :events-buffered) 100)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

;; --- View switching ---

(define-test tui-handle-key-switches-view
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.plugins.dashboard-tui:handle-key #\2)
    (assert-equal :events (getf (hngh.plugins.dashboard-tui:status) :view))
    (hngh.plugins.dashboard-tui:handle-key #\1)
    (assert-equal :overview (getf (hngh.plugins.dashboard-tui:status) :view))
    (hngh.plugins.dashboard-tui:handle-key #\3)
    (assert-equal :plugins (getf (hngh.plugins.dashboard-tui:status) :view))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(define-test tui-handle-key-q-stops
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.plugins.dashboard-tui:handle-key #\q)
    (assert-true (not (hngh.plugins.dashboard-tui:running-p)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))
