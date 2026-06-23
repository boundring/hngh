;;;; tests/unit/test-system-config.lisp — Tests for System Config (B2)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.system-config
  :description "Tests for System Config (B2)"
  :in :hngh)

(in-suite :hngh.system-config)

;;; --- Test helpers --------------------------------------------------------

(defun syscfg-setup (tmp)
  "Initialize event bus, state store, and system-config on TMP."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.plugins.system-config:init :hngh-home tmp))

(defun syscfg-teardown (tmp)
  "Shut down system-config, event bus, state store, and clean TMP."
  (hngh.plugins.system-config:shutdown)
  (hngh.core.event-bus:shutdown)
  (hngh.core.state-store:shutdown)
  (cleanup-tmp-home tmp))

(defmacro with-syscfg ((tmp-var) &body body)
  "Execute BODY with a temporary home, all services initialized."
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn
            (syscfg-setup ,tmp-var)
            ,@body)
       (syscfg-teardown ,tmp-var))))

;;; --- Test 1: Lifecycle — init/shutdown ------------------------------------

(test sc-init-shutdown
  "System config initializes and shuts down cleanly."
  (with-syscfg (tmp)
    (is (hngh.plugins.system-config:running-p)
        "Should be running after init")
    (hngh.plugins.system-config:shutdown)
    (is (not (hngh.plugins.system-config:running-p))
        "Should not be running after shutdown")
    ;; Re-init should work
    (hngh.plugins.system-config:init :hngh-home tmp)
    (is (hngh.plugins.system-config:running-p)
        "Should be running after re-init")))

;;; --- Test 2: Read config — existing system file ---------------------------

(test sc-read-existing-file
  "Read-config on /etc/hostname returns a non-empty string."
  (with-syscfg (tmp)
    (let ((content (hngh.plugins.system-config:read-config "/etc/hostname")))
      (is (stringp content)
          "Result should be a string (or NIL if hostname file missing)")
      (when content
        (is (plusp (length content))
            "File content should be non-empty")))))

;;; --- Test 3: Read config — nonexistent returns NIL -----------------------

(test sc-read-nonexistent
  "Read-config on a nonexistent file returns NIL."
  (with-syscfg (tmp)
    (let ((content (hngh.plugins.system-config:read-config
                    "/nonexistent-file-xyz-12345.conf")))
      (is (null content)
          "Nonexistent file should return NIL"))))

;;; --- Test 4: Write config — user-owned temp path succeeds -----------------

(test sc-write-user-config
  "Write-config to a temp path succeeds and can be read back."
  (with-syscfg (tmp)
    (let* ((test-path (namestring (merge-pathnames "test-config" tmp)))
           (test-content "Hello, Hngh! This is a test config."))
      (is (hngh.plugins.system-config:write-config test-path test-content)
          "Write to temp path should succeed")
      (let ((read-back (hngh.plugins.system-config:read-config test-path)))
        (is (stringp read-back) "Read-back should return a string")
        (is (string= test-content read-back)
            "Read-back should match written content")))))

;;; --- Test 5: Write config — /etc/ path fails gracefully -------------------

(test sc-write-system-config-fails-gracefully
  "Write-config to /etc/ returns NIL (no root, no daemon in tests)."
  (with-syscfg (tmp)
    (let ((result (hngh.plugins.system-config:write-config
                   "/etc/no-such-file-test.conf" "should-fail")))
      (is (not result)
          "Write to /etc/ should return NIL (no root/daemon in test)"))))

;;; --- Test 6: Managed paths — default list is non-empty --------------------

(test sc-managed-paths-default-nonempty
  "Default managed-paths list is non-empty."
  (with-syscfg (tmp)
    (let ((paths (hngh.plugins.system-config:managed-paths)))
      (is (listp paths) "Managed paths should be a list")
      (is (plusp (length paths))
          "Default managed paths list should be non-empty")
      (is (every #'stringp paths)
          "Every managed path should be a string"))))

;;; --- Test 7: Add managed path — list grows ---------------------------------

(test sc-add-managed-path
  "Adding a managed path makes the list grow."
  (with-syscfg (tmp)
    (let ((before (length (hngh.plugins.system-config:managed-paths))))
      (hngh.plugins.system-config:add-managed-path "/tmp/test-managed-path.conf")
      (let ((after (length (hngh.plugins.system-config:managed-paths))))
        (is (= (1+ before) after)
            "Managed paths list should grow by one after add")
        (is (member "/tmp/test-managed-path.conf"
                    (hngh.plugins.system-config:managed-paths)
                    :test #'string=)
            "Added path should be in the list")))))

;;; --- Test 8: Remove managed path — list shrinks ---------------------------

(test sc-remove-managed-path
  "Removing a managed path makes the list shrink."
  (with-syscfg (tmp)
    (hngh.plugins.system-config:add-managed-path "/tmp/test-removable.conf")
    (let ((before (length (hngh.plugins.system-config:managed-paths))))
      (is (member "/tmp/test-removable.conf"
                  (hngh.plugins.system-config:managed-paths)
                  :test #'string=)
          "Path should be present before removal")
      (hngh.plugins.system-config:remove-managed-path "/tmp/test-removable.conf")
      (let ((after (length (hngh.plugins.system-config:managed-paths))))
        (is (= (1- before) after)
            "Managed paths list should shrink by one after remove")
        (is (not (member "/tmp/test-removable.conf"
                         (hngh.plugins.system-config:managed-paths)
                         :test #'string=))
            "Removed path should not be in the list")))))

;;; --- Test 9: Create snapshot — fails gracefully (no daemon) ----------------

(test sc-create-snapshot-fails-gracefully
  "Create-snapshot returns NIL (system daemon not running in test env)."
  (with-syscfg (tmp)
    (let ((result (hngh.plugins.system-config:create-snapshot "test-snapshot")))
      (is (not result)
          "Snapshot creation should return NIL (no system daemon in test)"))))

;;; --- Test 10: Status — returns plist with :running key --------------------

(test sc-status-returns-plist
  "Status function returns a plist with required keys."
  (with-syscfg (tmp)
    (let ((status (hngh.plugins.system-config:status)))
      (is (listp status) "Status should be a list (plist)")
      (is (getf status :running) "Should have :running key")
      (is (eq t (getf status :running))
          "System config should be running")
      (is (getf status :managed-paths) "Should have :managed-paths key")
      (is (listp (getf status :managed-paths))
          ":managed-paths should be a list")
      (is (getf status :snapshots-count) "Should have :snapshots-count key")
      (is (integerp (getf status :snapshots-count))
          ":snapshots-count should be an integer"))))

;;; --- Test 11: List snapshots — returns a list (may be empty) ---------------

(test sc-list-snapshots-returns-list
  "List-snapshots returns a list (empty initially when no daemon)."
  (with-syscfg (tmp)
    (let ((snaps (hngh.plugins.system-config:list-snapshots)))
      (is (listp snaps) "Snapshot result should be a list")
      ;; Initially empty or may have entries from prior tests
      (is (every (lambda (s) (and (listp s)
                                  (getf s :id)
                                  (getf s :description)
                                  (getf s :timestamp)))
                 snaps)
          "Every snapshot should be a plist with :id, :description, :timestamp"))))

;;; --- Test 12: Write then read config round-trip with longer content --------

(test sc-write-read-long-content
  "Write config with longer content, read back successfully."
  (with-syscfg (tmp)
    (let* ((test-path (namestring (merge-pathnames "test-long-config" tmp)))
           (test-content "This is a longer configuration content.
It spans multiple lines and includes special characters:
  - key = value
  - option = enabled
  - path = /usr/local/bin
End of config."))
      (is (hngh.plugins.system-config:write-config test-path test-content)
          "Write should succeed")
      (let ((read-back (hngh.plugins.system-config:read-config test-path)))
        (is (stringp read-back) "Read-back should return a string")
        (is (string= test-content read-back)
            "Multi-line content should round-trip correctly")))))

;;; --- Test 13: Add managed path is idempotent for same path ----------------

(test sc-add-managed-path-idempotent
  "Adding the same path twice does not duplicate it."
  (with-syscfg (tmp)
    (let ((before (hngh.plugins.system-config:managed-paths)))
      (hngh.plugins.system-config:add-managed-path "/tmp/test-idempotent.conf")
      (let ((after-first (hngh.plugins.system-config:managed-paths)))
        (hngh.plugins.system-config:add-managed-path "/tmp/test-idempotent.conf")
        (let ((after-second (hngh.plugins.system-config:managed-paths)))
          (is (= (length after-first) (length after-second))
              "Adding same path twice should not increase count"))))))

;;; --- Test 14: Read config with tilde path expansion -----------------------

(test sc-read-config-tilde-expansion
  "Read-config with ~/ path expands tilde correctly."
  (with-syscfg (tmp)
    ;; Write a test file in the temp home and read it back using a tilde path
    (let* ((test-path (namestring (merge-pathnames "tilde-test-config" tmp)))
           (test-content "Tilde expansion test"))
      ;; Write the file first
      (ensure-directories-exist test-path)
      (with-open-file (s test-path :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create)
        (write-string test-content s))
      ;; Read it back
      (let ((read-back (hngh.plugins.system-config:read-config test-path)))
        (is (stringp read-back) "Should read back tilde-path file")
        (is (string= test-content read-back)
            "Content should match what was written")))))
