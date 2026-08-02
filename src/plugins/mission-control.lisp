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

(defvar *squad-command-runner* 'default-squad-command-runner
  "Function used for squad launcher and tmux commands.
The test suite binds this to a deterministic fake runner.")

(defvar *squad-state-rename-function* 'rename-file
  "Function used to publish a completed squad state atomically.
The test suite binds this to inject a publish failure.")

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

;;; --- Declarative squads -----------------------------------------------------

(defun default-squad-command-runner (program args)
  "Run PROGRAM with ARGS. Return (values exit-code stdout stderr)."
  (handler-case
      (let* ((out (make-string-output-stream))
             (err (make-string-output-stream))
             (process (sb-ext:run-program program args :search t :wait t
                                          :output out :error err)))
        (values (sb-ext:process-exit-code process)
                (get-output-stream-string out)
                (get-output-stream-string err)))
    (error (condition)
      (values 127 "" (princ-to-string condition)))))

(defun run-squad-command (program args)
  "Run a squad command or signal an actionable error."
  (multiple-value-bind (code output error)
      (funcall *squad-command-runner* program args)
    (unless (zerop code)
      (error "Squad command failed (~D): ~A" code error))
    (values output error)))

(defun squad-project-root ()
  "Resolve the source/config root used by default squad data and specs."
  (or (let ((configured (uiop:getenv "HNGH_PROJECT_ROOT")))
        (and configured (pathname configured)))
      (ignore-errors (asdf:system-source-directory "hngh"))
      (uiop:getcwd)))

(defun squad-registry-path (&optional path)
  "Resolve the squad registry PATH or the configured local default."
  (or path
      (let ((configured (uiop:getenv "HNGH_SQUADS_FILE")))
        (and configured (pathname configured)))
      (merge-pathnames "data/squads.lisp" (squad-project-root))
      (merge-pathnames "squads.lisp" hngh:*hngh-home*)))

(defun read-squad-registry (&optional path)
  "Read a data-only squad registry with read evaluation disabled."
  (let ((registry-path (squad-registry-path path)))
    (unless (probe-file registry-path)
      (error "Squad registry not found: ~A" registry-path))
    (with-open-file (stream registry-path :direction :input)
      (let ((*read-eval* nil)
            (registry (read stream nil nil)))
        (unless (listp registry)
          (error "Squad registry must contain a list: ~A" registry-path))
        registry))))

(defun local-model-p (model)
  "T when MODEL belongs to an approved local model namespace."
  (and (stringp model)
       (some (lambda (prefix)
               (and (>= (length model) (length prefix))
                    (string= prefix model :end2 (length prefix))))
             '("unsloth/" "unsloth-local/" "ollama/" "llama.cpp/" "local/"))))

(defun validate-squad-definition (definition)
  "Validate and return one squad DEFINITION from the registry."
  (unless (and (listp definition)
               (stringp (getf definition :name))
               (listp (getf definition :roles))
               (getf definition :roles))
    (error "Invalid squad definition: ~S" definition))
  (dolist (role (getf definition :roles))
    (unless (and (listp role)
                 (stringp (getf role :name))
                 (member (getf role :harness) '("hermes" "opencode")
                         :test #'string=)
                 (stringp (getf role :model))
                 (stringp (getf role :cwd))
                 (stringp (getf role :prompt-template))
                 (integerp (getf role :budget-cap-cents))
                 (>= (getf role :budget-cap-cents) 0))
      (error "Invalid squad role: ~S" role)))
  definition)

(defun squad-definition (name &key path)
  "Return validated squad NAME from the registry at PATH."
  (let ((definition (find name (read-squad-registry path)
                          :key (lambda (entry) (getf entry :name))
                          :test #'string-equal)))
    (or (and definition (validate-squad-definition definition))
        (error "Unknown squad: ~A" name))))

(defun squad-launcher-path ()
  "Path to the attended v0 squad launcher."
  (merge-pathnames ".local/bin/squad" (user-homedir-pathname)))

(defun squad-state-path (name hngh-home)
  "Path to Hngh's ownership state for squad NAME."
  (merge-pathnames (format nil "squads/~A.lisp" name) hngh-home))

(defun squad-forward-path (name hngh-home)
  "Path to the latest continuation prompt for squad NAME."
  (merge-pathnames (format nil "squads/~A-forward.md" name) hngh-home))

(defun write-squad-state (path state)
  "Atomically publish STATE to PATH as inspectable Lisp data."
  (ensure-directories-exist path)
  (let* ((directory (make-pathname :name nil :type nil :defaults path))
         (name (or (pathname-name path) "state"))
         (temporary (merge-pathnames
                     (format nil ".~A.~D.tmp" name (random 1000000))
                     directory)))
    (unwind-protect
         (progn
           (with-open-file (stream temporary :direction :output
                                    :if-exists :supersede
                                    :if-does-not-exist :create)
             (let ((*print-readably* t))
               (prin1 state stream)
               (terpri stream)))
           (funcall *squad-state-rename-function* temporary path))
      (when (probe-file temporary)
        (ignore-errors (delete-file temporary))))))

(defun read-squad-state (path)
  "Read ownership state from PATH with read evaluation disabled."
  (unless (probe-file path)
    (error "Squad state not found: ~A" path))
  (with-open-file (stream path :direction :input)
    (let ((*read-eval* nil))
      (read stream nil nil))))

(defun make-squad-state (definition name status spec forward-path)
  "Build inspectable lifecycle state for DEFINITION."
  (list :schema-version 1
        :name name
        :status status
        :ownership :hngh
        :session (format nil "squad-~A" name)
        :spec-path (namestring spec)
        :forward-prompt-path (namestring forward-path)
        :roles (mapcar (lambda (role) (getf role :name))
                       (getf definition :roles))
        :started-at (get-universal-time)))

(defun squad-up (name &key registry-path spec-path
                           (hngh-home hngh:*hngh-home*))
  "Validate NAME, launch SPEC-PATH, and record continuation ownership state.
Remote models are rejected in this local-first slice."
  (let* ((definition (squad-definition name :path registry-path))
         (spec (or spec-path
                   (merge-pathnames (format nil "squads/~A.spec" name)
                                    (squad-project-root))))
         (launcher (squad-launcher-path))
         (state-path (squad-state-path name hngh-home))
         (forward-path (squad-forward-path name hngh-home))
         (state (make-squad-state definition name :starting spec forward-path))
         (launched nil))
    (unless (probe-file spec)
      (error "Squad spec not found: ~A" spec))
    (unless (probe-file launcher)
      (error "Squad launcher not found: ~A" launcher))
    (unless (every (lambda (role) (local-model-p (getf role :model)))
                   (getf definition :roles))
      (error "Remote squad models are disabled; use an explicit approved lane"))
    (when (probe-file state-path)
      (let ((state (read-squad-state state-path)))
        (when (member (getf state :status) '(:starting :running))
          (error "Squad already owns state: ~A" state-path))))
    (write-squad-state state-path state)
    (handler-case
        (progn
          (ensure-directories-exist forward-path)
          (with-open-file (stream forward-path :direction :output
                                  :if-exists :supersede :if-does-not-exist :create)
            (terpri stream))
          (run-squad-command (namestring launcher) (list "up" (namestring spec)))
          (setf launched t
                (getf state :status) :running)
          (write-squad-state state-path state)
          state)
      (error (condition)
        (let ((message (princ-to-string condition)))
          (when launched
            (ignore-errors
              (run-squad-command "tmux"
                                 (list "kill-session" "-t"
                                       (getf state :session)))))
          (setf (getf state :status) :failed
                (getf state :error) message
                (getf state :failed-at) (get-universal-time))
          (handler-case
              (write-squad-state state-path state)
            (error (persist-condition)
              (error "Squad failed and failed-state persistence failed: ~A (original: ~A)"
                     persist-condition message)))
          (error "Squad ~A failed: ~A" name message))))))

(defun squad-down (name &key (hngh-home hngh:*hngh-home*))
  "Stop only a squad session with Hngh ownership state."
  (let* ((state-path (squad-state-path name hngh-home))
         (state (read-squad-state state-path)))
    (unless (and (eq (getf state :ownership) :hngh)
                 (eq (getf state :status) :running))
      (error "Refusing to stop non-running or unowned squad session: ~A" name))
    (run-squad-command "tmux" (list "kill-session" "-t" (getf state :session)))
    (setf (getf state :status) :stopped
          (getf state :stopped-at) (get-universal-time))
    (write-squad-state state-path state)
    state))

(defun split-lines (text)
  "Return non-empty lines from TEXT."
  (with-input-from-string (stream (or text ""))
    (loop for line = (read-line stream nil nil)
          while line
          unless (zerop (length line)) collect line)))

(defun squad-forward-prompt (name prompt &key (hngh-home hngh:*hngh-home*))
  "Persist PROMPT and forward it to every owned squad pane."
  (let* ((state-path (squad-state-path name hngh-home))
         (state (read-squad-state state-path))
         (session (getf state :session))
         (forward-path (pathname (getf state :forward-prompt-path))))
    (unless (and (eq (getf state :ownership) :hngh)
                 (eq (getf state :status) :running))
      (error "Squad is not an active Hngh-owned run: ~A" name))
    (ensure-directories-exist forward-path)
    (with-open-file (stream forward-path :direction :output :if-exists :supersede
                            :if-does-not-exist :create)
      (write-string prompt stream)
      (terpri stream))
    (multiple-value-bind (pane-output ignored)
        (run-squad-command "tmux"
                           (list "list-panes" "-t" (format nil "~A:0" session)
                                 "-F" "#{pane_id}"))
      (declare (ignore ignored))
      (dolist (pane (split-lines pane-output))
        (run-squad-command "tmux" (list "send-keys" "-t" pane "-l" prompt))
        (run-squad-command "tmux" (list "send-keys" "-t" pane "Enter")))
      (setf (getf state :forward-count)
            (1+ (getf state :forward-count 0)))
      (setf (getf state :last-forwarded-at) (get-universal-time))
      (write-squad-state state-path state)
      (values state (length (split-lines pane-output))))))

(defun squad-status (name &key (hngh-home hngh:*hngh-home*))
  "Return persisted squad status plus current tmux liveness."
  (let* ((state-path (squad-state-path name hngh-home))
         (state (read-squad-state state-path)))
    (append state (list :alive (session-alive-p (getf state :session))))))

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
