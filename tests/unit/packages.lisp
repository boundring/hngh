;;;; tests/unit/packages.lisp — Test package definitions
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(defpackage :hngh.tests
  (:documentation "Hngh test suite using FiveAM.")
  (:use :cl :fiveam :hngh :hngh.core :hngh.core.wire-protocol :hngh.core.daemon)
  (:export #:run-tests
           #:make-tmp-home
           #:cleanup-tmp-home
           #:fixture-path))
