;;;; tests/unit/test-event-bus.lisp — Tests for Event Bus (A2)
;;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests.harness)

;; --- Topic matching ---

(define-test topic-match-exact
  (assert-true (hngh.core.event-bus:topic-match-p
                 "system.pacman.transaction-completed"
                 "system.pacman.transaction-completed"))
  (assert-true (not (hngh.core.event-bus:topic-match-p
                      "system.pacman.transaction-completed"
                      "system.pacman.transaction-started"))))

(define-test topic-match-wildcard-dot-star
  (assert-true (hngh.core.event-bus:topic-match-p "system.*" "system.pacman.hook"))
  (assert-true (hngh.core.event-bus:topic-match-p "system.*" "system.udev.device-changed"))
  (assert-true (not (hngh.core.event-bus:topic-match-p "system.*" "plugin.loaded"))))

(define-test topic-match-wildcard-nested
  (assert-true (hngh.core.event-bus:topic-match-p
                 "system.pacman.*" "system.pacman.transaction-completed"))
  (assert-true (not (hngh.core.event-bus:topic-match-p
                      "system.pacman.*" "system.udev.device-changed"))))

(define-test topic-match-bare-star
  (assert-true (hngh.core.event-bus:topic-match-p "*" "anything.at.all"))
  (assert-true (hngh.core.event-bus:topic-match-p "*" "system.pacman")))

;; --- Bus lifecycle ---

(define-test init-creates-bus
  (let ((tmp-home (merge-pathnames "test-ebus-init/"
                                    (uiop:temporary-directory))))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh.core.event-bus:init :hngh-home tmp-home)
    (assert-true (hngh.core.event-bus:running-p))
    (hngh.core.event-bus:shutdown)
    (assert-true (not (hngh.core.event-bus:running-p)))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

;; --- Publish / Subscribe ---

(define-test publish-delivers-to-subscriber
  (let ((tmp-home (merge-pathnames "test-ebus-pubsub/"
                                    (uiop:temporary-directory)))
        (received nil))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh.core.event-bus:init :hngh-home tmp-home)
    (hngh.core.event-bus:subscribe "test.topic"
                                    (lambda (evt)
                                      (push (hngh.core.event-bus:event-payload evt)
                                            received)))
    (hngh.core.event-bus:publish "test.topic" "hello")
    (assert-equal "hello" (first received))
    (hngh.core.event-bus:shutdown)
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

(define-test wildcard-subscription-receives-nested
  (let ((tmp-home (merge-pathnames "test-ebus-wild/"
                                    (uiop:temporary-directory)))
        (received nil))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh.core.event-bus:init :hngh-home tmp-home)
    (hngh.core.event-bus:subscribe "test.*"
                                    (lambda (evt)
                                      (push (hngh.core.event-bus:event-topic evt)
                                            received)))
    (hngh.core.event-bus:publish "test.foo" 1)
    (hngh.core.event-bus:publish "test.bar.baz" 2)
    (hngh.core.event-bus:publish "other.topic" 3)  ; should NOT be received
    (assert-equal 2 (length received))
    (assert-true (member "test.bar.baz" received :test #'string=))
    (assert-true (member "test.foo" received :test #'string=))
    (hngh.core.event-bus:shutdown)
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

(define-test unsubscribe-stops-delivery
  (let ((tmp-home (merge-pathnames "test-ebus-unsub/"
                                    (uiop:temporary-directory)))
        (received nil))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh.core.event-bus:init :hngh-home tmp-home)
    (let ((sub-id (hngh.core.event-bus:subscribe
                    "test.topic"
                    (lambda (evt)
                      (push (hngh.core.event-bus:event-payload evt) received)))))
      (hngh.core.event-bus:publish "test.topic" "first")
      (hngh.core.event-bus:unsubscribe sub-id)
      (hngh.core.event-bus:publish "test.topic" "second"))
    (assert-equal 1 (length received))
    (assert-equal "first" (first received))
    (hngh.core.event-bus:shutdown)
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

(define-test filter-only-delivers-matching
  (let ((tmp-home (merge-pathnames "test-ebus-filter/"
                                    (uiop:temporary-directory)))
        (received nil))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh.core.event-bus:init :hngh-home tmp-home)
    (hngh.core.event-bus:subscribe "test.*"
                                    (lambda (evt)
                                      (push (hngh.core.event-bus:event-payload evt)
                                            received))
                                    :filter (lambda (evt)
                                              (> (hngh.core.event-bus:event-payload evt) 5)))
    (hngh.core.event-bus:publish "test.num" 3)
    (hngh.core.event-bus:publish "test.num" 10)
    (hngh.core.event-bus:publish "test.num" 7)
    (assert-equal 2 (length received))
    (assert-true (member 10 received))
    (assert-true (member 7 received))
    (hngh.core.event-bus:shutdown)
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

;; --- Event journaling ---

(define-test publish-journals-event
  (let ((tmp-home (merge-pathnames "test-ebus-journal/"
                                    (uiop:temporary-directory))))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh.core.event-bus:init :hngh-home tmp-home)
    (hngh.core.event-bus:publish "test.topic" "journaled" :source 'test)
    (hngh.core.event-bus:shutdown)
    ;; Check journal file exists and contains the event
    (let ((journal-dir (merge-pathnames "journal/events/" tmp-home)))
      (assert-true (probe-file journal-dir))
      (let ((files (directory (merge-pathnames "*.lisp" journal-dir))))
        (assert-true (= 1 (length files)))
        (let ((events (hngh.core.event-bus:read-journal-events (first files))))
          (assert-true (= 1 (length events)))
          (assert-equal "test.topic" (hngh.core.event-bus:event-topic (first events)))
          (assert-equal "journaled" (hngh.core.event-bus:event-payload (first events))))))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))

(define-test event-ids-increment
  (let ((tmp-home (merge-pathnames "test-ebus-ids/"
                                    (uiop:temporary-directory))))
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))
    (hngh.core.event-bus:init :hngh-home tmp-home)
    (let ((e1 (hngh.core.event-bus:publish "test" 1))
          (e2 (hngh.core.event-bus:publish "test" 2))
          (e3 (hngh.core.event-bus:publish "test" 3)))
      (assert-true (< (hngh.core.event-bus:event-id e1)
                      (hngh.core.event-bus:event-id e2)))
      (assert-true (< (hngh.core.event-bus:event-id e2)
                      (hngh.core.event-bus:event-id e3))))
    (hngh.core.event-bus:shutdown)
    (when (probe-file tmp-home)
      (uiop:delete-directory-tree tmp-home :validate #'identity))))
