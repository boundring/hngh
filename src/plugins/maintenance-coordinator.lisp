;;;; plugins/maintenance-coordinator.lisp — Hngh Maintenance Coordinator (H-B1)
;;;;
;;;; Read-only maintenance state coordinator. Exposes a pure function that reads
;;;; maintenance state from the state store and the pacman lock file.
;;;;
;;;; State priority: explicit active flag > pacman lock > store-ready default > unknown.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.maintenance-coordinator)

;;; --- State store path constants ----------------------------------------------

(defparameter +maintenance-active-path+ "state/maintenance/active.lisp"
  "Relative path within the Hngh state tree for the explicit maintenance-active flag.")

(defparameter *pacman-lock-path* "/var/lib/pacman/db.lck"
  "System pacman lock file. Existence indicates a pending package transaction.
Can be overridden for testing via LET-binding.")

;;; --- Lifecycle ---------------------------------------------------------------

(defun init ()
  "Initialize the maintenance coordinator plugin.
No state initialization needed — this is a read-only coordinator."
  (hngh.core:log-info "Maintenance coordinator initialized")
  t)

(defun shutdown ()
  "Shut down the maintenance coordinator plugin.
No cleanup needed — no owned state, no locks, no subscriptions."
  (hngh.core:log-info "Maintenance coordinator shut down")
  t)

(defun running-p ()
  "Return T if the maintenance coordinator is initialized.
Always returns T after init since this plugin holds no runtime state."
  t)

(defun status ()
  "Return a plist describing the plugin status."
  (list :plugin "maintenance-coordinator"
        :running-p (running-p)
        :read-only t))

;;; --- Pure maintenance state reader -------------------------------------------

(defun read-maintenance-state ()
  "Read the current maintenance state from state store and pacman lock.
Returns one of :clear, :maintenance-pending, :maintenance-active, :unknown.
PURE: does not write to the state store. Only reads state-store paths and
the pacman lock file.

Priority order:
  1. Explicit active flag (state/maintenance/active.lisp) -> :maintenance-active
  2. Pacman lock file (/var/lib/pacman/db.lck) exists -> :maintenance-pending
  3. State store initialized -> :clear
  4. Otherwise -> :unknown"
  ;; 1. Check explicit maintenance-active flag in state store
  (when (hngh.core.state-store:running-p)
    (let ((active-flag (hngh.core.state-store:read-state +maintenance-active-path+)))
      (when active-flag
        (return-from read-maintenance-state :maintenance-active))))
  ;; 2. Check pacman lock file
  (when (probe-file *pacman-lock-path*)
    (return-from read-maintenance-state :maintenance-pending))
  ;; 3. State store initialized but no lock/flag
  (if (hngh.core.state-store:running-p)
      :clear
      :unknown))