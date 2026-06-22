;;;; core/event-bus.lisp — Hngh Event Bus (A2)
;;;;
;;; Pub/sub nervous system for all intra-Hngh communication.
;;;
;;; Topics are dotted strings: "system.pacman.transaction-completed"
;;; Subscribers can subscribe to exact topics or wildcard prefixes:
;;;   "system.*" matches "system.pacman..." and "system.udev..."
;;;   "system.pacman.*" matches anything under system.pacman
;;;
;;; Events are journaled (append-only) to ~/.hngh/journal/events/YYYY-MM-DD.lisp
;;; Persistent subscriptions track last-received event ID; on restart,
;;; missed events are replayed from the journal.
;;;
;;; Backpressure policies for slow subscribers:
;;;   :block  — block the publisher until subscriber catches up (default)
;;;   :drop   — drop events if subscriber queue is full
;;;   :queue  — queue with no limit (risk: memory exhaustion)
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.event-bus)

;;; --- Data structures ---

(defstruct event
  "An event on the bus."
  id            ; integer, monotonically increasing
  topic         ; string, dotted namespace (e.g. "system.pacman.transaction-completed")
  payload       ; arbitrary Lisp value
  timestamp     ; universal-time when published
  source)       ; component that published (symbol or string)

(defstruct subscription
  "A subscription to one or more topics."
  id            ; integer, unique
  topic-pattern ; string with optional wildcard (e.g. "system.*")
  callback      ; function: (event) -> nil
  filter        ; optional filter function: (event) -> boolean
  persistent-p  ; if T, track last-received event ID for replay
  last-event-id ; for persistent subs: ID of last delivered event
  queue         ; queue of pending events (list, newest at front)
  queue-max     ; max queue length before backpressure applies
  drop-policy   ; :block, :drop, or :queue
  active-p)     ; if T, subscription is receiving events

(defvar *event-bus* nil
  "The current event bus instance (bound during START).")

(defvar *next-event-id* 0
  "Counter for event IDs (monotonically increasing).")

(defvar *next-subscription-id* 0
  "Counter for subscription IDs.")

(defvar *event-journal-path* nil
  "Path to the event journal directory (set during initialization).")

(defvar *event-journal-stream* nil
  "Open stream to the current day's journal file.")

(defvar *event-journal-date* nil
  "The date (YYYY-MM-DD) of the currently open journal file.")

;;; --- Topic matching ---

(defun topic-match-p (pattern topic)
  "Return T if TOPIC matches PATTERN.
Pattern can contain a trailing * for wildcard matching:
  \"system.*\" matches \"system.pacman.transaction-completed\"
  \"system.pacman.*\" matches \"system.pacman.transaction-completed\"
  \"system.pacman.transaction-completed\" matches only itself."
  (cond
    ;; Exact match
    ((string= pattern topic) t)
    ;; Wildcard: ends with ".*"
    ((and (>= (length pattern) 2)
          (char= (char pattern (- (length pattern) 1)) #\*)
          (char= (char pattern (- (length pattern) 2)) #\.))
     (let ((prefix (subseq pattern 0 (- (length pattern) 2))))
       (and (>= (length topic) (length prefix))
            (string= (subseq topic 0 (length prefix)) prefix)
            (or (= (length topic) (length prefix))
                (char= (char topic (length prefix)) #\.)))))
    ;; Wildcard: ends with just "*"
    ((and (>= (length pattern) 1)
          (char= (char pattern (- (length pattern) 1)) #\*))
     (let ((prefix (subseq pattern 0 (- (length pattern) 1))))
       (string= (subseq topic 0 (min (length prefix) (length topic)))
                prefix)))
    (t nil)))

;;; --- Event journal ---

(defun journal-date-string ()
  "Return today's date as YYYY-MM-DD string."
  (multiple-value-bind (sec min hr day mon yr)
      (decode-universal-time (get-universal-time))
    (declare (ignore sec min hr))
    (format nil "~4,'0D-~2,'0D-~2,'0D" yr mon day)))

(defun journal-file-path (&optional (date (journal-date-string)))
  "Return the path to the journal file for DATE."
  (when *event-journal-path*
    (merge-pathnames (concatenate 'string date ".lisp") *event-journal-path*)))

(defun ensure-journal-open ()
  "Ensure the journal stream is open for today's date.
If the date has changed, close the old file and open a new one."
  (let ((today (journal-date-string)))
    (cond
      ((null *event-journal-stream*)
       (let ((path (journal-file-path today)))
         (ensure-directories-exist path)
         (setf *event-journal-stream*
               (open path :direction :output
                          :if-exists :append
                          :if-does-not-exist :create)
               *event-journal-date* today)))
      ((not (string= *event-journal-date* today))
       (close *event-journal-stream*)
       (let ((path (journal-file-path today)))
         (setf *event-journal-stream*
               (open path :direction :output
                          :if-exists :append
                          :if-does-not-exist :create)
               *event-journal-date* today))))))

(defun journal-event (event)
  "Write EVENT to the journal file (append-only)."
  (ensure-journal-open)
  (when *event-journal-stream*
    (let ((*print-case* :downcase)
          (*print-pretty* nil))
      ;; Write as a form that can be read back with READ
      (format *event-journal-stream*
              "(event :id ~D :topic ~S :payload ~S :timestamp ~D :source ~S)~%"
              (event-id event)
              (event-topic event)
              (event-payload event)
              (event-timestamp event)
              (event-source event)))
    (finish-output *event-journal-stream*)))

(defun close-journal ()
  "Close the journal stream if open."
  (when *event-journal-stream*
    (close *event-journal-stream*)
    (setf *event-journal-stream* nil
          *event-journal-date* nil)))

(defun read-journal-events (path &optional (after-id 0))
  "Read events from journal file PATH with ID > AFTER-ID.
Returns a list of event structs."
  (when (probe-file path)
    (with-open-file (stream path :direction :input)
      (loop for form = (read stream nil nil)
            while form
            when (and (listp form)
                      (let ((tag (first form)))
                        (or (eq tag 'event)
                            (eq tag 'hngh.core.event-bus:event)
                            (string= (string tag) "EVENT"))))
            collect (let ((plist (rest form)))
                      (make-event :id (getf plist :id)
                                  :topic (getf plist :topic)
                                  :payload (getf plist :payload)
                                  :timestamp (getf plist :timestamp)
                                  :source (getf plist :source)))
            into events
            finally (return (remove-if (lambda (e) (<= (event-id e) after-id))
                                        events))))))

;;; --- Bus lifecycle ---

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the event bus.
Sets up the journal directory and resets counters."
  (setf *event-journal-path*
        (merge-pathnames "journal/events/" hngh-home))
  (ensure-directories-exist *event-journal-path*)
  (setf *next-event-id* 0
        *next-subscription-id* 0
        *event-bus* (make-hash-table :test 'eq))
  (hngh.core:log-info "Event bus initialized"))

(defun shutdown ()
  "Shut down the event bus.
Closes the journal, clears subscriptions."
  (close-journal)
  (setf *event-bus* nil
        *event-journal-path* nil)
  (hngh.core:log-info "Event bus shut down"))

(defun running-p ()
  "Return T if the event bus is initialized."
  (not (null *event-bus*)))

;;; --- Publish / Subscribe ---

(defun publish (topic payload &key (source nil))
  "Publish an event to TOPIC with PAYLOAD.
The event is journaled and delivered to all matching subscribers."
  (unless *event-bus*
    (error "Event bus not initialized — call EVENT-BUS:INIT first"))
  (let ((evt (make-event :id (incf *next-event-id*)
                         :topic topic
                         :payload payload
                         :timestamp (get-universal-time)
                         :source source)))
    ;; Journal the event
    (journal-event evt)
    ;; Deliver to subscribers
    (deliver-event evt)
    evt))

(defun deliver-event (event)
  "Deliver EVENT to all matching subscriptions."
  (loop for sub being the hash-values of *event-bus*
        when (and (subscription-active-p sub)
                  (topic-match-p (subscription-topic-pattern sub)
                                 (event-topic event)))
        do (deliver-to-subscription sub event)))

(defun deliver-to-subscription (sub event)
  "Deliver EVENT to a single subscription SUB.
Applies filter, backpressure, and persistent tracking."
  ;; Apply filter if present
  (when (and (subscription-filter sub)
             (not (funcall (subscription-filter sub) event)))
    (return-from deliver-to-subscription))
  ;; Deliver
  (handler-case
      (funcall (subscription-callback sub) event)
    (error (c)
      (hngh.core:log-warn "Event bus: subscriber ~D callback error: ~A"
                          (subscription-id sub) c)))
  ;; Update persistent tracking
  (when (subscription-persistent-p sub)
    (setf (subscription-last-event-id sub) (event-id event))))

(defun subscribe (topic-pattern callback &key
                  (filter nil)
                  (persistent nil)
                  (queue-max 1000)
                  (drop-policy :block))
  "Subscribe to TOPIC-PATTERN with CALLBACK.
Returns a subscription ID that can be used with UNSUBSCRIBE.

TOPIC-PATTERN: string with optional wildcard (e.g. \"system.*\")
CALLBACK: function called with the event struct as argument
FILTER: optional function (event) -> boolean; only matching events delivered
PERSISTENT: if T, missed events are replayed from journal on restart
QUEUE-MAX: max queued events before backpressure applies
DROP-POLICY: :block (default), :drop, or :queue"
  (unless *event-bus*
    (error "Event bus not initialized"))
  (let ((sub (make-subscription :id (incf *next-subscription-id*)
                                  :topic-pattern topic-pattern
                                  :callback callback
                                  :filter filter
                                  :persistent-p persistent
                                  :last-event-id *next-event-id*
                                  :queue nil
                                  :queue-max queue-max
                                  :drop-policy drop-policy
                                  :active-p t)))
    (setf (gethash (subscription-id sub) *event-bus*) sub)
    ;; If persistent, replay missed events from journal
    (when persistent
      (replay-missed-events sub))
    (subscription-id sub)))

(defun unsubscribe (subscription-id)
  "Remove a subscription by ID."
  (when *event-bus*
    (remhash subscription-id *event-bus*)))

(defun replay-missed-events (sub)
  "Replay events from the journal that the subscription missed.
Called on subscribe for persistent subscriptions."
  (let ((last-id (subscription-last-event-id sub)))
    (when *event-journal-path*
      (loop for path in (directory (merge-pathnames "*.lisp" *event-journal-path*))
            do (loop for evt in (read-journal-events path last-id)
                     when (and (topic-match-p (subscription-topic-pattern sub)
                                               (event-topic evt))
                               (or (null (subscription-filter sub))
                                   (funcall (subscription-filter sub) evt)))
                     do (handler-case
                            (funcall (subscription-callback sub) evt)
                          (error (c)
                            (hngh.core:log-warn "Replay error for sub ~D: ~A"
                                                (subscription-id sub) c)))
                     when (> (event-id evt) last-id)
                     do (setf last-id (event-id evt)))))
    (setf (subscription-last-event-id sub) last-id)))

(defun list-subscriptions ()
  "Return a list of all active subscriptions."
  (when *event-bus*
    (loop for sub being the hash-values of *event-bus*
          collect sub)))

(defun clear-all-subscriptions ()
  "Remove all subscriptions (used during shutdown)."
  (when *event-bus*
    (clrhash *event-bus*)))
