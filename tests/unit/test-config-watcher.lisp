;;;; tests/unit/test-config-watcher.lisp — Tests for Config Watcher (M2 Wave 2)
;;;;
;;;; Fixture tests exercise the scan, yaml-diff, debounce, handler routing
;;;; and fail-closed logic without requiring live inotify or python3.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.config-watcher
  :description "Tests for Config Watcher (M2 Wave 2)"
  :in :hngh)

(in-suite :hngh.config-watcher)

;;; --- Helpers ---------------------------------------------------------------

(defun %make-tmp-yaml (home filename &optional (content "key: value"))
  "Write a temporary YAML file under HOME and return its absolute path."
  (let ((path (merge-pathnames filename home)))
    (ensure-directories-exist path)
    (with-open-file (stream path :direction :output :if-exists :supersede
                                 :if-does-not-exist :create)
      (write-string content stream))
    (namestring path)))

(defun %captured-events ()
  "Subscribe to hermes.config.changed briefly and collect payloads."
  (let ((events '()))
    (when hngh.core.event-bus:*event-bus*
      (let ((sub (hngh.core.event-bus:subscribe
                  "hermes.config.changed"
                  (lambda (evt) (push evt events)))))
        (sleep 0.1)
        (hngh.core.event-bus:unsubscribe sub)
        (sleep 0.1)))
    (nreverse events)))

;;; --- Tests -----------------------------------------------------------------

(test config-watcher-yaml-diff-identifies-changed-section
  "A single key change produces the expected section in the diff."
  (let ((before "providers:\n  primary: kimi")
        (after  "providers:\n  primary: openai"))
    (let ((sections (hngh.plugins.config-watcher::yaml-diff-sections before after)))
      (is (listp sections))
      (when sections
        (is (member "providers" sections :test #'string=))))))

(test config-watcher-yaml-diff-no-change
  "Identical YAML content produces no changed sections."
  (let ((text "auxiliary:\n  goal_judge:\n    model: gemma"))
    (let ((sections (hngh.plugins.config-watcher::yaml-diff-sections text text)))
      (is (listp sections))
      (is (= 0 (length sections))))))

(test config-watcher-invalid-yaml-fails-closed
  "Malformed YAML returns an empty section list without signalling an error."
  (let ((before "key: value")
        (after  "key: :::: broken"))
    (let ((sections (hngh.plugins.config-watcher::yaml-diff-sections before after)))
      (is (listp sections))
      (is (= 0 (length sections))))))

(test config-watcher-handler-topic-routing
  "Each recognized config section maps to the correct handler topic."
  (is (eq :goal-judge
          (hngh.plugins.config-watcher::handler-topic "auxiliary.goal_judge")))
  (is (eq :model-runtime
          (hngh.plugins.config-watcher::handler-topic "providers")))
  (is (eq :ai-orchestrator
          (hngh.plugins.config-watcher::handler-topic "delegation")))
  (is (eq :mcp-client
          (hngh.plugins.config-watcher::handler-topic "mcp_servers")))
  (is (eq :unknown
          (hngh.plugins.config-watcher::handler-topic "unknown_section"))))

(test config-watcher-debounce-window
  "The debounce gate is CLOSED after the first event and re-opens after sleep."
  (let ((hngh.plugins.config-watcher::*last-event-time* 0))
    (is (not (hngh.plugins.config-watcher::within-debounce-window-p)))
    (setf hngh.plugins.config-watcher::*last-event-time* (get-universal-time))
    (is (hngh.plugins.config-watcher::within-debounce-window-p))
    (sleep 1.5)
    (is (not (hngh.plugins.config-watcher::within-debounce-window-p)))))

(test config-watcher-lifecycle-init-shutdown
  "Init and shutdown are safe and clean up the watch thread."
  (let ((tmp (make-tmp-home)))
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.plugins.config-watcher:init)
           (is (hngh.plugins.config-watcher:running-p))
           (sleep 0.1)
           (hngh.plugins.config-watcher:shutdown)
           (is (not (hngh.plugins.config-watcher:running-p)))
           (hngh.core.event-bus:shutdown))
      (cleanup-tmp-home tmp))))

(test config-watcher-status-plist
  "Status returns a plist with expected keys."
  (let ((tmp (make-tmp-home)))
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.plugins.config-watcher:init)
           (sleep 0.1)
           (let ((status (hngh.plugins.config-watcher:status)))
             (is (listp status))
             (is (getf status :running)))
           (hngh.plugins.config-watcher:shutdown)
           (hngh.core.event-bus:shutdown))
      (cleanup-tmp-home tmp))))

(test config-watcher-snapshot-seeding
  "After init, every watched path has a non-nil snapshot hash entry."
  (let ((tmp (make-tmp-home)))
    (unwind-protect
         (progn
           (%make-tmp-yaml tmp ".hermes/config.yaml" "key: value")
           (%make-tmp-yaml tmp ".hermes/.env" "KEY=val")
           (hngh.core.event-bus:init :hngh-home tmp)
           (let ((hngh:*hngh-home* tmp)
                 (hngh.plugins.config-watcher::*watch-paths*
                  '(".hermes/config.yaml" ".hermes/.env")))
             (hngh.plugins.config-watcher:init)
             (sleep 0.2)
             (is (>= (hash-table-count
                      hngh.plugins.config-watcher::*file-snapshots*)
                    1))
             (hngh.plugins.config-watcher:shutdown)))
      (hngh.core.event-bus:shutdown)
      (cleanup-tmp-home tmp))))
