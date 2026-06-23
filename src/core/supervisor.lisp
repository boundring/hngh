;;;; core/supervisor.lisp — Hngh Supervisor (A6)
;;;;
;;; Lifecycle management for all plugins and spawned agents.
;;; Restart policies, health checks, escalation.
;;;
;;; Restart policies:
;;;   :always     — restart on any termination (crash or clean exit)
;;;   :on-failure — restart only on abnormal exit (crash, error)
;;;   :never      — do not restart
;;;
;;; Restart window: track restart count within a time window.
;;; If max-restarts exceeded, escalate (emit event, notify user).
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.supervisor)

(defvar *components* (make-hash-table :test 'equal)
  "Registry of supervised components. Key: component ID (string), value: component-info.")

(defvar *components-lock* (bt:make-lock "hngh-supervisor")
  "Mutex protecting *components*.")

(defstruct component-info
  "Information about a supervised component."
  id              ; string (unique identifier)
  type            ; :plugin or :agent
  restart-policy  ; :always, :on-failure, :never
  health-check    ; function () -> boolean, or nil
  health-interval ; seconds between health checks
  last-health-ok  ; universal-time of last successful health check
  restart-count   ; total restarts
  restart-window-start ; universal-time when current window started
  window-restarts ; restarts within current window
  max-restarts    ; max restarts per window
  window-duration ; seconds — restart window duration
  restart-fn      ; function () -> boolean to restart the component
  status          ; :running, :stopped, :failed, :escalated
  registered-at)  ; universal-time

(defvar *supervisor-running* nil
  "Whether the supervisor is active.")

;;; --- Lifecycle ---

(defun init ()
  "Initialize the supervisor."
  (setf *components* (make-hash-table :test 'equal)
        *supervisor-running* t)
  (hngh.core:log-info "Supervisor initialized"))

(defun shutdown ()
  "Shut down the supervisor.
Does not stop components — just stops monitoring."
  (setf *supervisor-running* nil
        *components* nil)
  (hngh.core:log-info "Supervisor shut down"))

(defun running-p ()
  "Return T if the supervisor is active."
  *supervisor-running*)

;;; --- Registration ---

(defun register (id &key (type :plugin)
                        (restart-policy :on-failure)
                        (health-check nil)
                        (health-interval 60)
                        (restart-fn nil)
                        (max-restarts 5)
                        (window-duration 300))
  "Register a component for supervision.
ID: unique string identifier for this component
TYPE: :plugin or :agent
RESTART-POLICY: :always, :on-failure, or :never
HEALTH-CHECK: optional function () -> boolean (T = healthy)
HEALTH-INTERVAL: seconds between health checks (default 60)
RESTART-FN: function () -> boolean to restart the component (T = success)
MAX-RESTARTS: max restarts within WINDOW-DURATION before escalation
WINDOW-DURATION: restart counting window in seconds (default 300 = 5 min)"
  (bt:with-lock-held (*components-lock*)
    (when (gethash id *components*)
      (hngh.core:log-warn "Component ~A already registered" id)
      (return-from register nil))
    (let ((info (make-component-info
                  :id id
                  :type type
                  :restart-policy restart-policy
                  :health-check health-check
                  :health-interval health-interval
                  :last-health-ok (get-universal-time)
                  :restart-count 0
                  :restart-window-start (get-universal-time)
                  :window-restarts 0
                  :max-restarts max-restarts
                  :window-duration window-duration
                  :restart-fn restart-fn
                  :status :running
                  :registered-at (get-universal-time))))
      (setf (gethash id *components*) info)
      (hngh.core:log-debug "Registered component ~A (policy: ~A)" id restart-policy)
      info)))

(defun unregister (id)
  "Remove a component from supervision."
  (bt:with-lock-held (*components-lock*)
    (when (gethash id *components*)
      (remhash id *components*)
      (hngh.core:log-debug "Unregistered component ~A" id)
      t)))

;;; --- Health checking ---

(defun check-health (id)
  "Run health check for component ID.
Returns T if healthy, NIL if unhealthy.
If no health check is defined, assumes healthy."
  (let ((info (bt:with-lock-held (*components-lock*)
                (gethash id *components*))))
    (unless info
      (return-from check-health nil))
    (cond
      ((null (component-info-health-check info))
       t)
      (t
       (handler-case
           (let ((ok (funcall (component-info-health-check info))))
             (when ok
               (bt:with-lock-held (*components-lock*)
                 (setf (component-info-last-health-ok info) (get-universal-time))))
             ok)
         (error (c)
           (hngh.core:log-warn "Health check error for ~A: ~A" id c)
           nil))))))

(defun check-all-health ()
  "Run health checks for all registered components.
Returns a list of (id healthy-p) pairs."
  (let ((ids nil))
    (bt:with-lock-held (*components-lock*)
      (loop for id being the hash-keys of *components*
            do (push id ids)))
    (loop for id in ids
          collect (list id (check-health id)))))

;;; --- Restart logic ---

(defun report-failure (id &optional (reason nil))
  "Report that component ID has failed.
If restart policy allows, attempts to restart.
If max-restarts exceeded, escalates."
  (let ((info (bt:with-lock-held (*components-lock*)
                (gethash id *components*))))
    (unless info
      (hngh.core:log-warn "Failure reported for unknown component ~A" id)
      (return-from report-failure nil))
    (hngh.core:log-warn "Component ~A failed: ~A" id (or reason "unknown"))
    (when (eq (component-info-restart-policy info) :never)
      (bt:with-lock-held (*components-lock*)
        (setf (component-info-status info) :failed))
      (hngh.core:log-info "Component ~A has :never policy — not restarting" id)
      (return-from report-failure nil))
    (let ((now (get-universal-time)))
      (bt:with-lock-held (*components-lock*)
        (when (> (- now (component-info-restart-window-start info))
                 (component-info-window-duration info))
          (setf (component-info-restart-window-start info) now
                (component-info-window-restarts info) 0))
        (when (>= (component-info-window-restarts info)
                  (component-info-max-restarts info))
          (setf (component-info-status info) :escalated)
          (hngh.core:log-error "Component ~A exceeded max restarts (~D in ~Ds) — escalating"
                               id (component-info-max-restarts info)
                               (component-info-window-duration info))))
      (when (eq (component-info-status info) :escalated)
        (when hngh.core.event-bus:*event-bus*
          (hngh.core.event-bus:publish
            "supervisor.escalated"
            (list :component id :reason reason
                  :restarts (component-info-restart-count info))
            :source 'supervisor))
        (return-from report-failure nil))
      (when (component-info-restart-fn info)
        (bt:with-lock-held (*components-lock*)
          (incf (component-info-restart-count info))
          (incf (component-info-window-restarts info)))
        (hngh.core:log-info "Restarting component ~A (attempt ~D in window)"
                            id (component-info-window-restarts info))
        (handler-case
            (let ((ok (funcall (component-info-restart-fn info))))
              (if ok
                  (progn
                    (bt:with-lock-held (*components-lock*)
                      (setf (component-info-status info) :running))
                    (hngh.core:log-info "Component ~A restarted successfully" id)
                    (when hngh.core.event-bus:*event-bus*
                      (hngh.core.event-bus:publish
                        "supervisor.restarted"
                        (list :component id :reason reason)
                        :source 'supervisor))
                    t)
                  (progn
                    (bt:with-lock-held (*components-lock*)
                      (setf (component-info-status info) :failed))
                    (hngh.core:log-error "Component ~A restart failed" id)
                    nil)))
          (error (c)
            (bt:with-lock-held (*components-lock*)
              (setf (component-info-status info) :failed))
            (hngh.core:log-error "Component ~A restart error: ~A" id c)
            nil))))))

(defun report-success (id)
  "Report that component ID is running normally.
Resets the restart window counter."
  (bt:with-lock-held (*components-lock*)
    (let ((info (gethash id *components*)))
      (when info
        (setf (component-info-status info) :running
              (component-info-window-restarts info) 0)))))

;;; --- Query ---

(defun get-status (id)
  "Return the status of component ID (:running, :stopped, :failed, :escalated)."
  (bt:with-lock-held (*components-lock*)
    (let ((info (gethash id *components*)))
      (when info
        (component-info-status info)))))

(defun list-components ()
  "Return a list of all registered component-info structs."
  (bt:with-lock-held (*components-lock*)
    (loop for info being the hash-values of *components*
          collect info)))

(defun component-count ()
  "Return the number of registered components."
  (bt:with-lock-held (*components-lock*)
    (hash-table-count *components*)))
