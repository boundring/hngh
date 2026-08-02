;;;; plugins/ai-orchestrator.lisp — Hngh AI Orchestrator (B3)
;;;;
;;;; Coordinator, context packages, inter-tool handoffs.
;;;; Delegates tasks to the best available AI tool (agentic CLI, local model
;;;; runtime, or direct API), manages agent lifecycle, and assembles rich
;;;; context packages from the system state, event history, and user activity.
;;;;
;;;; Dependencies: AI Tool Hub (B11), Model Runtime Manager (B4),
;;;;               Resource Manager (A4), Event Bus (A2), State Store (A3).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.ai-orchestrator)

;;; --- Data structures ------------------------------------------------------

(defstruct agent-info
  "Metadata for a single AI agent invocation.
Tracked across its entire lifecycle: pending → running → completed/failed/killed.
Transcripts are persisted to agents/<id>/transcript.lisp via the state store."
  (id 0 :type integer)
  (tool nil :type (or null keyword))
  (task "" :type string)
  (status :pending :type keyword)
  (cost 0.0 :type number)
  (started-at 0 :type integer)
  (backend-id nil :type (or null integer))
  (context nil :type list)
  (result nil :type (or null string))
  (transcript-path nil :type (or null string)))

(defstruct delegate-policy
  "Policy rules that guide agent delegation decisions.
Used by the orchestrator to select the most appropriate tool
for a given task based on cost, latency, and privacy constraints."
  (prefer-tool nil :type (or null keyword))
  (prefer-tier :any :type keyword)
  (max-cost nil :type (or null number))
  (max-latency nil :type (or null integer))
  (privacy :any :type keyword)
  (model nil :type (or null string)))

;;; --- Internal state -------------------------------------------------------

(defvar *running* nil
  "Whether the AI orchestrator plugin is active.")

(defvar *agents* (make-hash-table :test 'eql)
  "Map of agent ID → agent-info struct. Thread-safe via *agents-lock*.")

(defvar *agents-lock* (bt:make-lock "hngh-aio-agents")
  "Mutex protecting *agents* and *next-agent-id*.")

(defvar *next-agent-id* 0
  "Counter for monotonically increasing agent IDs. Protected by *agents-lock*.")

(defvar *policies* (make-hash-table :test 'eq)
  "Map of policy keyword → delegate-policy struct. Thread-safe.
Key :default holds the fallback policy used when no specific policy is specified.")

(defvar *policies-lock* (bt:make-lock "hngh-aio-policies")
  "Mutex protecting *policies*.")

(defvar *event-subscriptions* '()
  "List of event subscription IDs for cleanup on shutdown.")

(defvar *policy-state-path* "config/plugins/ai-orchestrator/policies.lisp"
  "Relative path within the state store for persisting policies.")

;;; --- H-A3: Pause/Resume dispatch state -------------------------------------
;;;
;;; The dispatch pause is an in-memory flag (not persisted) because it is a
;;; runtime control: if the image restarts, the driver starts unpaused.
;;; The optional resume_at is a universal-time timestamp; when set, the tick
;;; auto-resumes once `now >= resume_at`.

(defvar *dispatch-paused* nil
  "When T, task-driver-tick does not dispatch new work.
Cleared by resume-dispatch or auto-resume when resume_at has passed.")

(defvar *dispatch-resume-at* nil
  "Universal-time timestamp at which the pause auto-clears, or NIL for
an indefinite pause (manual resume only).")

(defvar *dispatch-lock* (bt:make-lock "hngh-dispatch-pause")
  "Mutex protecting *dispatch-paused* and *dispatch-resume-at*.")

;;; --- Default policy -------------------------------------------------------

(defparameter *default-policy*
  (make-delegate-policy :prefer-tier :any :privacy :any)
  "Default delegation policy used as a fallback.
Can be overridden by per-call preferences or named policies in *policies*.")

;;; --- Dependency readiness helpers -----------------------------------------

(defun state-store-ready-p ()
  "Return T if the state store is initialized and ready for read/write."
  (let ((home-sym (find-symbol "*HNGH-HOME*" :hngh.core.state-store)))
    (and home-sym (boundp home-sym) (symbol-value home-sym))))

(defun event-bus-ready-p ()
  "Return T if the event bus is initialized."
  (and (boundp 'hngh.core.event-bus:*event-bus*)
       hngh.core.event-bus:*event-bus*))

(defun tool-hub-running-p ()
  "Return T if AI Tool Hub is initialized and running."
  (and (find-package :hngh.plugins.ai-tool-hub)
       (let ((sym (find-symbol "RUNNING-P" :hngh.plugins.ai-tool-hub)))
         (and sym (fboundp sym) (funcall sym)))))

(defun model-runtime-running-p ()
  "Return T if Model Runtime Manager is initialized and running."
  (and (find-package :hngh.plugins.model-runtime)
       (let ((sym (find-symbol "RUNNING-P" :hngh.plugins.model-runtime)))
         (and sym (fboundp sym) (funcall sym)))))

(defun resource-manager-running-p ()
  "Return T if Resource Manager is initialized and running."
  (and (find-package :hngh.core.resource-manager)
       (let ((sym (find-symbol "RUNNING-P" :hngh.core.resource-manager)))
         (and sym (fboundp sym) (funcall sym)))))

(defun tool-hub-fbound-p (name)
  "Return T if the named function is fbound in the AI Tool Hub package."
  (and (find-package :hngh.plugins.ai-tool-hub)
       (let ((sym (find-symbol name :hngh.plugins.ai-tool-hub)))
         (and sym (fboundp sym)))))

(defun model-runtime-fbound-p (name)
  "Return T if the named function is fbound in the Model Runtime package."
  (and (find-package :hngh.plugins.model-runtime)
       (let ((sym (find-symbol name :hngh.plugins.model-runtime)))
         (and sym (fboundp sym)))))

;;; --- Policy utilities -----------------------------------------------------

(defun default-policy ()
  "Return the currently active default policy from *policies*.
If no default is stored, returns the hardcoded *default-policy*."
  (bt:with-lock-held (*policies-lock*)
    (or (gethash :default *policies*) *default-policy*)))

(defun get-policy (name)
  "Retrieve a named policy from *policies* by keyword NAME.
Returns the delegate-policy struct if found, NIL otherwise."
  (when name
    (bt:with-lock-held (*policies-lock*)
      (gethash name *policies*))))

(defun set-policy (name policy)
  "Store a named POLICY under keyword NAME in *policies*."
  (bt:with-lock-held (*policies-lock*)
    (setf (gethash name *policies*) policy))
  (handler-case (persist-policies)
    (error (c) (hngh.core:log-warn "Failed to persist policies: ~A" c)))
  policy)

(defun policy-from-plist (plist)
  "Convert a plist to a delegate-policy struct."
  (make-delegate-policy
   :prefer-tool (getf plist :prefer-tool nil)
   :prefer-tier (getf plist :prefer-tier :any)
   :max-cost (getf plist :max-cost nil)
   :max-latency (getf plist :max-latency nil)
   :privacy (getf plist :privacy :any)
   :model (getf plist :model nil)))

(defun ensure-policy (preferences)
  "Normalize PREFERENCES into a delegate-policy struct."
  (cond ((null preferences) (default-policy))
        ((delegate-policy-p preferences) preferences)
        ((listp preferences) (policy-from-plist preferences))
        (t (default-policy))))

;;; --- Persistence ----------------------------------------------------------

(defun persist-policies ()
  "Write *policies* to the state store as an alist."
  (when (state-store-ready-p)
    (let ((alist (bt:with-lock-held (*policies-lock*)
                   (loop for key being the hash-keys of *policies*
                           using (hash-value policy)
                         collect (cons key
                                       (list :prefer-tool (delegate-policy-prefer-tool policy)
                                             :prefer-tier (delegate-policy-prefer-tier policy)
                                             :max-cost (delegate-policy-max-cost policy)
                                             :max-latency (delegate-policy-max-latency policy)
                                             :privacy (delegate-policy-privacy policy)
                                             :model (delegate-policy-model policy)))))))
      (hngh.core.state-store:write-state *policy-state-path* alist))))

(defun load-policies ()
  "Load policies from the state store. Merges with *default-policy*."
  (when (state-store-ready-p)
    (handler-case
        (let ((alist (hngh.core.state-store:read-state *policy-state-path*)))
          (when (listp alist)
            (bt:with-lock-held (*policies-lock*)
              (dolist (entry alist)
                (when (consp entry)
                  (setf (gethash (car entry) *policies*)
                        (policy-from-plist (cdr entry))))))
            (hngh.core:log-info "Loaded ~D policies from state store" (length alist))))
      (error (c)
        (hngh.core:log-warn "Could not load policies: ~A" c)))))

;;; --- Agent management -----------------------------------------------------

(defun next-agent-id ()
  "Allocate and return the next agent ID (thread-safe)."
  (bt:with-lock-held (*agents-lock*)
    (incf *next-agent-id*)))

(defun register-agent (info)
  "Register an agent-info struct in *agents*."
  (bt:with-lock-held (*agents-lock*)
    (setf (gethash (agent-info-id info) *agents*) info))
  info)

(defun find-agent (id)
  "Find an agent-info by ID. Returns NIL if not found."
  (bt:with-lock-held (*agents-lock*)
    (gethash id *agents*)))

(defun update-agent (id &rest updates)
  "Update fields of agent ID with UPDATES (keyword→value plist).
Returns the updated agent-info or NIL if not found."
  (bt:with-lock-held (*agents-lock*)
    (let ((agent (gethash id *agents*)))
      (when agent
        (loop for (key val) on updates by #'cddr
              do (case key
                   (:status (setf (agent-info-status agent) val))
                   (:cost (setf (agent-info-cost agent) val))
                    (:backend-id (setf (agent-info-backend-id agent) val))
                   (:result (setf (agent-info-result agent) val))
                   (:transcript-path (setf (agent-info-transcript-path agent) val))
                   (:tool (setf (agent-info-tool agent) val))
                   (t (hngh.core:log-debug "Unknown agent update key: ~A" key))))
        agent))))

(defun find-agent-by-backend-id (backend-id)
  "Find an agent-info by backend invocation/runtime ID. Returns NIL if not found."
  (when backend-id
    (bt:with-lock-held (*agents-lock*)
      (loop for agent being the hash-values of *agents*
            when (eql (agent-info-backend-id agent) backend-id)
            do (return agent)))))

(defun remove-agent (id)
  "Remove agent ID from *agents*. Returns the removed agent-info or NIL."
  (bt:with-lock-held (*agents-lock*)
    (let ((agent (gethash id *agents*)))
      (when agent (remhash id *agents*))
      agent)))

;;; --- Event emission -------------------------------------------------------

(defun emit-agent-event (topic payload)
  "Emit an agent lifecycle event on the event bus if available."
  (when (event-bus-ready-p)
    (handler-case
        (hngh.core.event-bus:publish topic payload :source 'ai-orchestrator)
      (error (c)
        (hngh.core:log-warn "Failed to emit event ~A: ~A" topic c)))))

;;; --- Context assembly -----------------------------------------------------

(defun meta-context (&key (scope :full))
  "Assemble a meta-context plist describing the current system state."
  (declare (ignore scope))
  (list :recent-activity (collect-recent-activity)
        :system-state (collect-system-state)
        :kb-articles (list :relevant nil)
        :dogfooding (list :is-self-improvement nil :repo-state nil)
        :intra-tool-informing (list :conventions "Follow Hngh coding standards"
                                     :skills-to-activate nil)))

(defun collect-recent-activity ()
  "Gather recent activity from the event bus journal.
Returns a plist (:count N :events (...))."
  (let* ((journal-sym (find-symbol "*EVENT-JOURNAL-PATH*" :hngh.core.event-bus)))
    (if (and journal-sym (boundp journal-sym) (symbol-value journal-sym))
        (handler-case
            (let* ((journal-dir (symbol-value journal-sym))
                   (pattern (merge-pathnames "*.lisp" journal-dir))
                   (files (sort (or (directory pattern) '())
                                #'string> :key #'namestring))
                   (events '())
                   (max-events 20))
              (dolist (file files)
                (when (>= (length events) max-events) (return))
                (dolist (evt (hngh.core.event-bus:read-journal-events file))
                  (when (>= (length events) max-events) (return))
                  (push (list :id (hngh.core.event-bus:event-id evt)
                              :topic (hngh.core.event-bus:event-topic evt)
                              :source (hngh.core.event-bus:event-source evt)
                              :timestamp (hngh.core.event-bus:event-timestamp evt))
                        events)))
              (list :count (length events) :events (nreverse events)))
          (error () (list :count 0 :events nil)))
        (list :count 0 :events nil))))

(defun collect-system-state ()
  "Gather system state: hardware info, package count, config changes."
  (list :hardware (safe-hardware-info)
        :packages (safe-package-count)
        :config (safe-recent-config-changes)))

(defun safe-hardware-info ()
  "Get hardware-info plist from Resource Manager, or NIL if unavailable."
  (handler-case
      (when (and (fboundp 'hngh.core.resource-manager:hardware-info)
                 (resource-manager-running-p))
        (let ((hw (hngh.core.resource-manager:hardware-info)))
          (when hw
            (list :gpus (length (hngh.core.resource-manager:hardware-info-gpus hw))
                  :cpu-model (hngh.core.resource-manager:hardware-info-cpu-model hw)
                  :cpu-cores (hngh.core.resource-manager:hardware-info-cpu-cores hw)
                  :memory-total (hngh.core.resource-manager:hardware-info-memory-total hw)
                  :memory-available (hngh.core.resource-manager:hardware-info-memory-available hw)))))
    (error () nil)))

(defun safe-package-count ()
  "Get installed package count from Package Manager, or NIL if unavailable."
  (handler-case
      (let ((sym (find-symbol "LIST-INSTALLED" :hngh.plugins.package-manager)))
        (when (and sym (fboundp sym))
          (length (funcall sym))))
    (error () nil)))

(defun safe-recent-config-changes ()
  "Get recent config changes. Returns NIL for M1 (not yet implemented)."
  nil)

;;; --- Tool selection -------------------------------------------------------

(defun select-tool-for-task (task policy)
  "Select the most appropriate AI tool for TASK according to POLICY."
  (let ((prefer-tool (delegate-policy-prefer-tool policy))
        (privacy (delegate-policy-privacy policy))
        (tier (delegate-policy-prefer-tier policy)))
    ;; Explicit tool preference
    (when prefer-tool
      (return-from select-tool-for-task prefer-tool))
    ;; Privacy constraint: local-only forces local model
    (when (eq privacy :local-only)
      (when (model-runtime-running-p)
        (return-from select-tool-for-task :ollama)))
    ;; Tier preference
    (when (eq tier :local)
      (when (model-runtime-running-p)
        (return-from select-tool-for-task :ollama)))
    (when (eq tier :agentic)
      (when (tool-hub-fbound-p "SELECT-TOOL")
        (handler-case
            (let ((select-fn (find-symbol "SELECT-TOOL" :hngh.plugins.ai-tool-hub)))
              (let ((tool (funcall select-fn task
                                   :max-cost (delegate-policy-max-cost policy)
                                   :privacy (eq privacy :local-only))))
                (when tool (return-from select-tool-for-task tool))))
          (error ()))))
    ;; Default: try agentic first, then local
    (when (tool-hub-fbound-p "SELECT-TOOL")
      (handler-case
          (let ((select-fn (find-symbol "SELECT-TOOL" :hngh.plugins.ai-tool-hub)))
            (let ((tool (funcall select-fn task
                                 :max-cost (delegate-policy-max-cost policy)
                                 :privacy (eq privacy :local-only))))
              (when tool (return-from select-tool-for-task tool))))
        (error ())))
    (when (model-runtime-running-p)
      (return-from select-tool-for-task :ollama))
    ;; Last resort
    (when (tool-hub-running-p) :opencode)))

(defun make-task-spec (task)
  "Create a task-spec plist from a task description string."
  (list :description task
        :success-criteria (format nil "Complete: ~A" task)
        :constraints (list :max-cost 0.10 :max-latency 300)))

;;; --- Context package assembly ---------------------------------------------

(defun assemble-context-package (task context)
  "Assemble a full context package for TASK with optional CONTEXT."
  (let ((sys-context (if (or (null context) (eq context :auto))
                         (meta-context)
                         context)))
    (list* :task-spec (make-task-spec task) sys-context)))

;;; --- Core delegation ------------------------------------------------------

(defun delegate (task &key (preferences nil) (context :auto))
  "Delegate TASK to the best available AI tool.
Returns an agent-info struct with the invocation result."
  (let* ((policy (ensure-policy preferences))
         (ctx (assemble-context-package task context))
         (tool (select-tool-for-task task policy)))
    (unless tool
      (hngh.core:log-warn "No AI tool available for task: ~A" task)
      (let ((agent (make-agent-info
                    :id (next-agent-id)
                    :task task
                    :status :failed
                    :started-at (get-universal-time)
                    :context ctx
                    :result "No AI tool available. Ensure AI Tool Hub or Model Runtime is initialized."
                    :cost 0.0)))
        (register-agent agent)
        (return-from delegate agent)))
    ;; Create and register agent
    (let* ((agent-id (next-agent-id))
           (agent (make-agent-info
                   :id agent-id :tool tool :task task
                   :status :pending :started-at (get-universal-time)
                   :context ctx :cost 0.0)))
      (register-agent agent)
      (emit-agent-event "agent.spawned"
                        (list :id agent-id :tool tool
                              :task-hash (sxhash task) :cost-estimate 0.0))
      (setf (agent-info-status agent) :running)
      ;; Invoke and process result
      (let ((outcome (invoke-agent agent policy)))
        (update-agent agent-id
                      :status (if (eq outcome :success) :completed :failed))
        (emit-agent-event (if (eq outcome :success) "agent.completed" "agent.failed")
                          (list :id agent-id :tool tool :task task
                                :result (agent-info-result agent)
                                :cost (agent-info-cost agent)))
        (handler-case (write-transcript agent)
          (error (c)
            (hngh.core:log-warn "Failed to write transcript for agent ~D: ~A" agent-id c))))
      agent)))

(defun invoke-agent (agent policy)
  "Invoke AGENT using the appropriate tool dispatch.
Returns :success or :failure. Updates agent-info in-place."
  (let ((tool (agent-info-tool agent))
        (task (agent-info-task agent))
        (ctx (agent-info-context agent))
        (id (agent-info-id agent)))
    (handler-case
        (cond
          ;; Agentic CLI / direct API tools
          ((member tool '(:opencode :claude :codex :gemini :cecli
                          :anthropic-api :google-api :openai-api :local-openai-api))
           (if (tool-hub-fbound-p "INVOKE")
                (let ((invoke-fn (find-symbol "INVOKE" :hngh.plugins.ai-tool-hub)))
                  (let* ((result (funcall invoke-fn tool task :context ctx))
                         (inv-id (ignore-errors
                                   (hngh.plugins.ai-tool-hub:invocation-info-id result)))
                         (inv-status (ignore-errors
                                       (hngh.plugins.ai-tool-hub:invocation-info-status result)))
                         (inv-cost (ignore-errors
                                     (hngh.plugins.ai-tool-hub:invocation-info-cost result)))
                         (inv-result (ignore-errors
                                       (hngh.plugins.ai-tool-hub:invocation-info-result result)))
                         (inv-error (ignore-errors
                                      (hngh.plugins.ai-tool-hub:invocation-info-error result))))
                    (update-agent id
                                  :backend-id inv-id
                                  :cost (or inv-cost 0.0))
                    (if (eq inv-status :completed)
                        (progn
                          (update-agent id
                                        :result (or (and (stringp inv-result) inv-result)
                                                    (and inv-result (princ-to-string inv-result))
                                                    (princ-to-string result))
                                        :status :completed)
                          (return-from invoke-agent :success))
                        (progn
                          (update-agent id
                                        :result (or (and (stringp inv-error) inv-error)
                                                    (and inv-error (princ-to-string inv-error))
                                                    (and (stringp inv-result) inv-result)
                                                    (and inv-result (princ-to-string inv-result))
                                                    (princ-to-string result))
                                        :status :failed)
                          (return-from invoke-agent :failure)))))
                (progn
                  (update-agent id
                                :result (format nil "AI Tool Hub invoke not yet implemented for ~A" tool)
                                :status :failed)
                  (return-from invoke-agent :failure))))
          ;; Local model runtime tools
          ((member tool '(:ollama :llama-cpp :unsloth :comfyui))
           (if (model-runtime-fbound-p "SPAWN-RUNTIME")
                (handler-case
                    (let* ((spawn-fn (find-symbol "SPAWN-RUNTIME" :hngh.plugins.model-runtime))
                           (model-name (or (delegate-policy-model policy) "default"))
                           (runtime (funcall spawn-fn tool
                                            (list :name model-name)
                                            :grant-id nil))
                           (runtime-id (and runtime
                                            (hngh.plugins.model-runtime:runtime-info-id runtime)))
                           (runtime-status (and runtime
                                                (hngh.plugins.model-runtime:runtime-info-status
                                                 runtime))))
                      (update-agent id :backend-id runtime-id)
                      (if (eq runtime-status :ready)
                          (progn
                            (update-agent id
                                          :result (format nil "Local runtime ~A (~A) spawned" tool model-name)
                                          :status :completed)
                            (return-from invoke-agent :success))
                          (progn
                            (update-agent id
                                          :result (format nil "Failed to spawn local runtime ~A (~A): status ~A"
                                                          tool model-name runtime-status)
                                          :status :failed)
                            (return-from invoke-agent :failure))))
                  (error (c)
                    (update-agent id
                                  :result (format nil "Failed to spawn local runtime ~A: ~A" tool c)
                                  :status :failed)
                   (return-from invoke-agent :failure)))
               (progn
                 (update-agent id
                               :result (format nil "Model Runtime not available for ~A" tool)
                               :status :failed)
                 (return-from invoke-agent :failure))))
          ;; Unknown tool
          (t
           (update-agent id
                         :result (format nil "Unknown tool: ~A" tool)
                         :status :failed)
           :failure))
      (error (c)
        (update-agent id
                      :result (format nil "Invocation error: ~A" c)
                      :status :failed)
        :failure))))

;;; --- Transcript persistence -----------------------------------------------

(defun write-transcript (agent)
  "Persist the agent's transcript to agents/<id>/transcript.lisp."
  (when (state-store-ready-p)
    (let ((path (format nil "agents/~D/transcript.lisp" (agent-info-id agent)))
          (transcript (list :agent-id (agent-info-id agent)
                            :tool (agent-info-tool agent)
                            :task (agent-info-task agent)
                            :status (agent-info-status agent)
                            :cost (agent-info-cost agent)
                            :started-at (agent-info-started-at agent)
                            :result (agent-info-result agent)
                            :context (agent-info-context agent)
                            :completed-at (get-universal-time))))
      (hngh.core.state-store:write-state path transcript)
      (setf (agent-info-transcript-path agent) path)))
  agent)

;;; --- Handoff --------------------------------------------------------------

(defun handoff (from-agent to-tool &key (context-delta nil))
  "Hand off work from an existing agent to a new tool.
Returns the new agent-info, or NIL if FROM-AGENT doesn't exist."
  (let ((source (find-agent from-agent)))
    (unless source
      (hngh.core:log-warn "Handoff source agent ~D not found" from-agent)
      (return-from handoff nil))
    (let* ((task (format nil "Handoff from agent ~D (~A): ~A"
                         from-agent
                         (agent-info-tool source)
                         (agent-info-task source)))
           (combined-context (list* :handoff-source-id from-agent
                                    :handoff-source-tool (agent-info-tool source)
                                    :handoff-source-result (agent-info-result source)
                                    (append context-delta
                                            (agent-info-context source))))
           (agent-id (next-agent-id))
           (agent (make-agent-info
                   :id agent-id :tool to-tool :task task
                   :status :pending :started-at (get-universal-time)
                   :context combined-context :cost 0.0)))
      (register-agent agent)
      (setf (agent-info-status agent) :running)
      (emit-agent-event "agent.handoff"
                        (list :from-id from-agent :to-id agent-id
                              :from-tool (agent-info-tool source)
                              :to-tool to-tool
                              :context-delta context-delta))
      (let ((outcome (invoke-agent agent (default-policy))))
        (update-agent agent-id
                      :status (if (eq outcome :success) :completed :failed))
        (emit-agent-event (if (eq outcome :success) "agent.completed" "agent.failed")
                          (list :id agent-id :tool to-tool :task task
                                :result (agent-info-result agent)
                                :cost (agent-info-cost agent)))
        (handler-case (write-transcript agent)
          (error (c)
            (hngh.core:log-warn "Failed to write transcript for handoff agent ~D: ~A"
                                agent-id c))))
      agent)))

;;; --- Kill agent -----------------------------------------------------------

(defun kill-agent (id &key (reason :killed))
  "Kill a running agent by ID. Returns T if found and killed, NIL otherwise."
  (let ((agent (find-agent id)))
    (unless agent
      (hngh.core:log-debug "Kill agent: agent ~D not found" id)
      (return-from kill-agent nil))
    (let ((tool (agent-info-tool agent))
          (status (agent-info-status agent))
          (backend-id (agent-info-backend-id agent)))
      (unless (member status '(:running :pending))
        (hngh.core:log-debug "Agent ~D is ~A, not killing" id status)
        (return-from kill-agent nil))
      ;; Kill via appropriate channel
      (cond
        ((member tool '(:opencode :claude :codex :gemini :cecli
                        :anthropic-api :google-api :openai-api))
          (when (tool-hub-fbound-p "KILL-INVOCATION")
            (handler-case
                (funcall (find-symbol "KILL-INVOCATION" :hngh.plugins.ai-tool-hub)
                         (or backend-id id))
              (error (c)
                (hngh.core:log-warn "Error killing invocation ~D: ~A" id c)))))
        ((member tool '(:ollama :llama-cpp :unsloth :comfyui))
          (when (model-runtime-fbound-p "STOP-RUNTIME")
            (handler-case
                (funcall (find-symbol "STOP-RUNTIME" :hngh.plugins.model-runtime)
                         (or backend-id id))
              (error (c)
                (hngh.core:log-warn "Error stopping runtime ~D: ~A" id c))))))
      ;; Update status and emit event
      (update-agent id :status :killed
                    :result (format nil "Killed by orchestrator: ~A" reason))
      (emit-agent-event "agent.failed"
                        (list :id id :tool tool :reason reason))
      (handler-case (write-transcript (find-agent id))
        (error (c)
          (hngh.core:log-warn "Failed to write transcript for killed agent ~D: ~A" id c)))
      t)))

;;; --- Queries --------------------------------------------------------------

(defun list-agents ()
  "Return a list of all agent-info structs, ordered by creation time."
  (bt:with-lock-held (*agents-lock*)
    (sort (loop for agent being the hash-values of *agents* collect agent)
          #'< :key #'agent-info-started-at)))

(defun status ()
  "Return a plist describing the current orchestrator status."
  (bt:with-lock-held (*agents-lock*)
    (let ((all-agents (loop for agent being the hash-values of *agents* collect agent))
          (active-count 0)
          (total-cost 0.0))
      (dolist (a all-agents)
        (when (member (agent-info-status a) '(:running :pending))
          (incf active-count))
        (incf total-cost (agent-info-cost a)))
      (list :running *running*
            :active-agents active-count
            :total-agents (length all-agents)
            :total-cost total-cost))))

;;; --- Event handlers -------------------------------------------------------

(defun handle-resource-pressure (event)
  "Handle resource.pressure events. On :critical, preempt lowest-priority agent."
  (let ((payload (hngh.core.event-bus:event-payload event)))
    (when (eq (getf payload :level) :critical)
      (hngh.core:log-warn "Resource pressure critical — preempting lowest-priority agent")
      (let ((victim (find-lowest-priority-agent)))
        (when victim
          (hngh.core:log-info "Preempting agent ~D (~A) due to resource pressure"
                              (agent-info-id victim) (agent-info-task victim))
          (kill-agent (agent-info-id victim) :reason :preempted))))))

(defun handle-agent-completed (event)
  "Handle agent.completed events from AI Tool Hub. Updates local agent-info."
  (when (eq (hngh.core.event-bus:event-source event) 'ai-orchestrator)
    (return-from handle-agent-completed nil))
  (let* ((payload (hngh.core.event-bus:event-payload event))
         (id (or (getf payload :id)
                 (getf payload :invocation-id))))
    (when id
      (let ((agent (or (find-agent id)
                       (find-agent-by-backend-id id))))
        (when agent
          (let ((agent-id (agent-info-id agent)))
            (update-agent agent-id :status :completed
                          :result (or (getf payload :result)
                                      (agent-info-result agent)
                                      "Completed")
                          :cost (getf payload :cost (agent-info-cost agent)))
            (hngh.core:log-debug "Agent ~D completed (via event id ~D)"
                                 agent-id id)))))))

(defun find-lowest-priority-agent ()
  "Find the most recently started running/pending agent (LIFO heuristic)."
  (bt:with-lock-held (*agents-lock*)
    (let ((candidates (loop for agent being the hash-values of *agents*
                            when (member (agent-info-status agent) '(:running :pending))
                            collect agent)))
      (car (sort candidates #'> :key #'agent-info-started-at)))))

;;; --- Lifecycle ------------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the AI orchestrator plugin."
  (declare (ignore hngh-home))
  (setf *running* nil *event-subscriptions* '())
  (bt:with-lock-held (*dispatch-lock*)
    (setf *dispatch-paused* nil *dispatch-resume-at* nil))
  (bt:with-lock-held (*agents-lock*)
    (setf *agents* (make-hash-table :test 'eql) *next-agent-id* 0))
  (bt:with-lock-held (*policies-lock*)
    (setf *policies* (make-hash-table :test 'eq))
    (setf (gethash :default *policies*) (copy-delegate-policy *default-policy*)))
  (load-policies)
  (when (event-bus-ready-p)
    (handler-case
        (push (hngh.core.event-bus:subscribe "resource.pressure"
                                              #'handle-resource-pressure)
              *event-subscriptions*)
      (error (c)
        (hngh.core:log-warn "Could not subscribe to resource.pressure: ~A" c)))
    (handler-case
        (push (hngh.core.event-bus:subscribe "agent.completed"
                                              #'handle-agent-completed)
              *event-subscriptions*)
      (error (c)
        (hngh.core:log-warn "Could not subscribe to agent.completed: ~A" c))))
  (setf *running* t)
  (hngh.core:log-info "AI Orchestrator initialized"))

(defun shutdown ()
  "Shut down the AI orchestrator plugin."
  (when *running*
    (hngh.core:log-info "Shutting down AI Orchestrator...")
    (let ((running-ids
            (bt:with-lock-held (*agents-lock*)
              (loop for agent being the hash-values of *agents*
                    when (member (agent-info-status agent) '(:running :pending))
                    collect (agent-info-id agent)))))
      (dolist (id running-ids)
        (handler-case (kill-agent id :reason :shutdown)
          (error (c)
            (hngh.core:log-warn "Error killing agent ~D during shutdown: ~A" id c)))))
    (when (event-bus-ready-p)
      (dolist (sub-id *event-subscriptions*)
        (handler-case (hngh.core.event-bus:unsubscribe sub-id)
          (error (c)
            (hngh.core:log-warn "Error unsubscribing ~D: ~A" sub-id c)))))
    (setf *event-subscriptions* '())
    (bt:with-lock-held (*dispatch-lock*)
      (setf *dispatch-paused* nil *dispatch-resume-at* nil))
    (bt:with-lock-held (*agents-lock*)
      (clrhash *agents*) (setf *next-agent-id* 0))
    (bt:with-lock-held (*policies-lock*)
      (clrhash *policies*))
    (setf *running* nil)
    (hngh.core:log-info "AI Orchestrator shut down")))

(defun running-p ()
  "Return T if the AI orchestrator plugin is active."
  *running*)


;;; --- Task driver (M3): persistent queue + scheduler-driven execution -------
(defvar *task-queue-path* "tasks/queue.lisp"
  "State-store relative path of the persistent task queue.")
(defvar *task-queue-lock* (bt:make-lock "hngh-task-queue"))
(defvar *next-task-id* 0)
(defvar *task-driver-schedule-id* nil)

(defparameter *task-statuses*
  '(:proposed :queued :claimed :blocked :running :done :failed :cancelled)
  "Statuses accepted by persisted task records.")

(defparameter *task-authorities*
  '(:procedural :advisory :approval :worker :owner :operation)
  "Action-authority classes accepted by persisted task records.")

(defparameter *task-schema-versions* '(2 3)
  "Task record schemas understood by the persistent queue.")

(defparameter *task-types* '(:plan :research :work :operation)
  "Task classes accepted by version 3 task records.")

(defparameter *task-roles* '(:coordinator :worker :reviewer :scout)
  "Agent roles accepted by version 3 task records.")

(defparameter *verification-statuses* '(:pending :passed :failed)
  "Verification states accepted by version 3 task records.")

(defun task-record-has-key-p (record key)
  "Return T when plist RECORD explicitly contains KEY."
  (not (null (member key record))))

(defun normalize-task-record (record)
  "Return RECORD upgraded to the latest compatible task-record shape.
Existing values are retained. Missing v2 control fields receive conservative
local/advisory defaults so historical queue entries remain readable. Version 3
records retain their schema and gain shared-queue metadata defaults."
  (unless (listp record)
    (error "Task record must be a plist: ~S" record))
  (let* ((entry (copy-list record))
         (schema-version (or (getf entry :schema-version) 2)))
    (setf (getf entry :schema-version) schema-version)
    (unless (task-record-has-key-p entry :authority)
      (setf (getf entry :authority)
            (if (eql schema-version 3) :worker :advisory)))
    (dolist (default '((:approval-at nil)
                       (:depends-on ())
                       (:attempt 0)
                       (:max-attempts 1)
                       (:not-before nil)
                       (:lease-until nil)
                       (:blocked-reason nil)
                       (:started-at nil)))
      (unless (task-record-has-key-p entry (first default))
        (setf (getf entry (first default)) (second default))))
    (when (eql schema-version 3)
      (dolist (default '((:type :work)
                         (:assigned-role :worker)
                         (:input-artifacts ())
                         (:output-artifacts ())
                         (:verification (:command nil :status :pending
                                         :observed-at nil))
                         (:claimant nil)
                         (:claimant-role nil)
                         (:claimant-route nil)
                         (:claimed-at nil)
                         (:lease-expires-at nil)
                         (:verifier nil)
                         (:allowed-roles nil)
                         (:authority :worker)
                         (:verification-command nil)
                         (:last-failure nil)
                         (:transition-log ())))
        (unless (task-record-has-key-p entry (first default))
          (setf (getf entry (first default)) (second default)))))
    entry))

(defun validate-task-record (record)
  "Return T for a valid normalized task RECORD or signal an error.
Validation is intentionally structural: dispatch eligibility remains the task
of the later queue-selection wave."
  (unless (listp record)
    (error "Task record must be a plist: ~S" record))
  (unless (member (getf record :schema-version) *task-schema-versions*)
    (error "Task record has unsupported schema version: ~S"
           (getf record :schema-version)))
  (unless (stringp (getf record :task))
    (error "Task record :task must be a string"))
  (unless (member (getf record :status) *task-statuses*)
    (error "Task record has unsupported status: ~S" (getf record :status)))
  (unless (member (getf record :authority) *task-authorities*)
    (error "Task record has unsupported authority: ~S" (getf record :authority)))
  (unless (and (integerp (getf record :attempt))
               (not (minusp (getf record :attempt))))
    (error "Task record :attempt must be a non-negative integer"))
  (unless (and (integerp (getf record :max-attempts))
               (plusp (getf record :max-attempts)))
    (error "Task record :max-attempts must be a positive integer"))
  (unless (listp (getf record :depends-on))
    (error "Task record :depends-on must be a list"))
  (when (eql (getf record :schema-version) 3)
    (unless (member (getf record :type) *task-types*)
      (error "Task record has unsupported type: ~S" (getf record :type)))
    (unless (member (getf record :assigned-role) *task-roles*)
      (error "Task record has unsupported role: ~S"
             (getf record :assigned-role)))
    (dolist (key '(:input-artifacts :output-artifacts))
      (let ((artifacts (getf record key)))
        (unless (and (listp artifacts) (every #'stringp artifacts))
          (error "Task record ~S must be a list of strings" key))))
    (let ((verification (getf record :verification)))
      (unless (listp verification)
        (error "Task record :verification must be a plist"))
      (unless (or (null (getf verification :command))
                  (stringp (getf verification :command)))
        (error "Task record verification :command must be a string or NIL"))
      (unless (member (getf verification :status) *verification-statuses*)
        (error "Task record has unsupported verification status: ~S"
               (getf verification :status)))
      (unless (or (null (getf verification :observed-at))
                  (integerp (getf verification :observed-at)))
        (error "Task record verification :observed-at must be an integer or NIL"))))
  t)

(defun read-task-queue ()
  "Read, normalize, and validate persisted task records.
Malformed data signals an error so callers fail closed rather than dropping work."
  (when (state-store-ready-p)
    (let ((queue (hngh.core.state-store:read-state *task-queue-path*)))
      (when queue
        (unless (listp queue)
          (error "Task queue must be a list: ~S" queue))
        (mapcar (lambda (entry)
                  (let ((normalized (normalize-task-record entry)))
                    (validate-task-record normalized)
                    normalized))
                queue)))))

(defun write-task-queue (queue)
  "Persist QUEUE (list of task plists) to the state store."
  (when (state-store-ready-p)
    (hngh.core.state-store:write-state *task-queue-path* queue)))

;;; --- Phase 2 claim/release (RED-stage API skeletons) ----------------------

(defun %claim-authority-permits-role-p (authority role)
  "Return T when ROLE may claim AUTHORITY, or signal for an unknown authority."
  (case authority
    (:worker (eq role :worker))
    (:owner (eq role :owner))
    (:operation (eq role :operation))
    (otherwise (error "Task has unsupported claim authority: ~S" authority))))

(defun claim-task (id &key agent role route)
  "Claim queued task ID for AGENT.
This RED-stage skeleton verifies the Phase 2 admission guards under the queue
lock. Persisting the transition and emitting :TASK-CLAIMED are deliberately
deferred to the GREEN implementation."
  (declare (ignore route))
  (unless (and (integerp id) (stringp agent) role)
    (error "Claim requires an integer id, string agent, and role"))
  (bt:with-lock-held (*task-queue-lock*)
    (let* ((queue (or (read-task-queue) '()))
           (task (find id queue :key (lambda (entry) (getf entry :id)))))
      (unless task
        (error "Task ~D does not exist" id))
      (unless (eq (getf task :status) :queued)
        (error "Task ~D is not queued" id))
      (unless (member role (getf task :allowed-roles))
        (error "Role ~S may not claim task ~D" role id))
      (unless (%claim-authority-permits-role-p (getf task :authority) role)
        (error "Role ~S may not claim ~S-authority task ~D"
               role (getf task :authority) id))
      (error "claim-task Phase 2 transition is not implemented"))))

(defun release-task (id &key agent reason)
  "Release claimed task ID for AGENT.
This RED-stage skeleton verifies release ownership under the queue lock. The
state transition and :TASK-RELEASED event are intentionally deferred to the
GREEN implementation."
  (declare (ignore reason))
  (unless (and (integerp id) (stringp agent))
    (error "Release requires an integer id and string agent"))
  (bt:with-lock-held (*task-queue-lock*)
    (let* ((queue (or (read-task-queue) '()))
           (task (find id queue :key (lambda (entry) (getf entry :id))))
           (now (get-universal-time)))
      (unless task
        (error "Task ~D does not exist" id))
      (unless (eq (getf task :status) :claimed)
        (error "Task ~D is not claimed" id))
      (let ((lease-expires-at (getf task :lease-expires-at)))
        (unless (or (string= agent (or (getf task :claimant) ""))
                    (and (integerp lease-expires-at) (<= lease-expires-at now)))
          (error "Agent ~S may not release task ~D" agent id)))
      (error "release-task Phase 2 transition is not implemented"))))

(defun %update-queue-entry (id fn)
  "Apply FN to the entry with :id ID inside the persisted queue (under lock)."
  (bt:with-lock-held (*task-queue-lock*)
    (let ((queue (or (read-task-queue) '())))
      (dolist (e queue)
        (when (and (listp e) (eql (getf e :id) id))
          (funcall fn e)))
      (write-task-queue queue))))

(defun submit-task (task &key (policy '(:prefer-tool :local-openai-api)))
  "Enqueue TASK (string) with POLICY plist. Returns the new task id.
Default policy routes to the free local tool (:local-openai-api)."
  (unless (stringp task)
    (error "TASK must be a string"))
  (bt:with-lock-held (*task-queue-lock*)
    (let* ((queue (or (read-task-queue) '()))
           (max-id (reduce #'max
                           (mapcar (lambda (e)
                                     (if (and (listp e) (integerp (getf e :id)))
                                         (getf e :id) 0))
                                   queue)
                           :initial-value 0))
           (id (setf *next-task-id* (max (1+ max-id) (1+ *next-task-id*))))
           (entry (list :id id :schema-version 2 :task task :status :queued
                        :policy policy :authority :advisory :approval-at nil
                        :depends-on '() :attempt 0 :max-attempts 1
                        :not-before nil :lease-until nil :blocked-reason nil
                        :result nil :error nil :submitted-at (get-universal-time)
                        :started-at nil :finished-at nil)))
      (write-task-queue (append queue (list entry)))
      (when (event-bus-ready-p)
        (ignore-errors
          (hngh.core.event-bus:publish
           :task-queued
           (list :id id :status :queued :schema-version 2)
           :source 'ai-orchestrator)))
      (hngh.core:log-info "Task ~D queued (~D chars)" id (length task))
      id)))

(defun list-tasks (&key status)
  "Return task entries, optionally filtered by STATUS keyword."
  (let ((queue (or (read-task-queue) '())))
    (if status
        (remove-if-not (lambda (e) (eq (getf e :status) status)) queue)
        queue)))

;;; --- H-A3: Pause/Resume dispatch -------------------------------------------

(defun dispatch-paused-p ()
  "Return T when new task dispatch is paused."
  (bt:with-lock-held (*dispatch-lock*)
    *dispatch-paused*))

(defun dispatch-resume-at ()
  "Return the resume_at universal-time, or NIL for an indefinite pause."
  (bt:with-lock-held (*dispatch-lock*)
    *dispatch-resume-at*))

(defun pause-dispatch (&key (resume-at nil))
  "Pause new task dispatch. When RESUME-AT (a universal time) is supplied,
task-driver-tick will auto-resume once `now >= resume_at`. Without RESUME-AT
the pause lasts until resume-dispatch is called manually."
  (bt:with-lock-held (*dispatch-lock*)
    (setf *dispatch-paused* t
          *dispatch-resume-at* resume-at))
  (hngh.core:log-info "Task dispatch paused~@[ until ~D~]" resume-at))

(defun resume-dispatch ()
  "Clear the dispatch pause and resume_at. Idempotent — safe to call when
not paused."
  (bt:with-lock-held (*dispatch-lock*)
    (setf *dispatch-paused* nil
          *dispatch-resume-at* nil))
  (hngh.core:log-info "Task dispatch resumed"))

(defun %maybe-auto-resume (now)
  "If paused and resume_at is set and has passed, clear the pause.
Returns T if the pause was auto-cleared (meaning the tick may proceed)."
  (bt:with-lock-held (*dispatch-lock*)
    (when (and *dispatch-paused*
               *dispatch-resume-at*
               (>= now *dispatch-resume-at*))
      (let ((resume-at *dispatch-resume-at*))
        (setf *dispatch-paused* nil
              *dispatch-resume-at* nil)
        (hngh.core:log-info "Task dispatch auto-resumed (resume_at ~D reached)"
                            resume-at)
        t))))

;;; --- H-A3: Stale-lease recovery --------------------------------------------

(defun recover-stale-task-leases ()
  "Transition :running tasks with expired (non-nil) :lease-until to :blocked.
A :running task with :lease-until nil holds the slot indefinitely and is NOT
recovered. Returns the count of tasks transitioned.

This function reads and writes the task queue under *task-queue-lock*."
  (bt:with-lock-held (*task-queue-lock*)
    (let* ((now (get-universal-time))
           (queue (or (read-task-queue) '()))
           (count 0))
      (dolist (entry queue)
        (when (and (eq (getf entry :status) :running)
                   (let ((lease-until (getf entry :lease-until)))
                     (and (integerp lease-until) (< lease-until now))))
          (let ((id (getf entry :id))
                (lease-until (getf entry :lease-until))
                (started-at (getf entry :started-at)))
            (setf (getf entry :status) :blocked
                  (getf entry :blocked-reason)
                  (format nil "stale lease: task ~D lease-until ~D expired at ~D"
                          id lease-until now)
                  (getf entry :finished-at) now)
            (incf count)
            (hngh.core:log-warn "Recovered stale task ~D (lease expired ~D)"
                                id lease-until))))
      (when (plusp count)
        (write-task-queue queue))
      count)))

;;; --- H-A2: Pure eligibility selector -----------------------------------------

(defun next-eligible-task (queue now maintenance-state)
  "Select the oldest eligible task from QUEUE given NOW and MAINTENANCE-STATE.
Returns two values:
1. The eligible task plist (oldest by :submitted-at, then :id), or NIL if none.
2. A list of tasks that should be persisted as :blocked (due to failed/cancelled deps).
The function is PURE w.r.t. the queue argument: no state-store access."
  (labels ((dep-done-p (dep-id)
             (let ((dep (find dep-id queue :key (lambda (e) (getf e :id)))))
               (and dep (eq (getf dep :status) :done))))
           (running-lease-blocks-p ()
             (some (lambda (other)
                     (and (eq (getf other :status) :running)
                          (let ((lease (getf other :lease-until)))
                            (or (null lease) (> lease now)))))
                   queue))
           (task-eligible-p (task)
             (and (eq (getf task :status) :queued)
                  (every #'dep-done-p (getf task :depends-on))
                  (or (null (getf task :not-before))
                      (<= (getf task :not-before) now))
                  (not (running-lease-blocks-p))
                  (not (eq (getf task :authority) :proposed))
                  (or (not (eq (getf task :authority) :approval))
                      (and (integerp (getf task :approval-at))
                           (> (getf task :approval-at) 0)))
                  (let ((requires-stable (getf (getf task :policy) :requires-stable-system)))
                    (or (not requires-stable)
                        (eq maintenance-state :clear))))))
    (if (eq maintenance-state :maintenance-active)
        (values nil (%blocked-by-failed-deps queue now))
        (let* ((candidates (remove-if-not #'task-eligible-p queue))
               (sorted (sort (copy-list candidates)
                              (lambda (a b)
                                (let ((sa (getf a :submitted-at))
                                      (sb (getf b :submitted-at)))
                                  (or (< sa sb)
                                      (and (= sa sb)
                                           (< (getf a :id) (getf b :id)))))))))
          (values (first sorted) (%blocked-by-failed-deps queue now))))))

(defun %blocked-by-failed-deps (queue now)
  "Return a list of QUEUE tasks whose dependency has failed/cancelled,
each returned with :status :blocked and :blocked-reason set."
  (let ((blocked-tasks '()))
    (dolist (task queue)
      (when (eq (getf task :status) :queued)
        (dolist (dep-id (getf task :depends-on))
          (let ((dep (find dep-id queue :key (lambda (e) (getf e :id)))))
            (when (and dep (member (getf dep :status) '(:failed :cancelled)))
              (let ((blocked (copy-list task)))
                (setf (getf blocked :status) :blocked
                      (getf blocked :blocked-reason)
                      (format nil "dependency ~D ~A" dep-id (getf dep :status))
                      (getf blocked :finished-at) now)
                (push blocked blocked-tasks)))))))
    (nreverse blocked-tasks)))

;;; --- Task driver tick (updated for H-B2) -------------------------------------

(defun task-driver-tick ()
  "One driver cycle: recover stale leases, check pause, check maintenance,
then run the oldest eligible task via DELEGATE, persisting the outcome.
The delegate call runs outside the queue lock (long inference)."
  ;; 1. Recover stale leases first — frees the execution slot.
  (recover-stale-task-leases)
  ;; 2. Check pause state (auto-resume if resume_at has passed).
  (let ((now (get-universal-time)))
    (when (dispatch-paused-p)
      (unless (%maybe-auto-resume now)
        (return-from task-driver-tick nil)))
    ;; 3. Read maintenance state and select eligible task.
    (let* ((maintenance-state (hngh.plugins.maintenance-coordinator:read-maintenance-state))
           (queue (or (read-task-queue) '())))
      (multiple-value-bind (eligible-task blocked-tasks)
          (next-eligible-task queue now maintenance-state)
        (dolist (blocked blocked-tasks)
          (let ((bid (getf blocked :id)))
            (%update-queue-entry
             bid (lambda (e)
                   (setf (getf e :status) :blocked
                         (getf e :blocked-reason) (getf blocked :blocked-reason)
                         (getf e :finished-at) (get-universal-time))))))
        (when eligible-task
          (let ((id (getf eligible-task :id))
                (task (getf eligible-task :task))
                (policy (getf eligible-task :policy)))
            (%update-queue-entry id (lambda (e) (setf (getf e :status) :running)))
            (handler-case
                (let* ((agent (delegate task :preferences policy))
                       (ok (eq (agent-info-status agent) :completed))
                       (result (agent-info-result agent)))
                  (%update-queue-entry
                   id (lambda (e)
                        (setf (getf e :status) (if ok :done :failed)
                              (getf e :result) (and (stringp result) result)
                              (getf e :error) (unless ok (or (and (stringp result) result) "unknown"))
                              (getf e :finished-at) (get-universal-time))))
                  (when (event-bus-ready-p)
                    (ignore-errors
                     (hngh.core.event-bus:publish :task-completed
                                                  (list :id id :status (if ok :done :failed))
                                                  :source 'ai-orchestrator)))
                  id)
              (error (c)
                (%update-queue-entry
                 id (lambda (e)
                      (setf (getf e :status) :failed
                            (getf e :error) (princ-to-string c)
                            (getf e :finished-at) (get-universal-time))))
                nil))))))))

(defun start-task-driver (&key (tick-seconds 5))
  "(Re)register the task driver on the scheduler. Returns the schedule id.
Idempotent and restart-safe: any previous registration is cancelled first."
  (when *task-driver-schedule-id*
    (ignore-errors (hngh.core.scheduler:cancel *task-driver-schedule-id*))
    (setf *task-driver-schedule-id* nil))
  (setf *task-driver-schedule-id*
        (hngh.core.scheduler:schedule
         "task-driver" (list :interval tick-seconds)
         (list :function #'task-driver-tick) :source 'ai-orchestrator)))

(defun stop-task-driver ()
  "Cancel the task driver schedule."
  (when *task-driver-schedule-id*
    (ignore-errors (hngh.core.scheduler:cancel *task-driver-schedule-id*))
    (setf *task-driver-schedule-id* nil)))
