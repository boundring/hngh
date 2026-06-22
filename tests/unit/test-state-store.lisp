;;;; tests/unit/test-state-store.lisp — Tests for State Store (A3)
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

(defun make-tmp-home ()
  "Create a unique temp directory for testing. Returns the path."
  (merge-pathnames (concatenate 'string "test-state-"
                                  (format nil "~D" (random 1000000))
                                  "/")
                    (uiop:temporary-directory)))

(defun cleanup-tmp-home (home)
  "Delete the temp directory if it exists."
  (when (probe-file home)
    (uiop:delete-directory-tree home :validate #'identity)))

;; --- Lifecycle ---

(define-test state-store-init-shutdown
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (assert-true (hngh.core.state-store:running-p))
    (hngh.core.state-store:shutdown)
    (assert-true (not (hngh.core.state-store:running-p)))
    (cleanup-tmp-home tmp)))

;; --- File read/write ---

(define-test write-and-read-state
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "config/test.lisp" '(:key "value" :num 42))
    (let ((result (hngh.core.state-store:read-state "config/test.lisp")))
      (assert-true (not (null result)))
      (assert-equal "value" (getf result :key))
      (assert-equal 42 (getf result :num)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test read-nonexistent-returns-nil
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (assert-true (null (hngh.core.state-store:read-state "nonexistent/file.lisp")))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test write-creates-parent-dirs
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "deep/nested/path/file.lisp" "test")
    (assert-true (hngh.core.state-store:state-exists-p "deep/nested/path/file.lisp"))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test delete-state-works
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "config/deletable.lisp" "data")
    (assert-true (hngh.core.state-store:delete-state "config/deletable.lisp"))
    (assert-true (not (hngh.core.state-store:state-exists-p "config/deletable.lisp")))
    (assert-true (not (hngh.core.state-store:delete-state "config/deletable.lisp")))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test write-and-read-state-string
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state-string "config/raw.txt" "raw content here")
    (assert-equal "raw content here" (hngh.core.state-store:read-state-string "config/raw.txt"))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

;; --- Journal ---

(define-test journal-append-and-read
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:append-journal "test-log" '(:action "first" :ts 100))
    (hngh.core.state-store:append-journal "test-log" '(:action "second" :ts 200))
    (let ((entries (hngh.core.state-store:read-journal "test-log")))
      (assert-equal 2 (length entries))
      (assert-equal "first" (getf (first entries) :action))
      (assert-equal "second" (getf (second entries) :action)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

;; --- Locks ---

(define-test acquire-lock-succeeds
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (assert-true (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test second-acquire-fails
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (assert-true (not (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-b" :ttl 60)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test same-holder-can-reacquire
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (assert-true (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test release-lock-works
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (assert-true (hngh.core.state-store:release-lock "test-resource" :holder "plugin-a"))
    ;; Now someone else can acquire
    (assert-true (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-b" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test release-by-wrong-holder-fails
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (assert-true (not (hngh.core.state-store:release-lock "test-resource" :holder "plugin-b")))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test expired-lock-reclaimable
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    ;; Acquire with 1-second TTL
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 1)
    ;; Wait for it to expire
    (sleep 2)
    ;; Now another holder can acquire
    (assert-true (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-b" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test list-locks-shows-active
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "resource-1" :holder "plugin-a" :ttl 60)
    (hngh.core.state-store:acquire-lock "resource-2" :holder "plugin-b" :ttl 60)
    (let ((locks (hngh.core.state-store:list-locks)))
      (assert-equal 2 (length locks)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test shutdown-releases-locks
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "hngh" :ttl 60)
    (hngh.core.state-store:shutdown)
    ;; Locks dir still exists but files should be gone
    ;; (shutdown calls release-all-locks with holder "hngh")
    (let ((locks-dir (merge-pathnames "state/locks/" tmp)))
      (when (probe-file locks-dir)
        (let ((files (directory (merge-pathnames "*.lock" locks-dir))))
          (assert-true (or (null files)
                           (= 0 (length files))))))
      (cleanup-tmp-home tmp))))

;; --- Snapshot ---

(define-test snapshot-returns-integer
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "config/test.lisp" "test")
    (let ((hash (hngh.core.state-store:snapshot)))
      (assert-true (integerp hash)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(define-test snapshot-changes-on-write
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (let ((hash1 (hngh.core.state-store:snapshot)))
      (hngh.core.state-store:write-state "config/new.lisp" "new data")
      (let ((hash2 (hngh.core.state-store:snapshot)))
        (assert-true (not (= hash1 hash2)))))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))
