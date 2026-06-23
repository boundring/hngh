;;;; core/scheduler.lisp — Hngh Scheduler (A5)
;;;
;;; Time-based triggers — timers, intervals, cron-like schedules.
;;; Each schedule fires either an event on the Event Bus or calls
;;; a function directly.
;;;
;;; Schedule types:
;;;   :interval  — fire every N seconds
;;;   :at        — fire at a specific universal-time
;;;   :delayed   — fire once after N seconds from now
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.scheduler)

(defvar *schedules* (make-hash-table :test 'eq)
  "Registry of schedules. Key: schedule ID (integer), value: schedule-info.")

(defvar *schedules-lock* (bt:make-lock "hngh-scheduler")
  "Mutex protecting *schedules* and *next-schedule-id*.")

(defvar *next-schedule-id* 0
  "Counter for schedule IDs.")

(defvar *scheduler-running* nil
  "Whether the scheduler is active.")

(defvar *scheduler-thread* nil
  "Background thread that fires schedules.")

(defstruct schedule-info
  "Information about a scheduled trigger."
  id              ; integer (unique)
  name            ; string (human-readable)
  type            ; :interval, :at, :delayed
  interval        ; seconds (for :interval)
  fire-at         ; universal-time (for :at and :delayed)
  action-type     ; :event or :function
  event-topic     ; string (for :event)
  event-payload   ; value (for :event)
  event-source    ; symbol (for :event)
  function        ; function (for :function)
  next-fire       ; universal-time of next firing
  repeat-p        ; T if this schedule repeats (only :interval)
  active-p        ; T if this schedule is active
  fire-count      ; number of times this schedule has fired
  created-at)     ; universal-time

;;; --- Lifecycle ---

(defun init ()
  "Initialize the scheduler and start the background thread."
  (setf *schedules* (make-hash-table :test 'eq)
        *next-schedule-id* 0
        *scheduler-running* t)
  #+sbcl
  (setf *scheduler-thread*
        (sb-thread:make-thread #'scheduler-loop
                                :name "hngh-scheduler"))
  (hngh.core:log-info "Scheduler initialized"))

(defun shutdown ()
  "Stop the scheduler and cancel all schedules."
  (setf *scheduler-running* nil)
  #+sbcl
  (when (and *scheduler-thread* (sb-thread:thread-alive-p *scheduler-thread*))
    (sb-thread:join-thread *scheduler-thread* :timeout 5))
  (bt:with-lock-held (*schedules-lock*)
    (clrhash *schedules*))
  (setf *scheduler-thread* nil)
  (hngh.core:log-info "Scheduler shut down"))

(defun running-p ()
  "Return T if the scheduler is active."
  *scheduler-running*)

;;; --- Scheduling ---

(defun schedule (name spec action &key (source nil))
  "Schedule a trigger.
NAME: human-readable string name
SPEC: one of:
  (:interval N)         — fire every N seconds
  (:at TIME)            — fire at universal-time TIME
  (:delayed SECONDS)    — fire once after SECONDS from now
ACTION: either:
  (:event TOPIC PAYLOAD) — publish an event on the bus
  (:function FN)         — call FN with no arguments
SOURCE: symbol for event source (default: 'scheduler)
Returns the schedule ID."
  (unless *scheduler-running*
    (error "Scheduler not initialized"))
  (destructuring-bind (spec-type &rest spec-args) spec
    (let* ((id (bt:with-lock-held (*schedules-lock*)
                 (incf *next-schedule-id*)))
           (now (get-universal-time))
           (info (make-schedule-info
                   :id id
                   :name name
                   :type spec-type
                   :interval (case spec-type (:interval (first spec-args)))
                   :fire-at (case spec-type
                              (:at (first spec-args))
                              (:delayed (+ now (first spec-args))))
                   :action-type (if (eq (first action) :event) :event :function)
                   :event-topic (case (first action) (:event (second action)))
                   :event-payload (case (first action) (:event (third action)))
                   :event-source (or source 'scheduler)
                   :function (case (first action) (:function (second action)))
                   :next-fire (case spec-type
                                (:interval (+ now (first spec-args)))
                                (:at (first spec-args))
                                (:delayed (+ now (first spec-args))))
                   :repeat-p (eq spec-type :interval)
                   :active-p t
                   :fire-count 0
                   :created-at now)))
      (bt:with-lock-held (*schedules-lock*)
        (setf (gethash id *schedules*) info))
      (hngh.core:log-debug "Scheduled ~A (type: ~A, next-fire: ~D)" name spec-type
                           (schedule-info-next-fire info))
      id)))

(defun cancel (schedule-id)
  "Cancel a schedule by ID. Returns T if cancelled, NIL if not found."
  (bt:with-lock-held (*schedules-lock*)
    (let ((info (gethash schedule-id *schedules*)))
      (when info
        (setf (schedule-info-active-p info) nil)
        (remhash schedule-id *schedules*)
        (hngh.core:log-debug "Cancelled schedule ~A" (schedule-info-name info))
        t))))

(defun list-schedules ()
  "Return a list of all active schedule-info structs."
  (bt:with-lock-held (*schedules-lock*)
    (loop for info being the hash-values of *schedules*
          when (schedule-info-active-p info)
          collect info)))

;;; --- Scheduler loop ---

(defun scheduler-loop ()
  "Main scheduler loop. Runs in a background thread.
Checks for due schedules every second and fires them."
  (hngh.core:log-debug "Scheduler loop started")
  (loop while *scheduler-running* do
        (handler-case
            (progn
              (check-and-fire)
              (sleep 1))
          (error (c)
            (hngh.core:log-error "Scheduler loop error: ~A" c)
            (sleep 5)))) ; Back off on error
  (hngh.core:log-debug "Scheduler loop stopped"))

(defun check-and-fire ()
  "Check all schedules and fire any that are due."
  (let ((now (get-universal-time))
        (due nil))
    (bt:with-lock-held (*schedules-lock*)
      (loop for info being the hash-values of *schedules*
            when (and (schedule-info-active-p info)
                      (<= (schedule-info-next-fire info) now))
            do (push info due)))
    (dolist (info due)
      (fire-schedule info now))))

(defun fire-schedule (info now)
  "Fire a single schedule. Updates next-fire for repeating schedules."
  (hngh.core:log-debug "Firing schedule ~A" (schedule-info-name info))
  (incf (schedule-info-fire-count info))
  (handler-case
      (case (schedule-info-action-type info)
        (:event
         (when hngh.core.event-bus:*event-bus*
           (hngh.core.event-bus:publish
             (schedule-info-event-topic info)
             (schedule-info-event-payload info)
             :source (schedule-info-event-source info))))
        (:function
         (when (schedule-info-function info)
           (funcall (schedule-info-function info)))))
    (error (c)
      (hngh.core:log-warn "Schedule ~A fire error: ~A"
                          (schedule-info-name info) c)))
  (if (schedule-info-repeat-p info)
      (setf (schedule-info-next-fire info)
            (+ now (schedule-info-interval info)))
      (bt:with-lock-held (*schedules-lock*)
        (setf (schedule-info-active-p info) nil)
        (remhash (schedule-info-id info) *schedules*))))

(defun schedule-count ()
  "Return the number of active schedules."
  (hash-table-count *schedules*))
