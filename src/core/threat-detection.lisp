;;;; core/threat-detection.lisp — Hngh Procedural Threat Detection (A7)
;;;
;;; L1: Static analysis of plugin manifests and code before loading.
;;; L3: Runtime observation of plugin behavior (file access, network, subprocess).
;;;
;;; This is a stub — full implementation is M1.1.
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.threat-detection)

(defun analyze-manifest (manifest)
  "Analyze a plugin manifest for threat indicators (L1 static).
Returns a plist: (:threat-level :safe|:suspicious|:dangerous :findings (list...)).
Full implementation in M1.1."
  (declare (ignore manifest))
  (list :threat-level :safe :findings nil))

(defun analyze-code (path)
  "Analyze plugin source code for threat indicators (L1 static).
Returns a plist: (:threat-level :safe|:suspicious|:dangerous :findings (list...)).
Full implementation in M1.1."
  (declare (ignore path))
  (list :threat-level :safe :findings nil))

(defun observe-behavior (plugin-name event)
  "Process a runtime observation event for a plugin (L3 runtime).
Called by the event bus when plugins exhibit observable behavior.
Full implementation in M1.1."
  (declare (ignore plugin-name event))
  nil)
