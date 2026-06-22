;;;; core/logging.lisp — Hngh logging system
;;;;
;;; Log levels: :debug < :info < :warn < :error
;;; Messages at or above the current *log-level* are printed.
;;; All log output includes an ISO 8601 timestamp.
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core)

(defparameter *log-level* :info
  "Current log level. One of :debug, :info, :warn, :error.
Messages at or above this level are printed.")

(defparameter *log-levels* '(:debug 0 :info 1 :warn 2 :error 3)
  "Numeric ranking of log levels. Higher = more severe.")

(defun log-level-priority (level)
  "Return the numeric priority of LEVEL. Unknown levels default to :info (1)."
  (or (getf *log-levels* level) 1))

(defun should-log-p (level)
  "Return T if messages at LEVEL should be printed (i.e., LEVEL >= *log-level*)."
  (>= (log-level-priority level) (log-level-priority *log-level*)))

(defun timestamp-string ()
  "Return the current time as an ISO 8601 string."
  (multiple-value-bind (sec min hr day mon yr)
      (decode-universal-time (get-universal-time))
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0D"
            yr mon day hr min sec)))

(defun log-message (level format-string &rest args)
  "Print a log message at LEVEL with timestamp, if LEVEL passes the filter."
  (when (should-log-p level)
    (format t "[~A] [~A] ~?~%"
            (string level)
            (timestamp-string)
            format-string
            args)
    (finish-output)))

(defun log-info (format-string &rest args)
  "Log an informational message."
  (apply #'log-message :info format-string args))

(defun log-warn (format-string &rest args)
  "Log a warning message."
  (apply #'log-message :warn format-string args))

(defun log-error (format-string &rest args)
  "Log an error message."
  (apply #'log-message :error format-string args))

(defun log-debug (format-string &rest args)
  "Log a debug message (only when *log-level* is :debug)."
  (apply #'log-message :debug format-string args))

(defun set-log-level (level)
  "Set the current log level to LEVEL."
  (setf *log-level* level)
  (log-debug "Log level set to ~A" level))
