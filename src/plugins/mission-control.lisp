;;;; plugins/mission-control.lisp — Hngh Mission Control (M6 wave 1)
;;;;
;;;; Tiled tmux observability + agent summoning. Thin wrapper: the `mc`
;;;; shell script (~/.local/bin/mc) is the single source of layout truth;
;;;; this plugin lets hngh start sessions and summon panes for subagents.
;;;;
;;;; Observation surface (live-orchestration L1): extend with `hngh-mc
;;;; observe <squad>` (a pane showing a squad's dispatch tree, beans, signals,
;;;; thought-trace intent, ledger tail) and `observe --all` (squad wall).
;;;; See docs/design/live-orchestration.md.
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
  (multiple-value-bind (code output error)
      (funcall *squad-command-runner* "tmux" (list "has-session" "-t" session))
    (declare (ignore output error))
    (zerop code)))

(defun start-session ()
  "Start the mission-control session (idempotent — mc handles existing)."
  (multiple-value-bind (code output error)
      (funcall *squad-command-runner* (namestring (mc-path)) '("start"))
    (declare (ignore error))
    (values output code)))

(defun stop-session ()
  "Stop the mission-control session."
  (multiple-value-bind (code output error)
      (funcall *squad-command-runner* (namestring (mc-path)) '("stop"))
    (declare (ignore error))
    (values output code)))

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

;;; --- Pane layout persistence ------------------------------------------------

(defparameter *session-layout-relative-path* "state/mc-layout.lisp"
  "State-store-relative path for the mission-control pane layout.")

(defun session-layout-path (&optional (hngh-home hngh:*hngh-home*))
  "Resolve the pane layout state path beneath HNGH-HOME."
  (merge-pathnames *session-layout-relative-path* hngh-home))

(defun split-layout-fields (line)
  "Split a tab-delimited tmux layout LINE without disturbing spaces."
  (loop with start = 0
        for separator = (position #\Tab line :start start)
        collect (subseq line start separator)
        while separator
        do (setf start (1+ separator))))

(defun parse-layout-integer (text field-name)
  "Parse a non-negative integer from TEXT for FIELD-NAME."
  (handler-case
      (let ((value (parse-integer text :junk-allowed nil)))
        (unless (>= value 0)
          (error "Layout ~A must be non-negative: ~S" field-name text))
        value)
    (parse-error ()
      (error "Layout ~A must be an integer: ~S" field-name text))))

(defun parse-layout-pane (line)
  "Parse one tab-delimited tmux pane LINE into the documented plist shape."
  (let ((fields (split-layout-fields line)))
    (unless (= 5 (length fields))
      (error "Layout pane record has ~D fields, expected 5: ~S"
             (length fields) line))
    (destructuring-bind (index width height cwd command) fields
      (list :index (parse-layout-integer index "index")
            :width (parse-layout-integer width "width")
            :height (parse-layout-integer height "height")
            :cwd cwd
            :cmd command))))

(defun plist-has-key-p (plist key)
  "Return T when proper PLIST contains KEY, including a NIL value."
  (loop for tail on plist by #'cddr
        thereis (eq (first tail) key)))

(defun proper-list-p (value)
  "Return T when VALUE is a finite proper list."
  (handler-case
      (progn (length value) (listp value))
    (type-error () nil)))

(defun valid-layout-pane-p (pane)
  "Return T when PANE has safe, structurally usable layout fields."
  (and (proper-list-p pane)
       (= 10 (length pane))
       (every (lambda (key) (plist-has-key-p pane key))
              '(:index :width :height :cwd :cmd))
       (integerp (getf pane :index))
       (>= (getf pane :index) 0)
       (integerp (getf pane :width))
       (> (getf pane :width) 0)
       (integerp (getf pane :height))
       (> (getf pane :height) 0)
       (stringp (getf pane :cwd))
       (> (length (getf pane :cwd)) 0)
       (stringp (getf pane :cmd))
       (> (length (getf pane :cmd)) 0)))

(defun valid-session-layout-p (layout)
  "Return T when LAYOUT matches the documented pane plist contract."
  (and (proper-list-p layout)
       (= 2 (length layout))
       (plist-has-key-p layout :panes)
       (let ((panes (getf layout :panes)))
         (and (proper-list-p panes)
              panes
              (every #'valid-layout-pane-p panes)
              (= (length panes)
                 (length (remove-duplicates
                          (mapcar (lambda (pane) (getf pane :index)) panes))))))))

(defun sorted-layout-panes (layout)
  "Return a fresh pane list sorted by persisted pane index."
  (sort (copy-list (getf layout :panes)) #'< :key (lambda (pane)
                                                    (getf pane :index))))

(defun read-session-layout (&key (hngh-home hngh:*hngh-home*))
  "Safely read and validate the persisted session layout.
Returns two values: layout and one of :VALID, :MISSING, or :MALFORMED."
  (let ((path (session-layout-path hngh-home)))
    (unless (probe-file path)
      (hngh.core:log-warn "Mission-control layout missing at ~A; use tiled fallback"
                          path)
      (return-from read-session-layout (values nil :missing)))
    (handler-case
        (with-open-file (stream path :direction :input)
          (let* ((*read-eval* nil)
                 (eof (gensym "EOF"))
                 (layout (read stream nil eof))
                 (extra (read stream nil eof)))
            (unless (and (not (eq layout eof))
                         (eq extra eof)
                         (valid-session-layout-p layout))
              (error "layout does not match (:panes ((:index ...)))"))
            (values layout :valid)))
      (error (condition)
        (hngh.core:log-warn
         "Mission-control layout malformed at ~A (~A); use tiled fallback"
         path condition)
        (values nil :malformed)))))

(defun layout-list-panes-format ()
  "Return the tmux format used for lossless space-preserving pane fixtures."
  (format nil "#{pane_index}~C#{pane_width}~C#{pane_height}~C#{pane_current_path}~C#{pane_current_command}"
          #\Tab #\Tab #\Tab #\Tab))

(defun run-layout-command (args)
  "Run a tmux layout command through the injectable mission-control runner."
  (multiple-value-bind (code output error)
      (funcall *squad-command-runner* "tmux" args)
    (unless (zerop code)
      (error "Mission-control tmux command failed (~D): ~A" code error))
    (values output error)))

(defun save-session-layout (&key (session *session-name*)
                                 (hngh-home hngh:*hngh-home*))
  "Query SESSION and atomically save its pane layout beneath HNGH-HOME."
  (multiple-value-bind (output ignored)
      (run-layout-command
       (list "list-panes" "-t" (format nil "~A:main" session)
             "-F" (layout-list-panes-format)))
    (declare (ignore ignored))
    (let ((layout
            (list :panes
                  (mapcar #'parse-layout-pane (split-lines output)))))
      (unless (valid-session-layout-p layout)
        (error "tmux returned an unusable mission-control layout"))
      (write-squad-state (session-layout-path hngh-home) layout)
      layout)))

(defun pane-target-from-output (output session pane)
  "Use tmux pane id OUTPUT, falling back to SESSION and persisted PANE index."
  (let ((pane-id (string-trim '(#\Space #\Tab #\Newline #\Return) output)))
    (if (zerop (length pane-id))
        (format nil "~A:main.~D" session (getf pane :index))
        pane-id)))

(defun restore-layout-panes (layout session)
  "Create SESSION panes from validated LAYOUT and request their saved sizes."
  (let* ((panes (sorted-layout-panes layout))
         (first-pane (first panes))
         (targets '())
         (created nil))
    (handler-case
        (progn
          (multiple-value-bind (output ignored)
              (run-layout-command
               (list "new-session" "-d" "-P" "-F" "#{pane_id}"
                     "-s" session "-n" "main"
                     "-c" (getf first-pane :cwd) (getf first-pane :cmd)))
            (declare (ignore ignored))
            (setf created t)
            (push (cons first-pane
                        (pane-target-from-output output session first-pane))
                  targets))
          (dolist (pane (rest panes))
            (let ((orientation (if (< (getf pane :width)
                                      (getf first-pane :width))
                                   "-h"
                                   "-v")))
              (multiple-value-bind (output ignored)
                  (run-layout-command
                   (list "split-window" orientation "-d" "-P" "-F" "#{pane_id}"
                         "-t" (format nil "~A:main" session)
                         "-c" (getf pane :cwd) (getf pane :cmd)))
                (declare (ignore ignored))
                (push (cons pane (pane-target-from-output output session pane))
                      targets))))
          (run-layout-command
           (list "select-layout" "-t" (format nil "~A:main" session) "tiled"))
          (dolist (entry (nreverse targets))
            (run-layout-command
             (list "resize-pane" "-t" (cdr entry)
                   "-x" (write-to-string (getf (car entry) :width))
                   "-y" (write-to-string (getf (car entry) :height)))))
          t)
      (error (condition)
        (when created
          (ignore-errors
            (run-layout-command (list "kill-session" "-t" session))))
        (error condition)))))

(defun restore-session-layout (&key (session *session-name*)
                                    (hngh-home hngh:*hngh-home*))
  "Restore SESSION from validated state without evaluating persisted forms.
Returns true and :RESTORED on success. Missing, malformed, or failed restores
return NIL and an actionable reason so callers can use their tiled fallback."
  (multiple-value-bind (layout status)
      (read-session-layout :hngh-home hngh-home)
    (unless layout
      (return-from restore-session-layout (values nil status)))
    (handler-case
        (progn
          (restore-layout-panes layout session)
          (values t :restored))
      (error (condition)
        (hngh.core:log-warn
         "Mission-control layout restore failed for ~A (~A); use tiled fallback"
         session condition)
        (values nil :restore-failed)))))

(defun layout-geometry-within-tolerance-p (saved actual &optional (tolerance 2))
  "Return T when ACTUAL pane sizes are within TOLERANCE of SAVED by index."
  (and (valid-session-layout-p saved)
       (valid-session-layout-p actual)
       (= (length (getf saved :panes)) (length (getf actual :panes)))
       (every
        (lambda (saved-pane)
          (let ((actual-pane
                  (find (getf saved-pane :index) (getf actual :panes)
                        :key (lambda (pane) (getf pane :index)))))
            (and actual-pane
                 (<= (abs (- (getf saved-pane :width)
                             (getf actual-pane :width)))
                     tolerance)
                 (<= (abs (- (getf saved-pane :height)
                             (getf actual-pane :height)))
                     tolerance))))
        (getf saved :panes))))

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
        :grant-ids nil
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
    ;; Resource gate (C2): fail closed when VRAM is insufficient and no
    ;; fallback exists; breadcrumb the rejection as a fragment (C5).
    (multiple-value-bind (decision reason)
        (hngh.plugins.squad-resources:check-resource-gate
         (getf definition :roles))
      (when (eq decision :reject)
        (hngh.plugins.squad-resources:reject-with-fragment
         name reason (princ-to-string spec) "n/a"
         "free VRAM or lower model tier before relaunching")
        (error "Squad ~A rejected by resource gate: ~A" name reason)))
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
                (getf state :status) :running
                (getf state :grant-ids)
                (hngh.plugins.squad-resources:acquire-squad-grants
                 name (getf definition :roles)))
          (write-squad-state state-path state)
          state)
      (error (condition)
        (let ((message (princ-to-string condition)))
          (when launched
            (ignore-errors
              (run-squad-command "tmux"
                                 (list "kill-session" "-t"
                                       (getf state :session)))))
          (hngh.plugins.squad-resources:release-squad-grants
           (getf state :grant-ids))
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
    (hngh.plugins.squad-resources:release-squad-grants (getf state :grant-ids))
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

;;; --- Session tree -----------------------------------------------------------

(defparameter *session-tree-relative-path* "state/session-tree.lisp"
  "State-store-relative path for the mission-control session tree.")

(defun session-tree-path (&optional (hngh-home hngh:*hngh-home*))
  "Resolve the session tree state path beneath HNGH-HOME."
  (merge-pathnames *session-tree-relative-path* hngh-home))

(defun read-session-tree (&key (hngh-home hngh:*hngh-home*))
  "Read the session tree with reader evaluation disabled. Returns NIL when absent."
  (let ((path (session-tree-path hngh-home)))
    (when (probe-file path)
      (handler-case
          (with-open-file (stream path :direction :input)
            (let* ((*read-eval* nil)
                   (raw (read stream nil nil)))
              (when (and (listp raw) (plist-has-key-p raw :sessions))
                raw)))
        (error () nil)))))

(defun write-session-tree (tree &key (hngh-home hngh:*hngh-home*))
  "Atomically persist TREE as a flat plist under HNGH-HOME."
  (write-squad-state (session-tree-path hngh-home) tree))

(defun register-session (name &key parent (hngh-home hngh:*hngh-home*))
  "Add or update a session entry in the tree. Return the updated tree."
  (let* ((tree (or (read-session-tree :hngh-home hngh-home)
                   (list :sessions nil)))
         (sessions (getf tree :sessions))
         (existing (find name sessions :key (lambda (s) (getf s :name))
                         :test #'string=)))
    (if existing
        (setf (getf existing :parent) parent
              (getf existing :updated-at) (get-universal-time))
        (setf (getf tree :sessions)
              (cons (list :name name
                          :parent parent
                          :created-at (get-universal-time)
                          :updated-at (get-universal-time))
                    sessions)))
    (write-session-tree tree :hngh-home hngh-home)
    tree))

(defun unregister-session (name &key (hngh-home hngh:*hngh-home*))
  "Remove a session from the tree. Return the updated tree."
  (let* ((tree (or (read-session-tree :hngh-home hngh-home)
                   (list :sessions nil)))
         (sessions (getf tree :sessions)))
    (setf (getf tree :sessions)
          (remove name sessions :key (lambda (s) (getf s :name))
                  :test #'string=))
    (write-session-tree tree :hngh-home hngh-home)
    tree))

(defun session-children (name &key (hngh-home hngh:*hngh-home*))
  "Return the list of child session NAME plists from the tree."
  (let ((tree (read-session-tree :hngh-home hngh-home)))
    (when tree
      (remove-if-not (lambda (s)
                       (and (getf s :parent)
                            (string= (getf s :parent) name)))
                     (getf tree :sessions)))))

;;; --- Session restart -------------------------------------------------------

(defun restart-session (&key (session *session-name*)
                              (hngh-home hngh:*hngh-home*))
  "Save layout, stop, start, restore layout, and emit session.restarted."
  (unless (session-alive-p session)
    (error "Session ~A is not running — cannot restart" session))
  (let ((saved (handler-case (save-session-layout :session session
                                                  :hngh-home hngh-home)
                 (error (c)
                   (hngh.core:log-warn
                    "Save layout failed for ~A (~A); restarting without saved state"
                    session c)
                   nil))))
    (stop-session)
    (sleep 0.5)
    (start-session)
    (when saved
      (handler-case
          (restore-session-layout :session session :hngh-home hngh-home)
        (error (c)
          (hngh.core:log-warn
           "Restore layout failed for ~A (~A); using current layout"
           session c))))
    (when hngh.core.event-bus:*event-bus*
      (handler-case
          (hngh.core.event-bus:publish "session.restarted"
                                       (list :session session
                                             :had-layout (not (null saved)))
                                       :source 'mission-control)
        (error ())))
    (values t saved)))

(defun cascade-restart (name &key (hngh-home hngh:*hngh-home*))
  "Restart NAME session, then restart its children in dependency order."
  (let ((children (session-children name :hngh-home hngh-home)))
    (restart-session :session name :hngh-home hngh-home)
    (dolist (child children)
      (handler-case
          (cascade-restart (getf child :name) :hngh-home hngh-home)
        (error (c)
          (hngh.core:log-warn "Cascade restart child ~A failed: ~A"
                              (getf child :name) c))))
    (values t children)))

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
