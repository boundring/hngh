;;;; tests/unit/test-main.lisp — Tests for Hngh core entry point
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.main
  :description "Tests for Hngh core (main, logging, config, utilities)"
  :in :hngh)

(in-suite :hngh.main)

(test version-returns-string
  (is (stringp (hngh:version)))
  (is (not (string= "" (hngh:version)))))

(test log-level-priority
  (is (< (hngh.core:log-level-priority :debug)
         (hngh.core:log-level-priority :info)))
  (is (< (hngh.core:log-level-priority :info)
         (hngh.core:log-level-priority :warn)))
  (is (< (hngh.core:log-level-priority :warn)
         (hngh.core:log-level-priority :error))))

(test should-log-p-respects-level
  (let ((hngh.core:*log-level* :info))
    (is (hngh.core:should-log-p :info))
    (is (hngh.core:should-log-p :warn))
    (is (hngh.core:should-log-p :error))
    (is (not (hngh.core:should-log-p :debug))))
  (let ((hngh.core:*log-level* :error))
    (is (not (hngh.core:should-log-p :debug)))
    (is (not (hngh.core:should-log-p :info)))
    (is (not (hngh.core:should-log-p :warn)))
    (is (hngh.core:should-log-p :error))))

(test set-log-level-works
  (let ((original hngh.core:*log-level*))
    (hngh.core:set-log-level :debug)
    (is (equal :debug hngh.core:*log-level*))
    (hngh.core:set-log-level :error)
    (is (equal :error hngh.core:*log-level*))
    (setf hngh.core:*log-level* original)))

(test config-merge-overrides-defaults
  (let ((merged (hngh.core.config:merge-config
                  '(:a 1 :b 2 :c 3)
                  '(:b 99))))
    (is (equal 1 (getf merged :a)))
    (is (equal 99 (getf merged :b)))
    (is (equal 3 (getf merged :c)))))

(test config-get-with-default
  (let ((hngh.core.config:*config* '(:foo "bar" :num 42)))
    (is (equal "bar" (hngh.core.config:config-get :foo)))
    (is (equal 42 (hngh.core.config:config-get :num)))
    (is (equal "default" (hngh.core.config:config-get :missing "default")))))

(test config-set-and-get
  (let ((hngh.core.config:*config* '()))
    (hngh.core.config:config-set :key "val")
    (is (equal "val" (hngh.core.config:config-get :key)))))

(test start-sets-running-flag
  (let ((hngh:*running* nil))
    (hngh:start :hngh-home (merge-pathnames "test-hngh-tmp/"
                                             (uiop:temporary-directory)))
    (is-true hngh:*running*)
    (hngh:stop)
    (is (not hngh:*running*))))

(test stop-when-not-running-returns-nil
  (let ((hngh:*running* nil))
    (is (not (hngh:stop)))))

(test init-state-tree-creates-directories
  (let ((tmp-home (merge-pathnames "test-state-tree/"
                                    (uiop:temporary-directory))))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh:init-state-tree tmp-home)
    (is (probe-file (merge-pathnames "config/" tmp-home)))
    (is (probe-file (merge-pathnames "state/" tmp-home)))
    (is (probe-file (merge-pathnames "journal/" tmp-home)))
    (is (probe-file (merge-pathnames "journal/events/" tmp-home)))
    (is (probe-file (merge-pathnames "journal/hnghbeats/" tmp-home)))
    (is (probe-file (merge-pathnames "knowledge-base/" tmp-home)))
    (is (probe-file (merge-pathnames "plugins/" tmp-home)))
    (is (probe-file (merge-pathnames "agents/" tmp-home)))
    (is (probe-file (merge-pathnames "secrets/" tmp-home)))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

(test keyword-from-string
  (is (equal :debug (hngh:keyword-from-string "debug")))
  (is (equal :info (hngh:keyword-from-string "INFO")))
  (is (equal :error (hngh:keyword-from-string "error"))))

(test parse-option-finds-flag
  (let ((args '("--hngh-home" "/tmp/hngh" "--version")))
    (is (equal "/tmp/hngh" (hngh:parse-option args "--hngh-home" #'identity)))
    (is (not (hngh:parse-option args "--nonexistent" #'identity)))))
