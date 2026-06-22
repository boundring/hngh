;;;; tests/unit/test-main.lisp — Tests for Hngh core entry point
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

;; --- Version tests ---

(define-test version-returns-string
  (assert-true (stringp (hngh:version)))
  (assert-true (not (string= "" (hngh:version)))))

;; --- Log level tests ---

(define-test log-level-priority
  (assert-true (< (hngh.core:log-level-priority :debug)
                   (hngh.core:log-level-priority :info)))
  (assert-true (< (hngh.core:log-level-priority :info)
                   (hngh.core:log-level-priority :warn)))
  (assert-true (< (hngh.core:log-level-priority :warn)
                   (hngh.core:log-level-priority :error))))

(define-test should-log-p-respects-level
  (let ((hngh.core:*log-level* :info))
    (assert-true (hngh.core:should-log-p :info))
    (assert-true (hngh.core:should-log-p :warn))
    (assert-true (hngh.core:should-log-p :error))
    (assert-true (not (hngh.core:should-log-p :debug))))
  (let ((hngh.core:*log-level* :error))
    (assert-true (not (hngh.core:should-log-p :debug)))
    (assert-true (not (hngh.core:should-log-p :info)))
    (assert-true (not (hngh.core:should-log-p :warn)))
    (assert-true (hngh.core:should-log-p :error))))

(define-test set-log-level-works
  (let ((original hngh.core:*log-level*))
    (hngh.core:set-log-level :debug)
    (assert-equal :debug hngh.core:*log-level*)
    (hngh.core:set-log-level :error)
    (assert-equal :error hngh.core:*log-level*)
    (setf hngh.core:*log-level* original)))

;; --- Config tests ---

(define-test config-merge-overrides-defaults
  (let ((merged (hngh.core.config:merge-config
                  '(:a 1 :b 2 :c 3)
                  '(:b 99))))
    (assert-equal 1 (getf merged :a))
    (assert-equal 99 (getf merged :b))
    (assert-equal 3 (getf merged :c))))

(define-test config-get-with-default
  (let ((hngh.core.config:*config* '(:foo "bar" :num 42)))
    (assert-equal "bar" (hngh.core.config:config-get :foo))
    (assert-equal 42 (hngh.core.config:config-get :num))
    (assert-equal "default" (hngh.core.config:config-get :missing "default"))))

(define-test config-set-and-get
  (let ((hngh.core.config:*config* '()))
    (hngh.core.config:config-set :key "val")
    (assert-equal "val" (hngh.core.config:config-get :key))))

;; --- Start/stop tests ---

(define-test start-sets-running-flag
  (let ((hngh:*running* nil))
    ;; Use a temp directory to avoid touching real ~/.hngh/
    (hngh:start :hngh-home (merge-pathnames "test-hngh-tmp/"
                                             (uiop:temporary-directory)))
    (assert-true hngh:*running*)
    (hngh:stop)
    (assert-true (not hngh:*running*))))

(define-test stop-when-not-running-returns-nil
  (let ((hngh:*running* nil))
    (assert-true (not (hngh:stop)))))

;; --- State tree tests ---

(define-test init-state-tree-creates-directories
  (let ((tmp-home (merge-pathnames "test-state-tree/"
                                    (uiop:temporary-directory))))
    ;; Clean up if exists from previous test
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh:init-state-tree tmp-home)
    (assert-true (probe-file (merge-pathnames "config/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "state/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "journal/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "journal/events/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "journal/hnghbeats/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "knowledge-base/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "plugins/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "agents/" tmp-home)))
    (assert-true (probe-file (merge-pathnames "secrets/" tmp-home)))
    ;; Clean up
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

;; --- Utility tests ---

(define-test keyword-from-string
  (assert-equal :debug (hngh:keyword-from-string "debug"))
  (assert-equal :info (hngh:keyword-from-string "INFO"))
  (assert-equal :error (hngh:keyword-from-string "error")))

(define-test parse-option-finds-flag
  (let ((args '("--hngh-home" "/tmp/hngh" "--version")))
    (assert-equal "/tmp/hngh" (hngh:parse-option args "--hngh-home" #'identity))
    (assert-true (not (hngh:parse-option args "--nonexistent" #'identity)))))
