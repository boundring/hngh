;;;; tests/unit/test-plugin-host.lisp — Tests for Plugin Host (A1)
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

(defun fixture-path (relative)
  "Return the path to a test fixture file."
  (merge-pathnames relative
                    (merge-pathnames "tests/fixtures/"
                                      (asdf:system-source-directory :hngh))))

;; --- Manifest parsing ---

(define-test parse-manifest-valid
  (let ((manifest (hngh.core.plugin-host:parse-manifest
                    (fixture-path "test-plugin/manifest.lisp"))))
    (assert-equal "test-plugin" (getf manifest :name))
    (assert-equal "0.1.0" (getf manifest :version))
    (assert-equal :first-party (getf manifest :trust-tier))
    (assert-equal :cl (getf manifest :language))))

(define-test parse-manifest-missing-file
  (assert-condition error
    (hngh.core.plugin-host:parse-manifest "/nonexistent/manifest.lisp")))

;; --- Manifest validation ---

(define-test validate-manifest-rejects-bad-tier
  (assert-condition error
    (hngh.core.plugin-host:validate-manifest
      '(:name "x" :version "0.1" :trust-tier :bogus :language :cl))))

(define-test validate-manifest-rejects-bad-language
  (assert-condition error
    (hngh.core.plugin-host:validate-manifest
      '(:name "x" :version "0.1" :trust-tier :first-party :language :bogus))))

;; --- Plugin loading ---

(define-test load-plugin-works
  ;; Clear registry first in case of prior runs
  (hngh.core.plugin-host:clear-registry)
  (let ((info (hngh.core.plugin-host:load-plugin
                (fixture-path "test-plugin/manifest.lisp"))))
    (assert-true (not (null info)))
    (assert-equal "test-plugin" (hngh.core.plugin-host:plugin-info-name info))
    (assert-equal "0.1.0" (hngh.core.plugin-host:plugin-info-version info))
    ;; Init function should have been called
    (assert-equal :initialized
                  (funcall (find-symbol "GET-STATE" :hngh.plugins.test-plugin)))
    ;; Cleanup
    (hngh.core.plugin-host:unload-plugin "test-plugin")))

(define-test load-twice-errors
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (assert-condition error
    (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp")))
  (hngh.core.plugin-host:unload-plugin "test-plugin"))

;; --- Plugin unloading ---

(define-test unload-plugin-calls-cleanup
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (hngh.core.plugin-host:unload-plugin "test-plugin")
  ;; Cleanup should have cleared state
  (assert-equal nil
                (funcall (find-symbol "GET-STATE" :hngh.plugins.test-plugin)))
  ;; Plugin should not be in registry
  (assert-true (not (hngh.core.plugin-host:plugin-loaded-p "test-plugin"))))

(define-test unload-nonexistent-returns-nil
  (assert-true (not (hngh.core.plugin-host:unload-plugin "nonexistent-plugin"))))

;; --- Plugin reload ---

(define-test reload-plugin-with-reload-fn
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (hngh.core.plugin-host:reload-plugin "test-plugin")
  (assert-equal :reloaded
                (funcall (find-symbol "GET-STATE" :hngh.plugins.test-plugin)))
  (hngh.core.plugin-host:unload-plugin "test-plugin"))

;; --- Query ---

(define-test list-plugins-shows-loaded
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (let ((plugins (hngh.core.plugin-host:list-plugins)))
    (assert-equal 1 (length plugins)))
  (hngh.core.plugin-host:unload-plugin "test-plugin")
  (let ((plugins (hngh.core.plugin-host:list-plugins)))
    (assert-equal 0 (length plugins))))

(define-test get-plugin-returns-info
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (let ((info (hngh.core.plugin-host:get-plugin "test-plugin")))
    (assert-true (not (null info)))
    (assert-equal "test-plugin" (hngh.core.plugin-host:plugin-info-name info)))
  (hngh.core.plugin-host:unload-plugin "test-plugin"))

(define-test plugin-loaded-p-returns-bool
  (hngh.core.plugin-host:clear-registry)
  (assert-true (not (hngh.core.plugin-host:plugin-loaded-p "test-plugin")))
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (assert-true (hngh.core.plugin-host:plugin-loaded-p "test-plugin"))
  (hngh.core.plugin-host:unload-plugin "test-plugin")
  (assert-true (not (hngh.core.plugin-host:plugin-loaded-p "test-plugin"))))
