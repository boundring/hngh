;;;; plugins/dbus-bridge.lisp — Hngh dbus Bridge (B13)
;;;;
;;; Translates between Hngh's internal event bus and the systemd
;;; session/system bus. Uses `gdbus monitor` as a subprocess to
;;; watch bus signals, and `gdbus call` to invoke methods.
;;;
;;; This is the M0 minimal implementation — uses CLI tools rather
;;; than a CL dbus library. When Quicklisp + cl-dbus are available,
;;; this can be upgraded to programmatic dbus access.
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.dbus-bridge)

(defvar *monitor-process* nil
  "The gdbus monitor subprocess (SB-IMPL::PROCESS or nil).")

(defvar *monitor-thread* nil
  "Background thread reading monitor output.")

(defvar *running* nil
  "Whether the bridge is active.")

(defvar *subscriptions* '()
  "List of (bus destination) pairs being monitored.")

(defvar *signal-scanner*
  (cl-ppcre:create-scanner "^(/[^:]+):\\s+(\\S+)\\.([^(]+)\\((.*)\\)$")
  "Regex matching gdbus monitor signal lines: /path: interface.member(args)")

;;; --- Lifecycle ---

(defun init (&key (monitor-systemd t))
  "Initialize the dbus bridge.
If MONITOR-SYSTEMD is T, starts watching systemd session bus signals."
  (setf *running* t
        *subscriptions* '())
  (when monitor-systemd
    (start-monitor "org.freedesktop.systemd1"))
  (hngh.core:log-info "dbus bridge initialized"))

(defun shutdown ()
  "Shut down the dbus bridge.
Kills the monitor subprocess and stops the reader thread."
  (setf *running* nil)
  (stop-monitor)
  (hngh.core:log-info "dbus bridge shut down"))

(defun running-p ()
  "Return T if the bridge is active."
  *running*)

;;; --- Monitor subprocess ---

(defun start-monitor (destination)
  "Start a gdbus monitor subprocess for DESTINATION on the session bus.
Returns the process object or nil on failure."
  (unless (find-gdbus)
    (hngh.core:log-warn "gdbus not found — dbus bridge inactive")
    (return-from start-monitor nil))
  (push (cons :session destination) *subscriptions*)
  #+sbcl
  (let ((process (sb-ext:run-program
                   "gdbus"
                   (list "monitor" "--session" "--dest" destination)
                   :output :stream
                   :wait nil
                   :search t)))
    (when process
      (setf *monitor-process* process)
      (setf *monitor-thread*
            (sb-thread:make-thread
              (lambda () (monitor-reader process))
              :name "hngh-dbus-monitor"))
      (hngh.core:log-info "Monitoring dbus: ~A" destination)))
  #-sbcl
  (hngh.core:log-warn "dbus monitor requires SBCL"))

(defun stop-monitor ()
  "Stop the monitor subprocess and reader thread."
  #+sbcl
  (progn
    (when *monitor-process*
      (ignore-errors (sb-ext:process-close *monitor-process*))
      (ignore-errors (sb-ext:process-kill *monitor-process* 15))
      (setf *monitor-process* nil))
    (when (and *monitor-thread* (sb-thread:thread-alive-p *monitor-thread*))
      (sb-thread:join-thread *monitor-thread* :timeout 3))
    (setf *monitor-thread* nil)))

(defun find-gdbus ()
  "Return T if gdbus is available on the system."
  (handler-case
      (let ((proc (sb-ext:run-program "which" '("gdbus") :output :stream :wait t :search t)))
        (and proc (sb-ext:process-exit-code proc) (= 0 (sb-ext:process-exit-code proc))))
    (error () nil)))

(defun monitor-reader (process)
  "Read lines from the gdbus monitor output and translate to events.
Runs in a background thread."
  (let ((stream (sb-ext:process-output process)))
    (loop while *running* do
          (handler-case
              (let ((line (read-line stream nil nil)))
                (when (null line)
                  (return))
                (handle-dbus-signal line))
            (error (c)
              (when *running*
                (hngh.core:log-debug "dbus monitor read error: ~A" c)
                (sleep 1)))))))

;;; --- Signal translation ---

(defun kebab-token (value)
  "Return VALUE lowercased with non-alphanumerics replaced by '-'."
  (let ((text (string-downcase (or value ""))))
    (with-output-to-string (out)
      (loop for ch across text
            do (write-char (if (alphanumericp ch) ch #\-) out)))))

(defun normalize-system-topic (interface member)
  "Return normalized system.* topic for known INTERFACE classes, else NIL."
  (let* ((iface (string-downcase (or interface "")))
         (member-kebab (kebab-token member)))
    (cond
      ((search "systemd1" iface)
       (format nil "system.systemd.~A" member-kebab))
      ((or (search "udev" iface)
           (search "device" iface)
           (search "hotplug" iface))
       (format nil "system.udev.~A" member-kebab))
      ((search "login1" iface)
       (format nil "system.login.~A" member-kebab))
      (t nil))))

(defun handle-dbus-signal (line)
  "Parse a gdbus monitor output line and translate to an internal event.
gdbus monitor output looks like:
  The name :1.42 is owned by org.freedesktop.systemd1
  /org/freedesktop/systemd1: org.freedesktop.systemd1.Manager.JobNew (...)
  /org/freedesktop/systemd1: org.freedesktop.systemd1.Manager.UnitNew (...)"
  (cl-ppcre:register-groups-bind (object-path interface member args)
      (*signal-scanner* line)
    (let* ((topic (format nil "dbus.signal.~A.~A"
                           (cl-ppcre:regex-replace-all "\\." interface "-")
                           member))
           (system-topic (normalize-system-topic interface member)))
      (hngh.core:log-debug "dbus signal: ~A.~A (~A)" interface member args)
      (when hngh.core.event-bus:*event-bus*
        (hngh.core.event-bus:publish
          topic
          (list :object-path object-path
                :interface interface
                :member member
                :args args)
          :source 'dbus-bridge)
        (when system-topic
          (hngh.core.event-bus:publish
           system-topic
           (list :interface interface
                 :member member
                 :args args
                 :source :dbus-bridge)
           :source 'dbus-bridge))))
    t))

;;; --- Method calls ---

(defun call-session-method (destination object-path interface method &rest args)
  "Call a dbus method on the session bus via gdbus call.
Returns the result string or nil on failure."
  (let ((gdbus-args (list "call" "--session"
                          "--dest" destination
                          "--object-path" object-path
                          "--method" (format nil "~A.~A" interface method))))
    (when args
      (setf gdbus-args (append gdbus-args args)))
    #+sbcl
    (handler-case
        (let ((proc (sb-ext:run-program "gdbus" gdbus-args
                                         :output :stream :wait t :search t)))
          (when (and proc (= 0 (sb-ext:process-exit-code proc)))
            (let ((output (read-line (sb-ext:process-output proc) nil "")))
              output)))
      (error (c)
        (hngh.core:log-warn "dbus call failed: ~A" c)
        nil))))

(defun call-system-method (destination object-path interface method &rest args)
  "Call a dbus method on the system bus via gdbus call.
Returns the result string or nil on failure."
  (let ((gdbus-args (list "call" "--system"
                          "--dest" destination
                          "--object-path" object-path
                          "--method" (format nil "~A.~A" interface method))))
    (when args
      (setf gdbus-args (append gdbus-args args)))
    #+sbcl
    (handler-case
        (let ((proc (sb-ext:run-program "gdbus" gdbus-args
                                         :output :stream :wait t :search t)))
          (when (and proc (= 0 (sb-ext:process-exit-code proc)))
            (let ((output (read-line (sb-ext:process-output proc) nil "")))
              output)))
      (error (c)
        (hngh.core:log-warn "dbus system call failed: ~A" c)
        nil))))

;;; --- Status ---

(defun status ()
  "Return a plist describing the bridge status."
  (list :running *running*
        :subscriptions *subscriptions*
        :monitoring (not (null *monitor-process*))))
