;;;; tests/fixtures/test-plugin/test-plugin.lisp
;;;; A minimal first-party CL plugin for testing the Plugin Host.
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(defpackage :hngh.plugins.test-plugin
  (:documentation "Test plugin for Plugin Host validation.")
  (:use :cl)
  (:export #:init
           #:cleanup
           #:reload
           #:get-state
           #:set-state))

(in-package :hngh.plugins.test-plugin)

(defvar *state* nil
  "Plugin state — set by init, cleared by cleanup.")

(defun init ()
  "Initialize the test plugin."
  (setf *state* :initialized)
  t)

(defun cleanup ()
  "Clean up the test plugin."
  (setf *state* nil)
  t)

(defun reload ()
  "Hot-reload the test plugin."
  (setf *state* :reloaded)
  t)

(defun get-state ()
  "Return the current plugin state."
  *state*)

(defun set-state (new-state)
  "Set the plugin state."
  (setf *state* new-state))
