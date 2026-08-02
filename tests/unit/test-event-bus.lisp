;;;; tests/unit/test-event-bus.lisp — Tests for Event Bus (A2)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.event-bus
  :description "Tests for Event Bus (A2)"
  :in :hngh)

(in-suite :hngh.event-bus)

(test topic-match-exact
  (is (hngh.core.event-bus:topic-match-p
       "system.pacman.transaction-completed"
       "system.pacman.transaction-completed"))
  (is (not (hngh.core.event-bus:topic-match-p
            "system.pacman.transaction-completed"
            "system.pacman.transaction-started"))))

(test topic-match-wildcard-dot-star
  (is (hngh.core.event-bus:topic-match-p "system.*" "system.pacman.hook"))
  (is (hngh.core.event-bus:topic-match-p "system.*" "system.udev.device-changed"))
  (is (not (hngh.core.event-bus:topic-match-p "system.*" "plugin.loaded"))))

(test topic-match-wildcard-nested
  (is (hngh.core.event-bus:topic-match-p
       "system.pacman.*" "system.pacman.transaction-completed"))
  (is (not (hngh.core.event-bus:topic-match-p
            "system.pacman.*" "system.udev.device-changed"))))

(test topic-match-bare-star
  (is (hngh.core.event-bus:topic-match-p "*" "anything.at.all"))
  (is (hngh.core.event-bus:topic-match-p "*" "system.pacman")))

(test topic-match-keyword-topic
  "Keyword topics emitted by plugins match string subscriptions."
  (is (hngh.core.event-bus:topic-match-p "*" :task-completed))
  (is (hngh.core.event-bus:topic-match-p "task-completed" :task-completed)))

(test init-creates-bus
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (is (hngh.core.event-bus:running-p))
    (hngh.core.event-bus:shutdown)
    (is (not (hngh.core.event-bus:running-p)))
    (cleanup-tmp-home tmp)))

(test publish-delivers-to-subscriber
  (let ((tmp (make-tmp-home))
        (received nil))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.event-bus:subscribe "test.topic"
        (lambda (evt)
          (push (hngh.core.event-bus:event-payload evt) received)))
    (hngh.core.event-bus:publish "test.topic" "hello")
    (is (equal "hello" (first received)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test wildcard-subscription-receives-nested
  (let ((tmp (make-tmp-home))
        (received nil))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.event-bus:subscribe "test.*"
        (lambda (evt)
          (push (hngh.core.event-bus:event-topic evt) received)))
    (hngh.core.event-bus:publish "test.foo" 1)
    (hngh.core.event-bus:publish "test.bar.baz" 2)
    (hngh.core.event-bus:publish "other.topic" 3)
    (is (equal 2 (length received)))
    (is (member "test.bar.baz" received :test #'string=))
    (is (member "test.foo" received :test #'string=))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test unsubscribe-stops-delivery
  (let ((tmp (make-tmp-home))
        (received nil))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (let ((sub-id (hngh.core.event-bus:subscribe
                    "test.topic"
                    (lambda (evt)
                      (push (hngh.core.event-bus:event-payload evt) received)))))
      (hngh.core.event-bus:publish "test.topic" "first")
      (hngh.core.event-bus:unsubscribe sub-id)
      (hngh.core.event-bus:publish "test.topic" "second"))
    (is (equal 1 (length received)))
    (is (equal "first" (first received)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test filter-only-delivers-matching
  (let ((tmp (make-tmp-home))
        (received nil))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.event-bus:subscribe "test.*"
        (lambda (evt)
          (push (hngh.core.event-bus:event-payload evt) received))
        :filter (lambda (evt)
                  (> (hngh.core.event-bus:event-payload evt) 5)))
    (hngh.core.event-bus:publish "test.num" 3)
    (hngh.core.event-bus:publish "test.num" 10)
    (hngh.core.event-bus:publish "test.num" 7)
    (is (equal 2 (length received)))
    (is (member 10 received))
    (is (member 7 received))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test publish-journals-event
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.event-bus:publish "test.topic" "journaled" :source 'test)
    (hngh.core.event-bus:shutdown)
    (let* ((journal-dir (merge-pathnames "journal/events/" tmp))
           (files (directory (merge-pathnames "*.lisp" journal-dir))))
      (is (probe-file journal-dir))
      (is (= 1 (length files)))
      (when files
        (let ((events (hngh.core.event-bus:read-journal-events (first files))))
          (is (= 1 (length events)))
          (is (equal "test.topic" (hngh.core.event-bus:event-topic (first events))))
          (is (equal "journaled" (hngh.core.event-bus:event-payload (first events)))))))
    (cleanup-tmp-home tmp)))

(test event-ids-increment
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (let ((e1 (hngh.core.event-bus:publish "test" 1))
          (e2 (hngh.core.event-bus:publish "test" 2))
          (e3 (hngh.core.event-bus:publish "test" 3)))
      (is (< (hngh.core.event-bus:event-id e1)
             (hngh.core.event-bus:event-id e2)))
      (is (< (hngh.core.event-bus:event-id e2)
             (hngh.core.event-bus:event-id e3))))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))
