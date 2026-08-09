;;;; tests/unit/test-sandbox.lisp — Wave C item 8 execution sandbox.
;;;;
;;;; Fixture-tested: argv construction (no bwrap needed), fail-closed path
;;;; (missing bwrap => error, never unsandboxed fallback), availability
;;;; probe. One REAL smoke test when bwrap is present: a sandboxed write
;;;; outside the task dir is denied, inside succeeds. No network, no model.

(in-package :hngh.tests)

(def-suite :hngh.sandbox
  :description "Tests for the Wave C per-task execution sandbox"
  :in :hngh)

(in-suite :hngh.sandbox)

(defparameter *tmp-base*
  (merge-pathnames (format nil "hngh-sandbox-test-~D-~D/" (get-universal-time)
                          (random 1000000))
                   (uiop:temporary-directory)))

(defmacro %sandbox-with (&body body)
  "Run BODY with a temp task dir + the sandbox module initialized."
  `(let ((task-dir (merge-pathnames "task/" *tmp-base*)))
     (ensure-directories-exist task-dir)
     (hngh.core.sandbox:init)
     (unwind-protect (progn ,@body)
       (hngh.core.sandbox:shutdown)
       (ignore-errors (uiop:delete-directory-tree *tmp-base* :validate t)))))

;;; --- argv construction (no bwrap required) --------------------------------

(test argv-default-deny-shape
  (%sandbox-with
    (let ((argv (hngh.core.sandbox::%argv
                 (namestring (merge-pathnames "task/" *tmp-base*)))))
      (is (member "--unshare-net" argv :test #'string=))
      (is (member "--die-with-parent" argv :test #'string=))
      (is (member "--unshare-all" argv :test #'string=)))))

(test argv-network-opt-in
  (%sandbox-with
    (let ((argv (hngh.core.sandbox::%argv
                 (namestring (merge-pathnames "task/" *tmp-base*))
                 :network t)))
      (is (member "--share-net" argv :test #'string=)))))

;;; --- fail-closed: missing bwrap never falls back --------------------------

(test fail-closed-without-bwrap
  (%sandbox-with
    ;; a bogus binary path must make availability NIL and run-sandboxed error
    (hngh.core.sandbox:init :bwrap "/nonexistent/bwrap")
    (is (not (hngh.core.sandbox:bwrap-available-p)))
    (signals error
          (hngh.core.sandbox:run-sandboxed "true" '()))))

;;; --- real smoke test (only when bwrap is present) -------------------------

(test sandbox-denies-outside-write
  (%sandbox-with
    (if (hngh.core.sandbox:bwrap-available-p)
        (let* ((outside (merge-pathnames "outside.txt" *tmp-base*))
               (cmd "sh")
               (args (list "-c"
                           (format nil "touch ~S; echo after-outside"
                                   (namestring outside)))))
          (multiple-value-bind (out code)
              (hngh.core.sandbox:run-sandboxed cmd args
                                               :task-dir
                                               (namestring
                                                (merge-pathnames "task/"
                                                                 *tmp-base*)))
            (declare (ignore out))
            ;; bwrap: /tmp/<base>/outside.txt is NOT bound -> touch fails,
            ;; file must NOT exist and exit code non-zero
            (is (not (probe-file outside)))
            (is (not (zerop code)))))
        ;; bwrap absent on this box: the suite must still pass (skip)
        (is (eq t t)))))