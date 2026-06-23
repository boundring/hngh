;;;; tests/unit/harness.lisp — Shared test utilities and suite definition
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh
  :description "Hngh test suite")

(defun run-tests ()
  "Run all Hngh tests. Returns T if all passed."
  (run! :hngh))

(defun make-tmp-home ()
  "Create a unique temp directory path for testing. Does not create the directory."
  (merge-pathnames (concatenate 'string "hngh-test-"
                                  (format nil "~D" (random 1000000))
                                  "/")
                    (uiop:temporary-directory)))

(defun cleanup-tmp-home (home)
  "Delete the temp directory if it exists."
  (when (probe-file home)
    (uiop:delete-directory-tree home :validate #'identity)))

(defun fixture-path (relative)
  "Return the path to a test fixture file."
  (merge-pathnames relative
                    (merge-pathnames "tests/fixtures/"
                                      (asdf:system-source-directory :hngh))))
