;;;; tests/unit/test-dbus-bridge.lisp — Tests for dbus Bridge (B13)
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

;; --- Lifecycle ---

(define-test dbus-bridge-init-shutdown
  (hngh.plugins.dbus-bridge:init :monitor-systemd nil)
  (assert-true (hngh.plugins.dbus-bridge:running-p))
  (hngh.plugins.dbus-bridge:shutdown)
  (assert-true (not (hngh.plugins.dbus-bridge:running-p))))

(define-test dbus-bridge-status-returns-plist
  (hngh.plugins.dbus-bridge:init :monitor-systemd nil)
  (let ((status (hngh.plugins.dbus-bridge:status)))
    (assert-true (listp status))
    (assert-true (getf status :running)))
  (hngh.plugins.dbus-bridge:shutdown))

;; --- gdbus detection ---

(define-test find-gdbus-returns-bool
  ;; gdbus should be available on CachyOS/Arch
  (assert-true (hngh.plugins.dbus-bridge:find-gdbus)))
