;;;; tests/unit/test-state-store.lisp — Tests for State Store (A3)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.state-store
  :description "Tests for State Store (A3)"
  :in :hngh)

(in-suite :hngh.state-store)

(test state-store-init-shutdown
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (is (hngh.core.state-store:running-p))
    (hngh.core.state-store:shutdown)
    (is (not (hngh.core.state-store:running-p)))
    (cleanup-tmp-home tmp)))

(test write-and-read-state
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "config/test.lisp" '(:key "value" :num 42))
    (let ((result (hngh.core.state-store:read-state "config/test.lisp")))
      (is (not (null result)))
      (is (equal "value" (getf result :key)))
      (is (equal 42 (getf result :num)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp))))

(test read-nonexistent-returns-nil
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (is (null (hngh.core.state-store:read-state "nonexistent/file.lisp")))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test write-creates-parent-dirs
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "deep/nested/path/file.lisp" "test")
    (is (hngh.core.state-store:state-exists-p "deep/nested/path/file.lisp"))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test delete-state-works
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "config/deletable.lisp" "data")
    (is (hngh.core.state-store:delete-state "config/deletable.lisp"))
    (is (not (hngh.core.state-store:state-exists-p "config/deletable.lisp")))
    (is (not (hngh.core.state-store:delete-state "config/deletable.lisp")))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test write-and-read-state-string
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state-string "config/raw.txt" "raw content here")
    (is (equal "raw content here" (hngh.core.state-store:read-state-string "config/raw.txt")))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test journal-append-and-read
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:append-journal "test-log" '(:action "first" :ts 100))
    (hngh.core.state-store:append-journal "test-log" '(:action "second" :ts 200))
    (let ((entries (hngh.core.state-store:read-journal "test-log")))
      (is (equal 2 (length entries)))
      (is (equal "first" (getf (first entries) :action)))
      (is (equal "second" (getf (second entries) :action))))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test acquire-lock-succeeds
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (is (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test second-acquire-fails
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (is (not (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-b" :ttl 60)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test same-holder-can-reacquire
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (is (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test release-lock-works
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (is (hngh.core.state-store:release-lock "test-resource" :holder "plugin-a"))
    (is (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-b" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test release-by-wrong-holder-fails
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 60)
    (is (not (hngh.core.state-store:release-lock "test-resource" :holder "plugin-b")))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test expired-lock-reclaimable
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-a" :ttl 1)
    (sleep 2)
    (is (hngh.core.state-store:acquire-lock "test-resource" :holder "plugin-b" :ttl 60))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test list-locks-shows-active
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "resource-1" :holder "plugin-a" :ttl 60)
    (hngh.core.state-store:acquire-lock "resource-2" :holder "plugin-b" :ttl 60)
    (is (equal 2 (length (hngh.core.state-store:list-locks))))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test shutdown-releases-locks
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:acquire-lock "test-resource" :holder "hngh" :ttl 60)
    (hngh.core.state-store:shutdown)
    (let ((locks-dir (merge-pathnames "state/locks/" tmp)))
      (when (probe-file locks-dir)
        (let ((files (directory (merge-pathnames "*.lock" locks-dir))))
          (is (or (null files) (= 0 (length files)))))))
    (cleanup-tmp-home tmp)))

(test snapshot-returns-integer
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.core.state-store:write-state "config/test.lisp" "test")
    (is (integerp (hngh.core.state-store:snapshot)))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))

(test snapshot-changes-on-write
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (let ((hash1 (hngh.core.state-store:snapshot)))
      (hngh.core.state-store:write-state "config/new.lisp" "new data")
      (let ((hash2 (hngh.core.state-store:snapshot)))
        (is (not (= hash1 hash2)))))
    (hngh.core.state-store:shutdown)
    (cleanup-tmp-home tmp)))
