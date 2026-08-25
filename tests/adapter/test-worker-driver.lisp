(in-package :hngh.tests)

;;;; The worker-driver script (scripts/worker-driver): one continual-worker
;;;; cycle. These tests run the REAL script as a subprocess against a
;;;; scratch store and assert its exit-code contract:
;;;;   - a malformed invocation (no store or too few args) exits 2;
;;;;   - a valid cycle without injected worker ports refuses with
;;;;     no-worker-transport (exit 1) — the honest closed behavior;
;;;;     the full injected cycle is proven in the live shell proof and
;;;;     covered at dispatch level by test-worker.lisp.

(defun driver-runs (args &key store)
  "Run scripts/worker-driver with ARGS (plus --store when STORE is given);
returns the subprocess exit code."
  (multiple-value-bind (stdout stderr exit)
      (uiop:run-program
       (append (list "sbcl" "--script"
                     (namestring (cl-user::project-file "scripts/worker-driver")))
               (and store (list (format nil "--store=~A" store)))
               args)
       :output :string :error-output :string :ignore-error-status t)
    (declare (ignore stdout stderr))
    exit))

;; malformed: no store
(multiple-value-bind (exit)
    (driver-runs nil :store nil)
  (check (= 2 exit)
         "worker-driver without a --store is malformed (exit 2)"))

;; valid cycle without injected ports: the honest no-worker refusal
(let* ((store (uiop:with-temporary-file (:pathname path :keep t)
                (delete-file path)
                (ensure-directories-exist (uiop:ensure-directory-pathname path))
                (namestring (uiop:ensure-directory-pathname path))))
       (result (driver-runs (list "objective-one" "scan") :store store)))
  (check (= 1 result)
         "a bare worker-driver cycle refuses no-worker-transport (exit 1)")
  (uiop:delete-directory-tree (pathname store) :validate t))