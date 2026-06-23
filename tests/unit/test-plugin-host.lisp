;;;; tests/unit/test-plugin-host.lisp — Tests for Plugin Host (A1)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.plugin-host
  :description "Tests for Plugin Host (A1)"
  :in :hngh)

(in-suite :hngh.plugin-host)

(test parse-manifest-valid
  (let ((manifest (hngh.core.plugin-host:parse-manifest
                    (fixture-path "test-plugin/manifest.lisp"))))
    (is (equal "test-plugin" (getf manifest :name)))
    (is (equal "0.1.0" (getf manifest :version)))
    (is (equal :first-party (getf manifest :trust-tier)))
    (is (equal :cl (getf manifest :language)))))

(test parse-manifest-missing-file
  (signals error
    (hngh.core.plugin-host:parse-manifest "/nonexistent/manifest.lisp")))

(test validate-manifest-rejects-bad-tier
  (signals error
    (hngh.core.plugin-host:validate-manifest
      '(:name "x" :version "0.1" :trust-tier :bogus :language :cl))))

(test validate-manifest-rejects-bad-language
  (signals error
    (hngh.core.plugin-host:validate-manifest
      '(:name "x" :version "0.1" :trust-tier :first-party :language :bogus))))

(test load-plugin-works
  (hngh.core.plugin-host:clear-registry)
  (let ((info (hngh.core.plugin-host:load-plugin
                (fixture-path "test-plugin/manifest.lisp"))))
    (is (not (null info)))
    (is (equal "test-plugin" (hngh.core.plugin-host:plugin-info-name info)))
    (is (equal "0.1.0" (hngh.core.plugin-host:plugin-info-version info)))
    (is (equal :initialized
              (funcall (find-symbol "GET-STATE" :hngh.plugins.test-plugin))))
    (hngh.core.plugin-host:unload-plugin "test-plugin")))

(test load-twice-errors
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (signals error
    (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp")))
  (hngh.core.plugin-host:unload-plugin "test-plugin"))

(test unload-plugin-calls-cleanup
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (hngh.core.plugin-host:unload-plugin "test-plugin")
  (is (equal nil
            (funcall (find-symbol "GET-STATE" :hngh.plugins.test-plugin))))
  (is (not (hngh.core.plugin-host:plugin-loaded-p "test-plugin"))))

(test unload-nonexistent-returns-nil
  (is (not (hngh.core.plugin-host:unload-plugin "nonexistent-plugin"))))

(test reload-plugin-with-reload-fn
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (hngh.core.plugin-host:reload-plugin "test-plugin")
  (is (equal :reloaded
            (funcall (find-symbol "GET-STATE" :hngh.plugins.test-plugin))))
  (hngh.core.plugin-host:unload-plugin "test-plugin"))

(test list-plugins-shows-loaded
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (is (equal 1 (length (hngh.core.plugin-host:list-plugins))))
  (hngh.core.plugin-host:unload-plugin "test-plugin")
  (is (equal 0 (length (hngh.core.plugin-host:list-plugins)))))

(test get-plugin-returns-info
  (hngh.core.plugin-host:clear-registry)
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (let ((info (hngh.core.plugin-host:get-plugin "test-plugin")))
    (is (not (null info)))
    (is (equal "test-plugin" (hngh.core.plugin-host:plugin-info-name info))))
  (hngh.core.plugin-host:unload-plugin "test-plugin"))

(test plugin-loaded-p-returns-bool
  (hngh.core.plugin-host:clear-registry)
  (is (not (hngh.core.plugin-host:plugin-loaded-p "test-plugin")))
  (hngh.core.plugin-host:load-plugin (fixture-path "test-plugin/manifest.lisp"))
  (is (hngh.core.plugin-host:plugin-loaded-p "test-plugin"))
  (hngh.core.plugin-host:unload-plugin "test-plugin")
  (is (not (hngh.core.plugin-host:plugin-loaded-p "test-plugin"))))
