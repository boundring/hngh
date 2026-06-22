;;;; tests/unit/harness.lisp — Test harness for Hngh
;;;;
;;; Minimal test framework: define-test, assert-*, run-all-tests.
;;; Not using FiveAM or other external test frameworks yet — keeping
;;; dependencies minimal for the M0 skeleton. We can migrate to FiveAM
;;; later if the custom harness becomes limiting.
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

(defparameter *tests* (make-hash-table :test 'eq)
  "Registry of test functions. Key: test name (symbol), value: function.")

(defparameter *test-results* '()
  "Results of the last test run. List of (name passed-p) plists.")

(defmacro define-test (name &body body)
  "Define a test named NAME. The body is executed when the test runs.
Within the body, use assert-* macros to check conditions."
  (let ((fn-name (intern (concatenate 'string "TEST-" (string name))
                         :hngh.tests.harness)))
    `(progn
       (defun ,fn-name ()
         ,@body)
       (setf (gethash ',name *tests*) #',fn-name)
       ',name)))

(defmacro assert-true (form)
  "Assert that FORM evaluates to non-NIL."
  `(unless ,form
     (error 'assertion-failed
            :form ',form
            :message (format nil "Expected non-NIL, got ~S" ,form))))

(defmacro assert-equal (expected actual)
  "Assert that EXPECTED is equal to ACTUAL (using EQUAL)."
  `(unless (equal ,expected ,actual)
     (error 'assertion-failed
            :form '(equal ,expected ,actual)
            :message (format nil "Expected ~S, got ~S" ,expected ,actual))))

(defmacro assert-condition (condition-type form)
  "Assert that evaluating FORM signals a condition of type CONDITION-TYPE."
  `(handler-case
       ,form
     (,condition-type () t)
     (:no-error (&rest args)
       (declare (ignore args))
       (error 'assertion-failed
              :form ',form
              :message (format nil "Expected condition ~S, but none was signaled"
                               ',condition-type)))
     (condition (c)
       (error 'assertion-failed
              :form ',form
              :message (format nil "Expected condition ~S, got ~S: ~A"
                               ',condition-type (type-of c) c)))))

(define-condition assertion-failed (error)
  ((form :reader assertion-form :initarg :form)
   (message :reader assertion-message :initarg :message))
  (:report (lambda (c stream)
             (format stream "Assertion failed: ~A~%  Form: ~S"
                     (assertion-message c) (assertion-form c)))))

(defun run-test (name)
  "Run a single test by NAME. Returns T if passed, NIL if failed."
  (let ((fn (gethash name *tests*)))
    (unless fn
      (format t "  [SKIP] ~A (not found)~%" name)
      (return-from run-test nil))
    (handler-case
        (progn
          (funcall fn)
          (format t "  [PASS] ~A~%" name)
          (push (list :name name :passed t) *test-results*)
          t)
      (assertion-failed (c)
        (format t "  [FAIL] ~A: ~A~%" name (assertion-message c))
        (push (list :name name :passed nil) *test-results*)
        nil)
      (error (c)
        (format t "  [ERROR] ~A: ~A~%" name c)
        (push (list :name name :passed nil) *test-results*)
        nil))))

(defun run-all-tests ()
  "Run all registered tests. Returns T if all passed, NIL if any failed."
  (format t "Running Hngh test suite...~%")
  (setf *test-results* '())
  (let ((passed 0)
        (failed 0)
        (total 0))
    (loop for name being the hash-keys of *tests* do
          (incf total)
          (if (run-test name)
              (incf passed)
              (incf failed)))
    (format t "~%Results: ~D/~D passed, ~D failed~%" passed total failed)
    (zerop failed)))
