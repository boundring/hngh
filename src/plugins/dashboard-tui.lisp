;;;; plugins/dashboard-tui.lisp — Hngh Dashboard TUI (B9)
;;;;
;;; Minimal text-based dashboard using raw ANSI escape codes.
;;; No external TUI library dependency (cl-charms/croatoan) needed.
;;;;
;;; Views:
;;;   Overview — Hngh status, active components, recent events
;;;   Events   — live event feed
;;;   Plugins  — loaded plugins
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.dashboard-tui)

(defvar *running* nil
  "Whether the TUI is active.")

(defvar *current-view* :overview
  "Current view: :overview, :events, :plugins")

(defvar *event-buffer* '()
  "Recent events for the event feed (newest first, max 100).")

(defvar *event-subscription* nil
  "Subscription ID for the wildcard event subscription.")

(defvar *input-thread* nil
  "Background thread reading keyboard input.")

(defvar *headless* nil
  "If T, don't render TUI (for service/SSH mode).")

;;; --- ANSI escape codes ---

(defconstant +ansi-clear+ #.(coerce #( #\Esc #\[ #\2 #\J) 'string))
(defconstant +ansi-home+ #.(coerce #( #\Esc #\[ #\H) 'string))
(defconstant +ansi-clear-line+ #.(coerce #( #\Esc #\[ #\2 #\K) 'string))
(defconstant +ansi-bold+ #.(coerce #( #\Esc #\[ #\1 #\m) 'string))
(defconstant +ansi-dim+ #.(coerce #( #\Esc #\[ #\2 #\m) 'string))
(defconstant +ansi-green+ #.(coerce #( #\Esc #\[ #\3 #\2 #\m) 'string))
(defconstant +ansi-yellow+ #.(coerce #( #\Esc #\[ #\3 #\3 #\m) 'string))
(defconstant +ansi-red+ #.(coerce #( #\Esc #\[ #\3 #\1 #\m) 'string))
(defconstant +ansi-cyan+ #.(coerce #( #\Esc #\[ #\3 #\6 #\m) 'string))
(defconstant +ansi-reset+ #.(coerce #( #\Esc #\[ #\0 #\m) 'string))

(defun ansi (code)
  "Output an ANSI escape code to *standard-output*."
  (write-string code)
  (finish-output))

(defun clear-screen ()
  "Clear the screen and move cursor to home."
  (ansi +ansi-clear+)
  (ansi +ansi-home+))

;;; --- Lifecycle ---

(defun init (&key (headless nil))
  "Initialize the dashboard TUI.
If HEADLESS is T, subscribes to events but doesn't render TUI."
  (setf *running* t
        *current-view* :overview
        *event-buffer* '()
        *headless* headless)
  ;; Subscribe to all events
  (when hngh.core.event-bus:*event-bus*
    (setf *event-subscription*
          (hngh.core.event-bus:subscribe "*"
            (lambda (evt)
              (push evt *event-buffer*)
              (when (> (length *event-buffer*) 100)
                (setf *event-buffer* (subseq *event-buffer* 0 100)))))))
  ;; Start input thread (only in interactive mode)
  (unless headless
    #+sbcl
    (setf *input-thread*
          (sb-thread:make-thread #'input-loop :name "hngh-tui-input")))
  (hngh.core:log-info "Dashboard TUI initialized (~A)"
                       (if headless "headless" "interactive")))

(defun shutdown ()
  "Shut down the TUI."
  (setf *running* nil)
  ;; Unsubscribe from events
  (when *event-subscription*
    (hngh.core.event-bus:unsubscribe *event-subscription*)
    (setf *event-subscription* nil))
  ;; Stop input thread
  #+sbcl
  (when (and *input-thread* (sb-thread:thread-alive-p *input-thread*))
    ;; Thread checks *running* flag and exits
    (sb-thread:join-thread *input-thread* :timeout 2))
  (setf *input-thread* nil)
  ;; Reset terminal
  (unless *headless*
    (ansi +ansi-reset+))
  (hngh.core:log-info "Dashboard TUI shut down"))

(defun running-p ()
  "Return T if the TUI is active."
  *running*)

;;; --- Rendering ---

(defun render ()
  "Render the current view to the terminal."
  (when *headless*
    (return-from render))
  (clear-screen)
  (case *current-view*
    (:overview (render-overview))
    (:events (render-events))
    (:plugins (render-plugins)))
  (render-footer))

(defun render-header (title)
  "Render the header bar."
  (format t "~A~AHngh ~A — ~A~A~%"
          +ansi-bold+ +ansi-cyan+ (hngh:version) title +ansi-reset+)
  (format t "~A~A----------------------------------------~A~%"
          +ansi-dim+ "" +ansi-reset+)
  (format t "~%"))

(defun render-overview ()
  "Render the overview view."
  (render-header "Overview")
  (format t "Status:     ~A~A~A~%"
          (if hngh:*running*
              (concatenate 'string +ansi-green+ "RUNNING" +ansi-reset+)
              (concatenate 'string +ansi-red+ "STOPPED" +ansi-reset+))
          "" "")
  (format t "State dir:  ~A~%" (namestring hngh:*hngh-home*))
  (format t "Log level:   ~A~%" hngh.core:*log-level*)
  (format t "~%")
  (format t "~AComponents:~A~%" +ansi-bold+ +ansi-reset+)
  ;; Event bus
  (format t "  Event Bus:     ~A~%"
          (if (hngh.core.event-bus:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+)))
  ;; State store
  (format t "  State Store:    ~A~%"
          (if (hngh.core.state-store:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+)))
  ;; Supervisor
  (format t "  Supervisor:     ~A (~D components)~%"
          (if (hngh.core.supervisor:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+))
          (hngh.core.supervisor:component-count))
  ;; Scheduler
  (format t "  Scheduler:      ~A (~D schedules)~%"
          (if (hngh.core.scheduler:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+))
          (if (hngh.core.scheduler:running-p)
              (length (hngh.core.scheduler:list-schedules))
              0))
  ;; Plugins
  (format t "  Plugins loaded: ~D~%"
          (length (hngh.core.plugin-host:list-plugins)))
  (format t "~%")
  ;; Recent events (last 5)
  (format t "~ARecent Events:~A~%" +ansi-bold+ +ansi-reset+)
  (let ((events (subseq *event-buffer* 0 (min 5 (length *event-buffer*)))))
    (if events
        (dolist (evt events)
          (format t "  ~A~A~A ~A~%"
                  +ansi-dim+
                  (format-event-time evt)
                  +ansi-reset+
                  (hngh.core.event-bus:event-topic evt)))
        (format t "  ~A(no events)~A~%" +ansi-dim+ +ansi-reset+))))

(defun render-events ()
  "Render the live event feed."
  (render-header "Events")
  (let ((events (subseq *event-buffer* 0 (min 30 (length *event-buffer*)))))
    (if events
        (dolist (evt events)
          (format t "  ~A~A~A ~A~A~A ~S~%"
                  +ansi-dim+ (format-event-time evt) +ansi-reset+
                  +ansi-cyan+ (hngh.core.event-bus:event-topic evt) +ansi-reset+
                  (hngh.core.event-bus:event-payload evt)))
        (format t "  ~A(no events yet)~A~%" +ansi-dim+ +ansi-reset+))))

(defun render-plugins ()
  "Render the loaded plugins view."
  (render-header "Plugins")
  (let ((plugins (hngh.core.plugin-host:list-plugins)))
    (if plugins
        (dolist (info plugins)
          (format t "  ~A~A~A v~A [~A]~%"
                  +ansi-green+
                  (hngh.core.plugin-host:plugin-info-name info)
                  +ansi-reset+
                  (hngh.core.plugin-host:plugin-info-version info)
                  (hngh.core.plugin-host:plugin-info-trust-tier info)))
        (format t "  ~A(no plugins loaded)~A~%" +ansi-dim+ +ansi-reset+))))

(defun render-footer ()
  "Render the footer with navigation hints."
  (format t "~%")
  (format t "~A[1]Overview [2]Events [3]Plugins [q]uit~A~%"
          +ansi-dim+ +ansi-reset+))

(defun format-event-time (evt)
  "Format an event's timestamp as HH:MM:SS."
  (multiple-value-bind (sec min hr)
      (decode-universal-time (hngh.core.event-bus:event-timestamp evt))
    (format nil "~2,'0D:~2,'0D:~2,'0D" hr min sec)))

;;; --- Input handling ---

(defun input-loop ()
  "Background thread that reads keyboard input and dispatches commands."
  (loop while *running* do
        (handler-case
            (let ((char (read-char *standard-input* nil nil)))
              (when char
                (handle-key char)))
          (error (c)
            (when *running*
              (hngh.core:log-debug "TUI input error: ~A" c)
              (sleep 1))))))

(defun handle-key (char)
  "Handle a keyboard input character."
  (case char
    (#\1 (setf *current-view* :overview) (render))
    (#\2 (setf *current-view* :events) (render))
    (#\3 (setf *current-view* :plugins) (render))
    (#\q (setf *running* nil))
    (#\Q (setf *running* nil))))

;;; --- Status ---

(defun status ()
  "Return a plist describing the TUI status."
  (list :running *running*
        :view *current-view*
        :headless *headless*
        :events-buffered (length *event-buffer*)))
