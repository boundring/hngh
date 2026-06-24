;;;; tests/unit/test-dbus-bridge.lisp — Tests for dbus Bridge (B13)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.dbus-bridge
  :description "Tests for dbus Bridge (B13)"
  :in :hngh)

(in-suite :hngh.dbus-bridge)

(test dbus-bridge-init-shutdown
  (hngh.plugins.dbus-bridge:init :monitor-systemd nil)
  (is (hngh.plugins.dbus-bridge:running-p))
  (hngh.plugins.dbus-bridge:shutdown)
  (is (not (hngh.plugins.dbus-bridge:running-p))))

(test dbus-bridge-status-returns-plist
  (hngh.plugins.dbus-bridge:init :monitor-systemd nil)
  (let ((status (hngh.plugins.dbus-bridge:status)))
    (is (listp status))
    (is (getf status :running)))
  (hngh.plugins.dbus-bridge:shutdown))

(test find-gdbus-returns-bool
  (is (hngh.plugins.dbus-bridge:find-gdbus)))

(test dbus-bridge-handle-signal-emits-system-topic-for-known-interface
  (let ((tmp (make-tmp-home))
        (system-topics '())
        (dbus-topics '()))
    (cleanup-tmp-home tmp)
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.core.event-bus:subscribe
            "system.*"
            (lambda (evt)
              (push (hngh.core.event-bus:event-topic evt) system-topics)))
           (hngh.core.event-bus:subscribe
            "dbus.signal.*"
            (lambda (evt)
              (push (hngh.core.event-bus:event-topic evt) dbus-topics)))

           (hngh.plugins.dbus-bridge::handle-dbus-signal
            "/org/freedesktop/systemd1: org.freedesktop.systemd1.Manager.JobNew((u 42))")

           (is (find "system.systemd.jobnew" system-topics :test #'string=)
               "Known systemd interface should emit normalized system.* event")
           (is (not (null dbus-topics))
               "Raw dbus.signal.* event should remain backward-compatible"))
      (ignore-errors (hngh.core.event-bus:shutdown))
      (cleanup-tmp-home tmp))))

(test dbus-bridge-handle-signal-skips-system-topic-for-unknown-interface
  (let ((tmp (make-tmp-home))
        (system-topics '())
        (dbus-topics '()))
    (cleanup-tmp-home tmp)
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.core.event-bus:subscribe
            "system.*"
            (lambda (evt)
              (push (hngh.core.event-bus:event-topic evt) system-topics)))
           (hngh.core.event-bus:subscribe
            "dbus.signal.*"
            (lambda (evt)
              (push (hngh.core.event-bus:event-topic evt) dbus-topics)))

           (hngh.plugins.dbus-bridge::handle-dbus-signal
            "/org/example/custom: com.example.Custom.InterfaceChanged((\"x\"))")

           (is (null system-topics)
               "Unknown interfaces should not emit normalized system.* events")
           (is (not (null dbus-topics))
               "Unknown interfaces should still emit dbus.signal.* events"))
      (ignore-errors (hngh.core.event-bus:shutdown))
      (cleanup-tmp-home tmp))))
