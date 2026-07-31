;;;; plugins/mission-control.lisp — Hngh Mission Control (M6 wave 1)
;;;;
;;;; Tiled tmux observability + agent summoning. Thin wrapper: the `mc`
;;;; shell script (~/.local/bin/mc) is the single source of layout truth;
;;;; this plugin lets hngh start sessions and summon panes for subagents.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.mission-control)

(defvar *running* nil)
(defvar *session-name* "hngh-mc"
  "Default tmux session name for mission control.")

(defun mc-path ()
  "Path to the mc launcher script."
  (merge-pathnames ".local/bin/mc" (user-homedir-pathname)))

(defun mc-run (args)
  "Run mc with ARGS (list of strings). Returns (values output exit-code stderr)."
  (handler-case
      (let* ((out-str (make-string-output-stream))
             (err-str (make-string-output-stream))
             (proc (sb-ext:run-program (namestring (mc-path)) args
                                       :output out-str :error err-str
                                       :search nil :wait t)))
        (values (get-output-stream-string out-str)
                (sb-ext:process-exit-code proc)
                (get-output-stream-string err-str)))
    (error (c)
      (values (princ-to-string c) 127 ""))))

(defun session-alive-p (&optional (session *session-name*))
  "T when the mission-control tmux session exists."
  (handler-case
      (let ((proc (sb-ext:run-program "tmux" (list "has-session" "-t" session)
                                      :search t :wait t :output nil :error nil)))
        (zerop (sb-ext:process-exit-code proc)))
    (error () nil)))

(defun start-session ()
  "Start the mission-control session (idempotent — mc handles existing)."
  (mc-run '("start")))

(defun stop-session ()
  "Stop the mission-control session."
  (mc-run '("stop")))

(defun add-pane (command)
  "Add a tiled pane running COMMAND (string) to the session."
  (mc-run (list "add" command)))

(defun summon (target task &key model)
  "Summon a sibling agent (hermes|opencode) in a new mission-control pane.
Uses agent-call; the summon is logged to OptMem automatically."
  (add-pane (format nil "agent-call ~A ~S~@[ ~S~]" target task model)))

(defun panes ()
  "Raw pane listing text (tmux list-panes via mc status)."
  (mc-run '("status")))

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the mission-control plugin."
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Mission control initialized (session: ~A, alive: ~A)"
                      *session-name* (session-alive-p))
  t)

(defun shutdown ()
  "Shut down the mission-control plugin (does not kill the tmux session)."
  (setf *running* nil)
  (hngh.core:log-info "Mission control shut down"))

(defun running-p ()
  "Return T if the mission-control plugin is active."
  *running*)

(defun status ()
  "Return a plist with mission-control status."
  (list :running *running*
        :session *session-name*
        :alive (session-alive-p)))
