;;;; tests/unit/test-dashboard-tui.lisp — Tests for Dashboard TUI (B9)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.dashboard-tui
  :description "Tests for Dashboard TUI (B9)"
  :in :hngh)

(in-suite :hngh.dashboard-tui)

(test tui-init-shutdown-headless
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (is (hngh.plugins.dashboard-tui:running-p))
    (hngh.plugins.dashboard-tui:shutdown)
    (is (not (hngh.plugins.dashboard-tui:running-p)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-status-returns-plist
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (is (listp status))
      (is (getf status :running))
      (is (getf status :headless)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-receives-events
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.core.event-bus:publish "test.tui" "hello")
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (is (> (getf status :events-buffered) 0)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-buffer-capped-at-100
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (dotimes (i 150)
      (hngh.core.event-bus:publish "test.flood" i))
    (let ((status (hngh.plugins.dashboard-tui:status)))
      (is (<= (getf status :events-buffered) 100)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-handle-key-switches-view
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.plugins.dashboard-tui:handle-key #\2)
    (is (equal :events (getf (hngh.plugins.dashboard-tui:status) :view)))
    (hngh.plugins.dashboard-tui:handle-key #\1)
    (is (equal :overview (getf (hngh.plugins.dashboard-tui:status) :view)))
    (hngh.plugins.dashboard-tui:handle-key #\3)
    (is (equal :plugins (getf (hngh.plugins.dashboard-tui:status) :view)))
    (hngh.plugins.dashboard-tui:handle-key #\4)
    (is (equal :watch (getf (hngh.plugins.dashboard-tui:status) :view)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-headless-render-to-string
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless nil)
    (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
      (is (search "Hngh v" output))
      (is (search "Overview" output)))
    (hngh.plugins.dashboard-tui:shutdown)
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))

(test tui-reads-live-watch-state
  (let ((tmp (make-pathname :name "watch-state" :type "txt"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "2026-08-09T18:00:00 cibo status=checked idle_s=4~%")
             (format stream "2026-08-09T18:00:10 cibo status=idle-nudge action=nudge idle_s=16~%")
             (format stream "2026-08-09T18:00:10 seu status=composer-active action=hold~%"))
           (let ((states (hngh.plugins.dashboard-tui:read-watch-state tmp)))
             (is (equal "idle-nudge"
                        (getf (cdr (assoc "cibo" states :test #'string=)) :status)))
             (is (equal "nudge"
                        (getf (cdr (assoc "cibo" states :test #'string=)) :action)))
             (is (= 16
                    (getf (cdr (assoc "cibo" states :test #'string=)) :idle-s)))
             (is (equal "composer-active"
                        (getf (cdr (assoc "seu" states :test #'string=)) :status)))))
      (when (probe-file tmp)
        (delete-file tmp)))))

(test tui-reads-live-watch-outcomes
  (let ((tmp (make-pathname :name "outcomes" :type "jsonl"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "{\"ts\":1,\"seat\":\"cibo\",\"cycle\":\"heartbeat\",\"result\":\"fired\"}~%")
             (format stream "{\"ts\":2,\"seat\":\"cibo\",\"cycle\":\"lanes-scout\",\"result\":\"fired\"}~%"))
           (let ((outcomes (hngh.plugins.dashboard-tui:read-watch-outcomes tmp)))
             (is (= 1 (length outcomes)))
             (is (equal "lanes-scout"
                        (getf (cdr (assoc "cibo" outcomes :test #'string=)) :cycle)))))
      (when (probe-file tmp) (delete-file tmp)))))

(test tui-reads-watcher-steers-from-lanes
  (let ((root (merge-pathnames "watch-lanes/" (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist (merge-pathnames "tandem-cibo/" root))
           (with-open-file (stream (merge-pathnames "tandem-cibo/inbox.md" root)
                                   :direction :output :if-exists :supersede)
             (format stream "old line~%")
             (format stream "STEER 22:00 (hngh-watch) — live~%"))
           (let ((lines (hngh.plugins.dashboard-tui::read-watch-steers root)))
             (is (= 1 (length lines)))
             (is (search "live" (first lines)))))
      (when (probe-file root)
        (uiop:delete-directory-tree root :validate #'identity)))))
(test tui-renders-live-watch-state
  (let ((tmp (make-pathname :name "watch-state-render" :type "txt"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "2026-08-09T18:30:00 cibo status=idle-nudge action=nudge idle_s=18~%"))
           (hngh.core.event-bus:init :hngh-home (make-tmp-home))
           (hngh.plugins.dashboard-tui:init :headless t)
           (hngh.plugins.dashboard-tui:handle-key #\4)
           (let ((hngh.plugins.dashboard-tui::*watch-root*
                   (merge-pathnames "missing-watch-root/"
                                    (uiop:temporary-directory)))
                 (hngh.plugins.dashboard-tui::*legacy-watch-state-path* tmp))
             (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
               (is (search "Live Watch" output))
               (is (search "cibo" output))
               (is (search "idle-nudge" output))))
           (hngh.plugins.dashboard-tui:shutdown)
           (hngh.core.event-bus:shutdown))
      (when (probe-file tmp)
        (delete-file tmp)))))

(test tui-reads-steers-log
  (let ((tmp (make-pathname :name "steers" :type "log"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "2026-08-09T14:34:13 STEER killy -> cibo :: wake~%")
             (format stream "delivery=0~%"))
           (let ((entries (hngh.plugins.dashboard-tui:read-steers-log tmp)))
             (is (= 1 (length entries)))
             (is (search "STEER killy -> cibo" (first entries)))))
      (when (probe-file tmp)
        (delete-file tmp)))))

(test tui-reads-owner-inbox
  (let ((tmp (make-pathname :name "owner-inbox" :type "md"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "DECISION: choose the safe route~%")
             (format stream "CHOICES: A/B~%"))
           (let ((lines (hngh.plugins.dashboard-tui:read-owner-inbox tmp)))
             (is (= 2 (length lines)))
             (is (search "DECISION:" (first lines)))))
      (when (probe-file tmp)
        (delete-file tmp)))))

(test tui-renders-steers-and-owner-inbox
  (let ((steers (make-pathname :name "steers-render" :type "log"
                               :defaults (uiop:temporary-directory)))
        (owner (make-pathname :name "owner-render" :type "md"
                              :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream steers :direction :output :if-exists :supersede)
             (format stream "2026-08-09T14:34:13 STEER killy -> cibo :: wake~%"))
           (with-open-file (stream owner :direction :output :if-exists :supersede)
             (format stream "DECISION: choose the safe route~%"))
           (hngh.core.event-bus:init :hngh-home (make-tmp-home))
           (hngh.plugins.dashboard-tui:init :headless t)
           (let ((hngh.plugins.dashboard-tui::*watch-root*
                   (merge-pathnames "missing-watch-root/"
                                    (uiop:temporary-directory)))
                 (hngh.plugins.dashboard-tui::*steers-log-path* steers)
                 (hngh.plugins.dashboard-tui::*owner-inbox-path* owner))
             (hngh.plugins.dashboard-tui:handle-key #\5)
             (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
               (is (search "Steers" output))
               (is (search "STEER killy -> cibo" output)))
             (hngh.plugins.dashboard-tui:handle-key #\6)
             (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
               (is (search "Owner Inbox" output))
               (is (search "DECISION:" output))))
           (hngh.plugins.dashboard-tui:shutdown)
           (hngh.core.event-bus:shutdown))
      (when (probe-file steers)
        (delete-file steers))
      (when (probe-file owner)
        (delete-file owner)))))
(test tui-reads-seat-registry-status
  (let ((registry (make-pathname :name "seat-names" :type "md"
                                 :defaults (uiop:temporary-directory)))
        (lanes (merge-pathnames "seat-lanes/"
                                (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist lanes)
           (with-open-file (stream registry :direction :output :if-exists :supersede)
             (format stream "- Cibo — ASSIGNED~%")
             (format stream "- Seu — ASSIGNED~%")
             (format stream "- Dhomochevsky — available~%"))
           (let ((cibo (merge-pathnames "tandem-cibo/" lanes))
                 (seu (merge-pathnames "tandem-seu/" lanes)))
             (ensure-directories-exist cibo)
             (ensure-directories-exist seu)
             (with-open-file (stream (merge-pathnames "model-status" cibo)
                                     :direction :output :if-exists :supersede)
               (format stream "requested=gpt provider=openrouter negotiated=gpt status=verified~%"))
             (with-open-file (stream (merge-pathnames "model-error" seu)
                                     :direction :output :if-exists :supersede)
               (format stream "ERROR requested=x negotiated=missing status=paused~%")))
           (let ((seats (hngh.plugins.dashboard-tui:read-seat-status registry lanes)))
             (is (= 2 (length seats)))
             (is (equal "verified"
                        (getf (cdr (assoc "Cibo" seats :test #'string=)) :status)))
             (is (equal "paused"
                        (getf (cdr (assoc "Seu" seats :test #'string=)) :status)))))
      (when (probe-file registry) (delete-file registry))
      (when (probe-file lanes)
        (uiop:delete-directory-tree lanes :validate #'identity)))))

(test tui-renders-seat-window-status
  (let ((registry (make-pathname :name "seat-render" :type "md"
                                 :defaults (uiop:temporary-directory)))
        (lanes (merge-pathnames "seat-render-lanes/"
                                (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist lanes)
           (with-open-file (stream registry :direction :output :if-exists :supersede)
             (format stream "- Cibo — ASSIGNED~%"))
           (let ((lane (merge-pathnames "tandem-cibo/" lanes)))
             (ensure-directories-exist lane)
             (with-open-file (stream (merge-pathnames "model-status" lane)
                                     :direction :output :if-exists :supersede)
               (format stream "requested=gpt provider=openrouter negotiated=gpt status=verified~%")))
           (hngh.core.event-bus:init :hngh-home (make-tmp-home))
           (hngh.plugins.dashboard-tui:init :headless t)
           (let ((hngh.plugins.dashboard-tui::*seat-registry-path* registry)
                 (hngh.plugins.dashboard-tui::*seat-lanes-root* lanes))
             (hngh.plugins.dashboard-tui:handle-key #\7)
             (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
               (is (search "Seats" output))
               (is (search "Cibo" output))
               (is (search "verified" output))))
           (hngh.plugins.dashboard-tui:shutdown)
           (hngh.core.event-bus:shutdown))
      (when (probe-file registry) (delete-file registry))
      (when (probe-file lanes)
        (uiop:delete-directory-tree lanes :validate #'identity)))))

(test tui-reads-claims-register
  (let ((tmp (make-pathname :name "claims" :type "lisp"
                            :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream tmp :direction :output :if-exists :supersede)
             (format stream "CLAIM: card:105 cibo dashboard-tui-build 15:20~%")
             (format stream "CLAIM: doc:durable-records seu design-home 15:20~%")
             (format stream "CLAIM-RELEASE: card:104 seu ride-along-design 17:05~%"))
           (let ((claims (hngh.plugins.dashboard-tui:read-claims-register tmp)))
             (is (= 2 (length claims)))
             (is (search "card:105" (first claims)))
             (is (search "durable-records" (second claims)))
             (is (not (some (lambda (line) (search "card:104" line)) claims)))))
      (when (probe-file tmp) (delete-file tmp)))))

(test tui-renders-claims
  (let ((claims (make-pathname :name "claims-render" :type "lisp"
                               :defaults (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (stream claims :direction :output :if-exists :supersede)
             (format stream "CLAIM: card:105 cibo dashboard-tui-build 15:20~%"))
           (hngh.core.event-bus:init :hngh-home (make-tmp-home))
           (hngh.plugins.dashboard-tui:init :headless t)
           (let ((hngh.plugins.dashboard-tui::*claims-register-path* claims))
             (hngh.plugins.dashboard-tui:handle-key #\8)
             (let ((output (hngh.plugins.dashboard-tui:render-to-string)))
               (is (search "Claims" output))
               (is (search "card:105" output)))))
           (hngh.plugins.dashboard-tui:shutdown)
           (hngh.core.event-bus:shutdown))
      (when (probe-file claims) (delete-file claims))))
(test tui-handle-key-q-stops
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.plugins.dashboard-tui:init :headless t)
    (hngh.plugins.dashboard-tui:handle-key #\q)
    (is (not (hngh.plugins.dashboard-tui:running-p)))
    (hngh.core.event-bus:shutdown)
    (cleanup-tmp-home tmp)))
