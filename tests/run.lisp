(defparameter *project-root*
  (merge-pathnames "../"
                   (make-pathname :name nil :type nil
                                  :defaults *load-truename*)))

(defun project-file (relative)
  (merge-pathnames relative *project-root*))

(require :asdf)
(load (project-file "src/packages.lisp"))
(load (project-file "src/domain/profile.lisp"))
(load (project-file "src/domain/mission.lisp"))
(load (project-file "src/domain/loadout.lisp"))
(load (project-file "src/domain/run.lisp"))
(load (project-file "src/domain/outcome.lisp"))
(load (project-file "src/domain/governance.lisp"))
(load (project-file "src/application/ports.lisp"))
(load (project-file "src/application/create-run.lisp"))
(load (project-file "src/application/arm-run.lisp"))
(load (project-file "src/application/start-run.lisp"))
(load (project-file "src/application/checkpoint.lisp"))
(load (project-file "src/application/close-run.lisp"))
(load (project-file "src/adapter/evidence.lisp"))

(in-package :hngh.tests)

(load (cl-user::project-file "tests/support/boundary-guards.lisp"))

(defparameter *check-count* 0)

(defun check (condition description)
  (unless condition
    (error "check failed: ~A" description))
  (incf *check-count*))

(defun signals-error-p (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (error () t)))

(load (cl-user::project-file "tests/domain/test-loadout.lisp"))
(load (cl-user::project-file "tests/domain/test-run-state.lisp"))
(load (cl-user::project-file "tests/domain/test-governance.lisp"))
(load (cl-user::project-file "tests/support/fakes.lisp"))
(load (cl-user::project-file "tests/application/test-create-run.lisp"))
(load (cl-user::project-file "tests/application/test-arm-run.lisp"))
(load (cl-user::project-file "tests/application/test-start-run.lisp"))
(load (cl-user::project-file "tests/application/test-checkpoint.lisp"))
(load (cl-user::project-file "tests/application/test-close-run.lisp"))
(load (cl-user::project-file "tests/adapter/test-evidence.lisp"))

(defun read-fixture (relative)
  (with-open-file (stream (cl-user::project-file relative))
    (let ((*read-eval* nil))
      (read stream))))

(check (equal '(:work :observe)
              (hngh:validate-profile '(:work :observe)))
       "profile preserves explicit mode order")
(check (equal '(:work :observe)
              (hngh.domain:validate-profile '(:work :observe)))
       "domain profile validation preserves explicit mode order")
(check (signals-error-p (lambda () (hngh:validate-profile '(:work :unknown))))
       "unknown mode fails closed")
(check (signals-error-p (lambda () (hngh:validate-profile '(:work :work))))
       "duplicate mode fails closed")
(check (signals-error-p (lambda () (hngh:validate-profile :work)))
       "non-list profile fails closed")

(check (not (dependency-fixture-allowed-p
             (read-fixture "tests/fixtures/dependency-guard/inward-imports-presentation.lisp")))
       "inward package importing presentation fails the dependency guard")
(check (not (dependency-fixture-allowed-p
             (read-fixture "tests/fixtures/dependency-guard/inward-imports-adapter.lisp")))
       "inward package importing an adapter fails the dependency guard")
(check (dependency-fixture-allowed-p
        (read-fixture "tests/fixtures/dependency-guard/inward-dependencies-clean.lisp"))
       "inward package with core-only dependencies passes the dependency guard")
(check (reference-lexicon-safe-p
        (read-fixture "tests/fixtures/reference-lexicon/presentation-only.lisp"))
       "presentation-only lexicon passes review")
(check (not (reference-lexicon-safe-p
             (read-fixture "tests/fixtures/reference-lexicon/attempts-canonical-control.lisp")))
       "lexicon cannot carry canonical control fields")

(format t "~D checks passed.~%" *check-count*)
