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

;;; --- hash-chained action log (tamper-evident) ------------------------------

(test action-log-carries-chain-hash
  (%sf-with
    (hngh.core.safety-boundary:log-action :denied :target "a.lisp")
    (hngh.core.safety-boundary:log-action :denied :target "b.lisp")
    (let ((log (hngh.core.safety-boundary:read-action-log)))
      (is (= 2 (length log)))
      (let ((h0 (getf (first log) :hash))
            (h1 (getf (second log) :hash)))
        (is (stringp h0))
        (is (= 64 (length h0)))
        (is (stringp h1))
        (is (= 64 (length h1)))
        (is (string/= h0 h1))))))

(test verify-action-log-chain-intact
  (%sf-with
    (hngh.core.safety-boundary:log-action :denied :target "a.lisp")
    (hngh.core.safety-boundary:log-action :locked :target "b.lisp"
                                          :detail "mode-locked")
    (hngh.core.safety-boundary:log-action :attempt :target "c.lisp")
    (multiple-value-bind (ok idx)
        (hngh.core.safety-boundary:verify-action-log)
      (is-true ok)
      (is (null idx)))))

(test verify-action-log-reports-broken-index-on-tamper
  (%sf-with
    (hngh.core.safety-boundary:log-action :denied :target "a.lisp")
    (hngh.core.safety-boundary:log-action :denied :target "b.lisp")
    (hngh.core.safety-boundary:log-action :denied :target "c.lisp")
    (let* ((log (hngh.core.safety-boundary:read-action-log))
           (tampered (copy-list log))
           (entry (copy-list (second tampered))))
      (setf (getf entry :target) "b-EVIL.lisp")
      (setf (second tampered) entry)
      (multiple-value-bind (ok idx)
          (hngh.core.safety-boundary:verify-action-log-entries tampered)
        (is (not ok))
        (is (= 1 idx))))))

(test verify-action-log-tolerates-pre-chain-head
  (%sf-with
    ;; E1 is a genuine first-chain entry: appended to a fresh journal, so
    ;; log-action chained it from the zero root.
    (hngh.core.safety-boundary:log-action :denied :target "after-upgrade.lisp")
    (let* ((e1 (first (hngh.core.safety-boundary:read-action-log)))
           ;; E0 is a pre-migration entry that never carried a hash.
           (e0 (list :kind :denied :ts 1 :target "legacy.lisp"
                     :detail nil :attribution "legacy")))
      (multiple-value-bind (ok idx)
          (hngh.core.safety-boundary:verify-action-log-entries (list e0 e1))
        (is-true ok)
        (is (null idx))))))

(test verify-action-log-fails-closed-on-malformed
  (%sf-with
    ;; An entry that is not a plist must fail closed (values NIL NIL),
    ;; not leak a type error from the chain walk.
    (multiple-value-bind (ok idx)
        (hngh.core.safety-boundary:verify-action-log-entries '(42))
      (is (not ok))
      (is (null idx)))))

;;; --- status -----------------------------------------------------------------

(test safety-boundary-status-shape
  (%sf-with
    (let ((s (hngh.core.safety-boundary:status)))
      (is (listp s))
      (is (= 3 (length (getf s :protected))))
      (is (integerp (getf s :denials-total))))))