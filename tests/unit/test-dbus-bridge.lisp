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
