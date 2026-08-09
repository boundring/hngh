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

(test tui-headless-render-to-string
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless nil)
    (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
      (is (search "Hngh v" output))
      (is (search "Overview" output)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-reads-live-watch-state
  (let ((tmp (make-pathname :name "watch-state" :type "txt"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "2026-08-09T18:00:00 cibo status=checked idle_s=4~%")
             (format stream "2026-08-09T18:00:10 cibo status=idle-nudge action=nudge idle_s=16~%")
             (format stream "2026-08-09T18:00:10 seu status=composer-active action=hold~%"))
           (let ((states (hngh.plugins.dashboard-tui:read-watch-state tmp)))
             (is (equal "idle-nudge"
                        (getf (cdr (assoc "cibo" states :test #'string=)) :status)))
             (is (equal "nudge"
                        (getf (cdr (assoc "cibo" states :test #'string=)) :action)))
             (is (= 16
                    (getf (cdr (assoc "cibo" states :test #'string=)) :idle-s)))
             (is (equal "composer-active"
                        (getf (cdr (assoc "seu" states :test #'string=)) :status)))))
      (when (probe-file tmp)
        (delete-file tmp)))))

(test tui-renders-live-watch-state
  (let ((tmp (make-pathname :name "watch-state-render" :type "txt"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "2026-08-09T18:30:00 cibo status=idle-nudge action=nudge idle_s=18~%"))
           (hngh.core.event-bus:init :hngh-home (make-tmp-home))
           (hngh.plugins.dashboard-tui:init :headless t)
           (hngh.plugins.dashboard-tui:handle-key #\4)
           (let ((hngh.plugins.dashboard-tui::*watch-state-path* tmp))
             (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
               (is (search "Live Watch" output))
               (is (search "cibo" output))
               (is (search "idle-nudge" output))))
           (hngh.plugins.dashboard-tui:shutdown)
           (hngh.core.event-bus:shutdown))
      (when (probe-file tmp)
        (delete-file tmp)))))

(test tui-handle-key-q-stops
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.plugins.dashboard-tui:handle-key #\q)
    (is (not (hngh.plugins.dashboard-tui:running-p)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))
