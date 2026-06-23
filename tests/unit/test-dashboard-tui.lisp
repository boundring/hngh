;;;; tests/unit/test-dashboard-tui.lisp — Tests for Dashboard TUI (B9)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.dashboard-tui
  :description "Tests for Dashboard TUI (B9)"
  :in :hngh)

(in-suite :hngh.dashboard-tui)

(test tui-init-shutdown-headless
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (is (hngh.plugins.dashboard-tui:running-p))
    (hngh.plugins.dashboard-tui:shutdown)
    (is (not (hngh.plugins.dashboard-tui:running-p)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-status-returns-plist
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (is (listp status))
      (is (getf status :running))
      (is (getf status :headless)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-receives-events
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.core.event-bus:publish "test.tui" "hello")
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (is (> (getf status :events-buffered) 0)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-buffer-capped-at-100
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (dotimes (i 150)
      (hngh.core.event-bus:publish "test.flood" i))
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (is (<= (getf status :events-buffered) 100)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-handle-key-switches-view
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.plugins.dashboard-tui:handle-key #\2)
    (is (equal :events (getf (hngh.plugins.dashboard-tui:status) :view)))
    (hngh.plugins.dashboard-tui:handle-key #\1)
    (is (equal :overview (getf (hngh.plugins.dashboard-tui:status) :view)))
    (hngh.plugins.dashboard-tui:handle-key #\3)
    (is (equal :plugins (getf (hngh.plugins.dashboard-tui:status) :view)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-handle-key-q-stops
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.plugins.dashboard-tui:handle-key #\q)
    (is (not (hngh.plugins.dashboard-tui:running-p)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))
