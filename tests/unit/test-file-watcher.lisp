;;;; tests/unit/test-file-watcher.lisp — Tests for File Watcher (Wave 2)
;;;;
;;;; Fixture tests exercise registration, event publishing, deregistration,
;;;; scoping, and directory watching with mtime-poll.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.file-watcher
  :description "Tests for file-watcher plugin (Wave 2)"
  :in :hngh)

(in-suite :hngh.file-watcher)

;;; --- Fixture helpers -------------------------------------------------------

(defun %file-watcher-tmp-dir ()
  "Return a fresh temp directory for file-watcher tests."
  (merge-pathnames (format nil "hngh-file-watcher-test-~D/"
                           (random 1000000))
                   (uiop:temporary-directory)))

(defun %cleanup-tmp-dir (dir)
  "Delete a test directory tree."
  (when (probe-file dir)
    (uiop:delete-directory-tree dir :validate t)))

(defun %touch-file (path &optional (content "test"))
  "Write CONTENT to PATH, creating parent dirs."
  (ensure-directories-exist (directory-namestring path))
  (with-open-file (s path :direction :output :if-exists :supersede)
    (write-string content s)))

;;; --- Tests -----------------------------------------------------------------

;;; Test 1: register-path registers and seeds snapshot
(test register-path-seeds-snapshot
  (let ((dir (%file-watcher-tmp-dir)))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (is-true (hngh.plugins.file-watcher:register-path
                     (namestring file) :label "test-file"))
           (is (= 1 (length (hngh.plugins.file-watcher:registered-paths))))
           (hngh.plugins.file-watcher:deregister-path
            (namestring file)))
      (%cleanup-tmp-dir dir))))

;;; Test 2: file.changed event fires on modification
(test file-changed-event-fires
  (let ((dir (%file-watcher-tmp-dir))
        (events nil)
        (tmp-home (make-tmp-home)))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (hngh.core.event-bus:init :hngh-home tmp-home)
           (hngh.plugins.file-watcher:register-path
            (namestring file) :label "test-file")
           ;; Subscribe to file.changed
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event)
              (push event events)))
           ;; Init watcher with short interval
           (setf hngh.plugins.file-watcher:*watch-interval* 1)
           (hngh.plugins.file-watcher:init)
           ;; Modify file after first poll cycle seeds snapshot
           (sleep 2)
           (%touch-file file "modified")
           ;; Wait for scan to detect change
           (sleep 3)
           (hngh.plugins.file-watcher:shutdown)
           (is-true (find-if
                     (lambda (e)
                       (string= "file.changed"
                                (hngh.core.event-bus:event-topic e)))
                     events))
           (when events
             (let ((payload (hngh.core.event-bus:event-payload
                             (first events))))
               (is (string= "test-file"
                            (getf payload :label))))))
      (hngh.plugins.file-watcher:shutdown)
      (hngh.core.event-bus:shutdown)
      (hngh.plugins.file-watcher:deregister-path
       (namestring (merge-pathnames "test.txt" dir)))
      (%cleanup-tmp-dir dir)
      (cleanup-tmp-home tmp-home))))

;;; Test 3: deregister-path stops events
(test deregister-stops-events
  (let ((dir (%file-watcher-tmp-dir))
        (events nil)
        (tmp-home (make-tmp-home)))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (hngh.core.event-bus:init :hngh-home tmp-home)
           (hngh.plugins.file-watcher:register-path
            (namestring file) :label "test-file")
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event) (push event events)))
           (setf hngh.plugins.file-watcher:*watch-interval* 1)
           (hngh.plugins.file-watcher:init)
           ;; Deregister before modification
           (hngh.plugins.file-watcher:deregister-path
            (namestring file))
           (sleep 1)
           (%touch-file file "should-not-fire")
           (sleep 3)
           (hngh.plugins.file-watcher:shutdown)
           (setf hngh.plugins.file-watcher:*watch-interval* 5)
           (is (null events)))
      (hngh.plugins.file-watcher:shutdown)
      (hngh.core.event-bus:shutdown)
      (%cleanup-tmp-dir dir)
      (cleanup-tmp-home tmp-home))))

;;; Test 4: register-path on nonexistent path returns nil
(test register-nonexistent-path
  (is (null (hngh.plugins.file-watcher:register-path
             "/nonexistent/path/does/not/exist.txt"))))

;;; Test 5: status returns correct plist
(test status-returns-plist
  (let ((dir (%file-watcher-tmp-dir)))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "content")
           (hngh.plugins.file-watcher:register-path
            (namestring file) :label "status-test")
           (hngh.plugins.file-watcher:init)
           (let ((status (hngh.plugins.file-watcher:status)))
             (is (getf status :running))
             (is (= 1 (getf status :registered-count))))
           (hngh.plugins.file-watcher:shutdown)
           (let ((status (hngh.plugins.file-watcher:status)))
             (is-false (getf status :running))))
      (hngh.plugins.file-watcher:deregister-path
       (namestring (merge-pathnames "test.txt" dir)))
      (%cleanup-tmp-dir dir))))

;;; Test 6: scoped registration tags events
(test scoped-registration-tags-events
  (let ((dir (%file-watcher-tmp-dir))
        (events nil)
        (tmp-home (make-tmp-home)))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (hngh.core.event-bus:init :hngh-home tmp-home)
           (hngh.plugins.file-watcher:register-path
            (namestring file) :scope :designer :label "designer-inbox")
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event) (push event events)))
           (setf hngh.plugins.file-watcher:*watch-interval* 1)
           (hngh.plugins.file-watcher:init)
           (sleep 2)
           (%touch-file file "modified")
           (sleep 3)
           (hngh.plugins.file-watcher:shutdown)
           (when events
             (let ((payload (hngh.core.event-bus:event-payload
                             (first events))))
               (is (eq :designer (getf payload :scope))))))
      (hngh.plugins.file-watcher:shutdown)
      (hngh.core.event-bus:shutdown)
      (hngh.plugins.file-watcher:deregister-path
       (namestring (merge-pathnames "test.txt" dir)))
      (%cleanup-tmp-dir dir)
      (cleanup-tmp-home tmp-home))))

;;; Test 7: directory watch detects new file
(test directory-watch-detects-new-file
  (let ((dir (%file-watcher-tmp-dir))
        (events nil)
        (tmp-home (make-tmp-home)))
    (unwind-protect
         (progn
           (ensure-directories-exist dir)
           (hngh.core.event-bus:init :hngh-home tmp-home)
           (hngh.plugins.file-watcher:register-path
            (namestring dir) :label "watched-dir")
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event) (push event events)))
           (setf hngh.plugins.file-watcher:*watch-interval* 1)
           (hngh.plugins.file-watcher:init)
           (sleep 2)
           ;; Create a new file in the watched directory
           (%touch-file (merge-pathnames "new-file.txt" dir) "new content")
           (sleep 3)
           (hngh.plugins.file-watcher:shutdown)
           (is-true (find-if
                     (lambda (e)
                       (let ((p (hngh.core.event-bus:event-payload e)))
                         (search "new-file.txt" (getf p :path))))
                     events)))
      (hngh.plugins.file-watcher:shutdown)
      (hngh.core.event-bus:shutdown)
      (hngh.plugins.file-watcher:deregister-path (namestring dir))
      (%cleanup-tmp-dir dir)
      (cleanup-tmp-home tmp-home))))
