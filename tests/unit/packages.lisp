;;;; tests/unit/packages.lisp — Test package definitions
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(defpackage :hngh.tests
  (:documentation "Hngh test suite.")
  (:use :cl :hngh))

(defpackage :hngh.tests.harness
  (:documentation "Test harness — run all tests.")
  (:use :cl)
  (:export #:run-all-tests
           #:run-test
           #:define-test
           #:assert-equal
           #:assert-true
           #:assert-condition))
