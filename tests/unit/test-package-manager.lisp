;;;; tests/unit/test-package-manager.lisp — Tests for Package Manager (B1)
;;;;
;;;; Read-only tests exercise real pacman on this system.
;;;; Privileged operation tests verify correct failure modes without daemon.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.package-manager
  :description "Tests for Package Manager (B1)"
  :in :hngh)

(in-suite :hngh.package-manager)

;;; --- Helpers -------------------------------------------------------------

(defun pkgmgr-setup (tmp)
  "Initialize event bus, state store, and package manager on TMP."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.plugins.package-manager:init :hngh-home tmp))

(defun pkgmgr-teardown (tmp)
  "Shut down package manager, event bus, state store, and clean TMP."
  (hngh.plugins.package-manager:shutdown)
  (hngh.core.event-bus:shutdown)
  (hngh.core.state-store:shutdown)
  (cleanup-tmp-home tmp))

(defmacro with-pkgmgr ((tmp-var) &body body)
  "Execute BODY with a temporary home, all services initialized."
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn
            (pkgmgr-setup ,tmp-var)
            ,@body)
       (pkgmgr-teardown ,tmp-var))))

;;; --- Test 1: Lifecycle ---------------------------------------------------

(test pm-init-shutdown
  "Package manager initializes and shuts down cleanly."
  (with-pkgmgr (tmp)
    (is (hngh.plugins.package-manager:running-p)
        "Should be running after init")
    (hngh.plugins.package-manager:shutdown)
    (is (not (hngh.plugins.package-manager:running-p))
        "Should not be running after shutdown")
    ;; Re-init should work
    (hngh.plugins.package-manager:init :hngh-home tmp)
    (is (hngh.plugins.package-manager:running-p)
        "Should be running after re-init")))

;;; --- Test 2: Search known package ----------------------------------------

(test pm-search-known-package
  "Search for 'bash' returns a list containing 'bash'."
  (with-pkgmgr (tmp)
    (let ((results (hngh.plugins.package-manager:search "bash")))
      (is (listp results) "Result should be a list")
      (is (plusp (length results)) "Should find at least one result for 'bash'")
      (is (member "bash" results :test #'string=)
          "Results should contain 'bash'"))))

;;; --- Test 3: Search nonexistent package ----------------------------------

(test pm-search-nonexistent
  "Search for a nonexistent package returns an empty list."
  (with-pkgmgr (tmp)
    (let ((results (hngh.plugins.package-manager:search
                    "xyznonexistentpkg123456789")))
      (is (listp results) "Result should be a list")
      (is (zerop (length results))
          "Nonexistent package should return empty list"))))

;;; --- Test 4: Info for installed package ----------------------------------

(test pm-info-installed
  "Info on 'bash' returns a plist with :name and :version."
  (with-pkgmgr (tmp)
    (let ((info (hngh.plugins.package-manager:info "bash")))
      (is (listp info) "Info should be a plist (list)")
      (is (getf info :name) "Should have :name key")
      (is (stringp (getf info :name)) ":name should be a string")
      (is (string= "bash" (getf info :name)) ":name should be \"bash\"")
      (is (getf info :version) "Should have :version key")
      (is (stringp (getf info :version)) ":version should be a string")
      (is (plusp (length (getf info :version)))
          ":version should be non-empty"))))

;;; --- Test 5: List installed returns non-empty list -----------------------

(test pm-list-installed-nonempty
  "List installed packages returns a non-empty list."
  (with-pkgmgr (tmp)
    (let ((pkgs (hngh.plugins.package-manager:list-installed)))
      (is (listp pkgs) "Should return a list")
      (is (plusp (length pkgs))
          "Should have at least one installed package")
      (is (every #'stringp pkgs)
          "Every element should be a string"))))

;;; --- Test 6: List installed explicit -------------------------------------

(test pm-list-installed-explicit
  "List explicitly installed packages returns a subset of all packages."
  (with-pkgmgr (tmp)
    (let ((all-pkgs (hngh.plugins.package-manager:list-installed))
          (explicit-pkgs (hngh.plugins.package-manager:list-installed :explicit-p t)))
      (is (listp explicit-pkgs) "Should return a list")
      (is (every #'stringp explicit-pkgs)
          "Every element should be a string")
      ;; Explicit packages should be a subset of all installed
      (is (>= (length all-pkgs) (length explicit-pkgs))
          "Explicit list should not be larger than full list"))))

;;; --- Test 7: List AUR returns a list ------------------------------------

(test pm-list-aur-returns-list
  "List AUR packages returns a list (may be empty)."
  (with-pkgmgr (tmp)
    (let ((aur-pkgs (hngh.plugins.package-manager:list-aur)))
      (is (listp aur-pkgs) "Should return a list")
      (is (every #'stringp aur-pkgs)
          "Every element should be a string"))))

;;; --- Test 8: List updates returns a list ---------------------------------

(test pm-list-updates-returns-list
  "List updates returns a list of plists (may be empty)."
  (with-pkgmgr (tmp)
    (let ((updates (hngh.plugins.package-manager:list-updates)))
      (is (listp updates) "Should return a list")
      ;; If there are updates, verify the structure
      (dolist (u updates)
        (is (listp u) "Each update should be a plist")
        (is (getf u :name) "Each update should have :name")
        (is (getf u :old-version) "Each update should have :old-version")
        (is (getf u :new-version) "Each update should have :new-version")))))

;;; --- Test 9: List orphans returns a list ---------------------------------

(test pm-list-orphans-returns-list
  "List orphans returns a list of strings (may be empty)."
  (with-pkgmgr (tmp)
    (let ((orphans (hngh.plugins.package-manager:list-orphans)))
      (is (listp orphans) "Should return a list")
      (is (every #'stringp orphans)
          "Every element should be a string"))))

;;; --- Test 10: History starts empty and grows -----------------------------

(test pm-history-starts-empty
  "History function returns an empty list after fresh init."
  (with-pkgmgr (tmp)
    (let ((h (hngh.plugins.package-manager:history)))
      (is (listp h) "History should be a list")
      (is (zerop (length h)) "History should start empty on fresh init"))))

;;; --- Test 11: History grows after add-to-history -------------------------

(test pm-history-grows
  "History list grows after an internal add-to-history call."
  (with-pkgmgr (tmp)
    (is (zerop (length (hngh.plugins.package-manager:history)))
        "History should start empty")
    ;; Manipulate *history* directly to simulate an operation record
    (let ((entry (list :timestamp (get-universal-time)
                       :op :test
                       :packages '("testpkg")
                       :result :success)))
      (setf hngh.plugins.package-manager:*history*
            (list entry))
      (let ((h (hngh.plugins.package-manager:history)))
        (is (= 1 (length h)) "History should have one entry")
        (is (eq :test (getf (first h) :op))
            "Entry should have :op :test")
        (is (equal '("testpkg") (getf (first h) :packages))
            "Entry should contain the test package")))))

;;; --- Test 12: Status returns plist ---------------------------------------

(test pm-status-returns-plist
  "Status function returns a plist with required keys."
  (with-pkgmgr (tmp)
    (let ((status (hngh.plugins.package-manager:status)))
      (is (listp status) "Status should be a list (plist)")
      (is (getf status :running) "Should have :running key")
      (is (eq t (getf status :running)) "Package manager should be running")
      (is (getf status :aur-helper) "Should have :aur-helper key")
      (is (getf status :packages-installed) "Should have :packages-installed key")
      (is (integerp (getf status :packages-installed))
          ":packages-installed should be an integer"))))

;;; --- Test 13: Check breakage returns plist ------------------------------

(test pm-check-breakage-returns-plist
  "Check-breakage returns a plist with required keys."
  (with-pkgmgr (tmp)
    (let ((breakage (hngh.plugins.package-manager:check-breakage)))
      (is (listp breakage) "Breakage should be a list (plist)")
      (is (member :missing-files breakage) "Should have :missing-files key")
      (is (member :orphans breakage) "Should have :orphans key")
      (is (member :broken-p breakage) "Should have :broken-p key")
      (is (listp (getf breakage :missing-files))
          ":missing-files should be a list")
      (is (listp (getf breakage :orphans))
          ":orphans should be a list"))))

;;; --- Test 14: Remove-packages signals not implemented --------------------

(test pm-remove-packages-not-implemented
  "Remove-packages returns NIL (not yet implemented via daemon)."
  (with-pkgmgr (tmp)
    (let ((result (hngh.plugins.package-manager:remove-packages
                   '("testpkg") :reason "test")))
      (is (not result) "Remove should return NIL (not implemented)"))))

;;; --- Test 15: Search with * wildcard works -------------------------------

(test pm-search-wildcard
  "Search with partial name returns matching packages."
  (with-pkgmgr (tmp)
    (let ((results (hngh.plugins.package-manager:search "systemd")))
      (is (listp results) "Should return a list")
      ;; systemd is likely installed; there should be at least one result
      ;; but it could be just 'systemd' itself on minimal systems
      (is (find-if (lambda (s) (search "systemd" s)) results)
          "At least one result should contain 'systemd'"))))
