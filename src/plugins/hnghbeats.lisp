;;;; plugins/hnghbeats.lisp — Hnghbeats daily condensation (B6)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.hnghbeats)

;;; --- State -----------------------------------------------------------------

(defvar *running* nil
  "Whether the Hnghbeats plugin is active.")

(defvar *events-lock* (bt:make-lock "hngh-hnghbeats-events")
  "Mutex protecting *recent-events*.")

(defvar *recent-events* '()
  "Recently observed events captured from the event bus.")

(defparameter *recent-events-max* 5000
  "Maximum number of in-memory recent events retained for fallback condensation.")

(defvar *event-subscriptions* '()
  "List of event subscription IDs for cleanup on shutdown.")

(defvar *schedule-id* nil
  "Scheduler ID for daily condensation job.")

(defvar *last-beat* nil
  "Most recent condensed beat payload.")

(defvar *last-condensed-date* nil
  "Date string (YYYY-MM-DD) last condensed.")

;;; --- Utilities -------------------------------------------------------------

(defun today-date-string ()
  "Return today's date string as YYYY-MM-DD."
  (multiple-value-bind (sec min hr day mon yr)
      (decode-universal-time (get-universal-time))
    (declare (ignore sec min hr))
    (format nil "~4,'0D-~2,'0D-~2,'0D" yr mon day)))

(defun yesterday-date-string ()
  "Return yesterday's date string as YYYY-MM-DD."
  (date-string-from-time (- (get-universal-time) 86400)))

(defun date-string-from-time (universal-time)
  "Return YYYY-MM-DD for UNIVERSAL-TIME."
  (multiple-value-bind (sec min hr day mon yr)
      (decode-universal-time universal-time)
    (declare (ignore sec min hr))
    (format nil "~4,'0D-~2,'0D-~2,'0D" yr mon day)))

(defun string-prefix-p (prefix string)
  "Return T if STRING starts with PREFIX."
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (string= prefix string :end2 (length prefix))))

(defun string-suffix-p (suffix string)
  "Return T if STRING ends with SUFFIX."
  (and (stringp suffix)
       (stringp string)
       (<= (length suffix) (length string))
       (string= suffix string
                :start2 (- (length string) (length suffix)))))

(defun plist-copy (plist)
  "Return a shallow copy of PLIST."
  (if (listp plist)
      (copy-list plist)
      nil))

(defun normalize-event (event)
  "Normalize EVENT struct to a plist for stable processing."
  (list :id (hngh.core.event-bus:event-id event)
        :topic (hngh.core.event-bus:event-topic event)
        :payload (hngh.core.event-bus:event-payload event)
        :timestamp (hngh.core.event-bus:event-timestamp event)
        :source (hngh.core.event-bus:event-source event)))

(defun event-id< (a b)
  "Deterministic ordering predicate for normalized events."
  (let ((a-ts (or (getf a :timestamp) 0))
        (b-ts (or (getf b :timestamp) 0))
        (a-id (or (getf a :id) 0))
        (b-id (or (getf b :id) 0))
        (a-topic (or (getf a :topic) ""))
        (b-topic (or (getf b :topic) "")))
    (or (< a-ts b-ts)
        (and (= a-ts b-ts)
             (or (< a-id b-id)
                 (and (= a-id b-id)
                      (string< a-topic b-topic)))))))

(defun normalize-agent-activity (topic payload)
  "Normalize agent payload differences across ai-tool-hub and ai-orchestrator."
  (let* ((agent-id (or (getf payload :id)
                       (getf payload :invocation-id)
                       (getf payload :agent-id)))
         (tool (or (getf payload :tool)
                   (getf payload :provider)))
         (status (or (getf payload :status)
                     (cond ((string-suffix-p ".completed" topic) :completed)
                           ((string-suffix-p ".failed" topic) :failed)
                           ((string-suffix-p ".spawned" topic) :spawned)
                           (t :unknown))))
         (cost (or (getf payload :cost)
                   (getf payload :cost-usd)
                   (getf payload :cost-estimate))))
    (list :id agent-id :tool tool :status status :cost cost :topic topic)))

(defun classify-system-change-p (topic)
  "Return T if TOPIC belongs to the system-changes category."
  (or (string-prefix-p "system." topic)
      (string-prefix-p "config." topic)
      (string-prefix-p "resource." topic)
      (string-prefix-p "runtime." topic)
      (string-prefix-p "supervisor." topic)
      (string-prefix-p "dbus.signal." topic)))

(defun classify-package-op-p (topic)
  "Return T if TOPIC belongs to package-ops."
  (string-prefix-p "package." topic))

(defun classify-agent-activity-p (topic)
  "Return T if TOPIC belongs to agent-activity."
  (string-prefix-p "agent." topic))

(defun classify-threat-event-p (topic)
  "Return T if TOPIC belongs to threat-events."
  (string-prefix-p "threat." topic))

(defun classify-user-activity-p (topic)
  "Return T if TOPIC belongs to user-activity."
  (or (string-prefix-p "secret." topic)
      (string-prefix-p "knowledge-base." topic)))

(defun classify-error-p (topic payload)
  "Return T if TOPIC/PAYLOAD indicates an error or failure."
  (or (string-suffix-p ".failed" topic)
      (string-suffix-p ".denied" topic)
      (not (null (getf payload :error)))
      (eq (getf payload :result) :failure)
      (eq (getf payload :status) :failed)
      (eq (getf payload :status) :error)
      (eq (getf payload :reason) :execution-error)))

(defun summarize-topics (events predicate)
  "Return deterministic summary plist for events matching PREDICATE."
  (let ((counts (make-hash-table :test 'equal))
        (matched-count 0))
    (dolist (evt events)
      (let ((topic (or (getf evt :topic) "")))
        (when (funcall predicate topic evt)
          (incf matched-count)
          (incf (gethash topic counts 0)))))
    (let ((pairs (loop for k being the hash-keys of counts
                       using (hash-value v)
                       collect (cons k v))))
      (setf pairs (sort pairs #'string< :key #'car))
      (list :count matched-count :by-topic pairs))))

(defun summarize-costs (events)
  "Return deterministic summary for cost-bearing events."
  (let ((entries '())
        (total 0.0d0))
    (dolist (evt events)
      (let* ((topic (or (getf evt :topic) ""))
             (payload (or (getf evt :payload) '()))
             (cost (or (getf payload :cost)
                       (getf payload :cost-usd)
                       (getf payload :cost-estimate))))
        (when (numberp cost)
          (let ((normalized (normalize-agent-activity topic payload)))
            (push normalized entries)
            (setf total (+ total (coerce cost 'double-float)))))))
    (setf entries
          (sort entries
                (lambda (a b)
                  (let ((a-id (or (getf a :id) 0))
                        (b-id (or (getf b :id) 0))
                        (a-topic (or (getf a :topic) ""))
                        (b-topic (or (getf b :topic) "")))
                    (or (< a-id b-id)
                        (and (= a-id b-id)
                             (string< a-topic b-topic)))))))
    (list :count (length entries)
          :total total
          :entries entries)))

(defun summarize-agent-activity (events)
  "Return deterministic summary for agent-related events with normalized payloads."
  (let ((activities '()))
    (dolist (evt events)
      (let* ((topic (or (getf evt :topic) ""))
             (payload (or (getf evt :payload) '())))
        (when (classify-agent-activity-p topic)
          (push (normalize-agent-activity topic payload) activities))))
    (setf activities
          (sort activities
                (lambda (a b)
                  (let ((a-id (or (getf a :id) 0))
                        (b-id (or (getf b :id) 0))
                        (a-topic (or (getf a :topic) ""))
                        (b-topic (or (getf b :topic) "")))
                    (or (< a-id b-id)
                        (and (= a-id b-id)
                             (string< a-topic b-topic)))))))
    (list :count (length activities)
          :activities activities)))

(defun collect-journal-events-for-date (date)
  "Read all event bus journal events for DATE and return normalized plists."
  (handler-case
      (let ((path (hngh.core.event-bus:journal-file-path date)))
        (if (and path (probe-file path))
            (mapcar #'normalize-event
                    (hngh.core.event-bus:read-journal-events path))
            '()))
    (error (c)
      (hngh.core:log-warn "Hnghbeats could not read journal for ~A: ~A" date c)
      '())))

(defun collect-buffered-events-for-date (date)
  "Return buffered events whose timestamp falls on DATE."
  (bt:with-lock-held (*events-lock*)
    (loop for evt in *recent-events*
          for ts = (getf evt :timestamp)
          when (and (integerp ts)
                    (string= (date-string-from-time ts) date))
          collect (list :id (getf evt :id)
                        :topic (getf evt :topic)
                        :payload (plist-copy (getf evt :payload))
                        :timestamp ts
                        :source (getf evt :source)))))

(defun dedupe-events (events)
  "Deduplicate normalized EVENTS by event ID where available."
  (let ((seen (make-hash-table :test 'equal))
        (result '()))
    (dolist (evt events)
      (let* ((id (getf evt :id))
             (topic (or (getf evt :topic) ""))
             (timestamp (or (getf evt :timestamp) 0))
             (key (if id
                      (list :id id)
                      (list :topic topic :timestamp timestamp :payload (getf evt :payload)))))
        (unless (gethash key seen)
          (setf (gethash key seen) t)
          (push evt result))))
    (nreverse result)))

(defun build-beat (date events)
  "Build a deterministic beat payload for DATE from normalized EVENTS."
  (let* ((sorted-events (sort (copy-list events) #'event-id<))
         (system-changes (summarize-topics
                          sorted-events
                          (lambda (topic evt)
                            (declare (ignore evt))
                            (classify-system-change-p topic))))
         (package-ops (summarize-topics
                       sorted-events
                       (lambda (topic evt)
                         (declare (ignore evt))
                         (classify-package-op-p topic))))
         (agent-activity (summarize-agent-activity sorted-events))
         (costs (summarize-costs sorted-events))
         (threat-events (summarize-topics
                         sorted-events
                         (lambda (topic evt)
                           (declare (ignore evt))
                           (classify-threat-event-p topic))))
         (user-activity (summarize-topics
                         sorted-events
                         (lambda (topic evt)
                           (declare (ignore evt))
                           (classify-user-activity-p topic))))
         (errors (summarize-topics
                  sorted-events
                  (lambda (topic evt)
                    (classify-error-p topic (or (getf evt :payload) '()))))))
    (list :date date
          :event-count (length sorted-events)
          :system-changes system-changes
          :package-ops package-ops
          :agent-activity agent-activity
          :costs costs
          :threat-events threat-events
          :user-activity user-activity
          :errors errors)))

(defun persist-beat (date beat)
  "Persist BEAT for DATE under journal/hnghbeats/YYYY-MM-DD.lisp."
  (hngh.core.state-store:write-state
   (format nil "journal/hnghbeats/~A.lisp" date)
   beat))

(defun emit-beat (beat)
  "Publish hnghbeats.beat event with BEAT payload."
  (when hngh.core.event-bus:*event-bus*
    (hngh.core.event-bus:publish "hnghbeats.beat" beat :source 'hnghbeats)))

(defun capture-event (event)
  "Event bus callback used to capture all live events for fallback condensation."
  (let ((normalized (normalize-event event)))
    (bt:with-lock-held (*events-lock*)
      (push normalized *recent-events*)
      (when (> (length *recent-events*) *recent-events-max*)
        (setf *recent-events* (subseq *recent-events* 0 *recent-events-max*))))))

(defun drop-buffered-events-through-date (date)
  "Drop buffered events whose event date is <= DATE (YYYY-MM-DD)."
  (bt:with-lock-held (*events-lock*)
    (setf *recent-events*
          (loop for evt in *recent-events*
                for ts = (getf evt :timestamp)
                for evt-date = (if (integerp ts)
                                   (date-string-from-time ts)
                                   "9999-12-31")
                unless (string<= evt-date date)
                collect evt))))

;;; --- Public API ------------------------------------------------------------

(defun perform-condensation (&key date)
  "Perform daily beat condensation and persist output.
Always returns a deterministic beat plist, including when no events exist."
  (let* ((target-date (or date (yesterday-date-string)))
         (journal-events (collect-journal-events-for-date target-date))
         (buffered-events (collect-buffered-events-for-date target-date))
         (events (dedupe-events (append journal-events buffered-events)))
         (beat (build-beat target-date events)))
    (persist-beat target-date beat)
    (drop-buffered-events-through-date target-date)
    (setf *last-beat* beat
          *last-condensed-date* target-date)
    (emit-beat beat)
    beat))

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize Hnghbeats plugin: subscribe to events and register daily schedule."
  (declare (ignore hngh-home))
  (when *running*
    (shutdown))
  (setf *event-subscriptions* '()
        *schedule-id* nil
        *last-beat* nil
        *last-condensed-date* nil)
  (bt:with-lock-held (*events-lock*)
    (setf *recent-events* '()))

  (when hngh.core.event-bus:*event-bus*
    (push (hngh.core.event-bus:subscribe "*" #'capture-event)
          *event-subscriptions*))

  (when (hngh.core.scheduler:running-p)
    (setf *schedule-id*
          (hngh.core.scheduler:schedule
           "hnghbeats.daily-condensation"
           '(:interval 86400)
            (list :function #'perform-condensation)
            :source 'hnghbeats)))

  (setf *running* t)

  (hngh.core:log-info "Hnghbeats initialized")
  t)

(defun shutdown ()
  "Shut down Hnghbeats plugin: cancel schedule and unsubscribe from events."
  (when *schedule-id*
    (ignore-errors
      (when (hngh.core.scheduler:running-p)
        (hngh.core.scheduler:cancel *schedule-id*)))
    (setf *schedule-id* nil))

  (dolist (sub-id *event-subscriptions*)
    (ignore-errors
      (when hngh.core.event-bus:*event-bus*
        (hngh.core.event-bus:unsubscribe sub-id))))
  (setf *event-subscriptions* '())

  (setf *running* nil)
  (hngh.core:log-info "Hnghbeats shut down")
  t)

(defun running-p ()
  "Return T if Hnghbeats plugin is active."
  *running*)

(defun status ()
  "Return a status plist for Hnghbeats runtime state."
  (let ((buffered-count
          (bt:with-lock-held (*events-lock*)
            (length *recent-events*))))
    (list :running *running*
          :schedule-id *schedule-id*
          :subscriptions (length *event-subscriptions*)
          :buffered-events buffered-count
          :last-condensed-date *last-condensed-date*
          :last-beat *last-beat*)))
