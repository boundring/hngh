;;;; tests/unit/test-safety-boundary.lisp — Wave C immutable safety layer.
;;;;
;;;; Isolated temp hngh-home. Covers: registry freeze, protected-path
;;;; detection (file + directory containment), fail-closed mutation guard
;;;; with action-log recording, ensure-mutable signalling, action-log
;;;; append-only shape, empty-log denials count, status shape. No network,
;;;; no model, no privileges (mode-lock is tolerated/ignored in temp dirs).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later

(in-package :hngh.tests)

(def-suite :hngh.safety-boundary
  :description "Tests for the Wave C immutable safety layer"
  :in :hngh)

(in-suite :hngh.safety-boundary)

;;; --- fixture: isolated temp hngh-home -------------------------------------

(defun %sf-home ()
  (let* ((base (merge-pathnames
                (format nil "hngh-sf-test-~D-~D-/"
                        (get-universal-time) (random 1000000))
                (uiop:temporary-directory)))
         (h (merge-pathnames "home/" base)))
    (ensure-directories-exist h)
    h))

(defmacro %sf-with (&body body)
  `(let* ((home (%sf-home))
          (hngh:*hngh-home* home))
     (hngh.core.state-store:init :hngh-home home)
     (hngh.core.safety-boundary:init :hngh-home home)
     (unwind-protect (progn ,@body)
       (hngh.core.safety-boundary:shutdown))))

;;; --- registry + detection --------------------------------------------------

(test registry-frozen-at-init
  (%sf-with
    (is (= 3 (length (hngh.core.safety-boundary:protected-paths))))
    (let ((p (namestring (merge-pathnames
                          "config/hngh.lisp" hngh:*hngh-home*))))
      (is (hngh.core.safety-boundary:protected-path-p p))
      (is (hngh.core.safety-boundary:allow-mutation-p
           (merge-pathnames "journal/other.lisp" hngh:*hngh-home*))))))

(test protected-detects-contained-dir
  (%sf-with
    ;; a path INSIDE the protected config/ dir is protected by containment
    (let ((p (merge-pathnames "config/approvals.lisp" hngh:*hngh-home*)))
      (is (hngh.core.safety-boundary:protected-path-p p)))
    ;; a path OUTSIDE config/ is free
    (let ((p (merge-pathnames "journal/actions.lisp" hngh:*hngh-home*)))
      (is (not (hngh.core.safety-boundary:protected-path-p p))))))

;;; --- mutation guard + action log ------------------------------------------

(test mutation-denied-records-action
  (%sf-with
    (let ((p (merge-pathnames "config/hngh.lisp" hngh:*hngh-home*)))
      (is (not (hngh.core.safety-boundary:allow-mutation-p p)))
      (let ((log (hngh.core.safety-boundary:read-action-log)))
        (is (= 1 (length log)))
        (is (eq :denied (getf (first log) :kind)))
        (is (search "config/hngh.lisp"
                    (getf (first log) :target)))))))

(test mutation-allowed-no-log-entry
  (%sf-with
    (let ((p (merge-pathnames "journal/other.lisp" hngh:*hngh-home*)))
      (is (hngh.core.safety-boundary:allow-mutation-p p))
      (is (null (hngh.core.safety-boundary:read-action-log))))))

(test ensure-mutable-signals-on-protected
  (%sf-with
    (let ((p (merge-pathnames "config/sentry.lisp" hngh:*hngh-home*)))
      (signals error
        (hngh.core.safety-boundary:ensure-mutable p)))))

(test action-log-append-only-shape
  (%sf-with
    (hngh.core.safety-boundary:log-action :locked :target "x.lisp")
    (hngh.core.safety-boundary:log-action :denied :target "y.lisp")
    (let ((log (hngh.core.safety-boundary:read-action-log)))
      (is (= 2 (length log)))
      (is (eq :locked (getf (first log) :kind)))
      (is (eq :denied (getf (second log) :kind)))
      (is (integerp (getf (first log) :ts))))))

;;; --- status -----------------------------------------------------------------

(test safety-boundary-status-shape
  (%sf-with
    (let ((s (hngh.core.safety-boundary:status)))
      (is (listp s))
      (is (= 3 (length (getf s :protected))))
      (is (integerp (getf s :denials-total))))))