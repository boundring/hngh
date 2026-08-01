;;;; tests/unit/test-emacs-daemon.lisp — Tests for the Emacs Daemon plugin (M6.3)
;;;;
;;;; Unit tests are headless-safe (daemon may or may not exist). The live
;;;; lifecycle test is guarded: it starts/stops a daemon ONLY when emacs is
;;;; present AND no daemon is already running. A pre-existing daemon is never
;;;; stopped by this suite — only status/health shape is asserted then.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.emacs-daemon
  :description "Tests for the Emacs Daemon plugin (M6.3)"
  :in :hngh)

(in-suite :hngh.emacs-daemon)

;;; --- Helpers ---------------------------------------------------------------

(defun emacs-test-available-p ()
  "T when an emacs binary is found on PATH."
  (handler-case
      (let ((proc (sb-ext:run-program "emacs" '("--version")
                                      :search t :wait t
                                      :output nil :error nil)))
        (zerop (sb-ext:process-exit-code proc)))
    (error () nil)))

;;; --- Unit tests ------------------------------------------------------------

(test daemon-alive-p-returns-boolean
  "daemon-alive-p returns a boolean without error, daemon or not."
  (is (member (hngh.plugins.emacs-daemon:daemon-alive-p) '(t nil))))

(test status-plist-shape
  "status returns a plist with :running :daemon-alive :pid keys."
  (let ((status (hngh.plugins.emacs-daemon:status)))
    (is (member (getf status :running) '(t nil)))
    (is (member (getf status :daemon-alive) '(t nil)))
    (is (or (null (getf status :pid)) (integerp (getf status :pid))))))

(test health-plist-shape
  "health returns a plist with :alive :pid keys; pid is an integer or NIL."
  (let ((h (hngh.plugins.emacs-daemon:health)))
    (is (member (getf h :alive) '(t nil)))
    (is (or (null (getf h :pid)) (integerp (getf h :pid))))))

;;; --- Live lifecycle (guarded) ----------------------------------------------

(test emacs-daemon-live-lifecycle
  "When emacs exists and no daemon runs: start, assert alive + integer pid,
stop, assert not alive. When a daemon already runs, assert health shape only
and NEVER stop it."
  (if (not (emacs-test-available-p))
      (skip "emacs binary not available")
      (if (hngh.plugins.emacs-daemon:daemon-alive-p)
          (progn
            (format t "~&[emacs-daemon-test] pre-existing daemon detected; health-only, never stopping.~%")
            (let ((h (hngh.plugins.emacs-daemon:health)))
              (is (getf h :alive))
              (is (integerp (getf h :pid)))
              (is (= (getf h :pid)
                     (getf (hngh.plugins.emacs-daemon:status) :pid)))))
          (unwind-protect
               (progn
                 (is (hngh.plugins.emacs-daemon:start-daemon))
                 (is (hngh.plugins.emacs-daemon:daemon-alive-p))
                 (is (integerp (getf (hngh.plugins.emacs-daemon:health) :pid)))
                 (is (hngh.plugins.emacs-daemon:stop-daemon))
                 (is (not (hngh.plugins.emacs-daemon:daemon-alive-p))))
            (when (hngh.plugins.emacs-daemon:daemon-alive-p)
              (hngh.plugins.emacs-daemon:stop-daemon))))))
