;;;; plugins/ai-tool-hub.lisp — Hngh AI Tool Hub (B11)
;;;; Agentic CLI invocation + direct API, tool registry, cost tracking.
;;;;
;;;; Tools: Opencode, Claude Code, Codex, Gemini-CLI, Cecli,
;;;;        Anthropic API, Google API, OpenAI API, Local OpenAI-compatible (unsloth).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.ai-tool-hub)

;;; --- Utility: which ---------------------------------------------------

(defun which (executable)
  "Check if EXECUTABLE exists on PATH. Returns the full path or NIL."
  #+sbcl
  (handler-case
      (let* ((proc (sb-ext:run-program "which" (list executable)
                                       :output :stream :wait t :search t))
             (output (read-line (sb-ext:process-output proc) nil nil)))
        (when (and output (stringp output)
                   (> (length (string-trim '(#\Space #\Newline #\Return #\Tab) output)) 0))
          (string-trim '(#\Space #\Newline #\Return #\Tab) output)))
    (error () nil))
  #-sbcl
  (progn
    (hngh.core:log-warn "which() not implemented on this Lisp")
    nil))

;;; --- Utility: local endpoint probe (M2) ---------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (ignore-errors (require :sb-bsd-sockets)))

(defun local-endpoint-available-p (host port)
  "T when a TCP connection to HOST:PORT succeeds (loopback: instant fail if down)."
  #+sbcl
  (handler-case
      (let ((sock (make-instance 'sb-bsd-sockets:inet-socket
                                 :type :stream :protocol :tcp)))
        (unwind-protect
             (sb-bsd-sockets:socket-connect
              sock (sb-bsd-sockets:host-ent-address
                    (sb-bsd-sockets:get-host-by-name host)) port)
          (sb-bsd-sockets:socket-close sock))
        t)
    (error () nil))
  #-sbcl
  (progn
    (hngh.core:log-warn "local-endpoint-available-p() not implemented on this Lisp")
    nil))

;;; --- Data structures -------------------------------------------------

(defstruct tool-info
  "Information about an available AI tool."
  id            ; keyword (:opencode :claude :codex :gemini :cecli etc.)
  name          ; string ("Opencode" "Claude Code" etc.)
  type          ; :agentic-cli or :direct-api
  command       ; string ("opencode" "claude" "codex" "gemini" "cecli" "curl")
  available-p   ; boolean — is this tool installed / key available?
  capabilities  ; list of keywords
  providers     ; list of keywords (:anthropic :google :openai :local)
  cost-model    ; :per-query, :per-token, :subscription, :free
  context-format ; :opencode-prompt, :cli-args, :jsonl, :https-system-message
  dogfooding)   ; boolean — used to develop Hngh?

(defstruct invocation-info
  "Information about a single AI tool invocation."
  id            ; integer (unique)
  tool          ; keyword (tool-id)
  task          ; string (task description)
  status        ; :pending, :running, :completed, :failed, :killed
  started-at    ; universal-time
  cost          ; number (USD, 0.0 if unknown)
  pid           ; integer or nil (subprocess PID for agentic CLIs)
  workdir       ; string or nil (temporary workdir)
  result        ; string or nil (output)
  error)        ; string or nil (failure reason)

;;; --- Global state ----------------------------------------------------

(defvar *running* nil
  "Whether the AI Tool Hub is active.")

(defvar *hngh-home* nil
  "The Hngh state directory (set during INIT).")

(defvar *tools* nil
  "List of tool-info structs representing the tool registry.")

(defvar *tools-lock* (bt:make-lock "hngh-ai-tool-hub-tools")
  "Mutex protecting *tools*.")

(defvar *invocations* nil
  "List of invocation-info structs (newest first).")

(defvar *invocations-lock* (bt:make-lock "hngh-ai-tool-hub-invocations")
  "Mutex protecting *invocations* and *next-invocation-id*.")

(defvar *next-invocation-id* 0
  "Counter for invocation IDs (monotonically increasing).")

(defvar *cost-log* nil
  "List of cost log entries (plists). Each entry has keys:
    :timestamp :tool :provider :model :tokens-in :tokens-out
    :cost-usd :task-hash :success")

(defvar *cost-log-lock* (bt:make-lock "hngh-ai-tool-hub-cost-log")
  "Mutex protecting *cost-log*.")

;;; --- Persistence paths -----------------------------------------------

(defun cost-log-path ()
  "Return the relative path for cost log persistence."
  "state/plugins/ai-tool-hub/costs.lisp")

;;; --- Event helpers ---------------------------------------------------

(defun publish-event (topic payload &key (source 'ai-tool-hub))
  "Publish an event to the event bus, if initialized."
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish topic payload :source source)
      (error (c)
        (hngh.core:log-warn "AI Tool Hub: failed to publish event ~A: ~A" topic c)))))

;;; --- Tool registry ---------------------------------------------------

(defun make-default-tool-registry ()
  "Create the default tool registry with availability based on system detection.
  Returns a list of tool-info structs."
  (let ((tools nil))
    ;; Opencode — agentic CLI
    (push (make-tool-info
           :id :opencode
           :name "Opencode"
           :type :agentic-cli
           :command "opencode"
           :available-p (when (which "opencode") t)
           :capabilities '(:code-editing :system-manipulation
                           :multi-step-reasoning :tool-use :mcp)
           :providers '(:anthropic :google :openai :local)
           :cost-model :per-query
           :context-format :opencode-prompt
           :dogfooding t)
          tools)
    ;; Claude Code — agentic CLI
    (push (make-tool-info
           :id :claude
           :name "Claude Code"
           :type :agentic-cli
           :command "claude"
           :available-p (when (which "claude") t)
           :capabilities '(:code-editing :multi-step-reasoning :tool-use)
           :providers '(:anthropic)
           :cost-model :per-query
           :context-format :cli-args
           :dogfooding nil)
          tools)
    ;; Codex — agentic CLI
    (push (make-tool-info
           :id :codex
           :name "Codex"
           :type :agentic-cli
           :command "codex"
           :available-p (when (which "codex") t)
           :capabilities '(:code-editing :multi-step-reasoning)
           :providers '(:openai)
           :cost-model :per-query
           :context-format :cli-args
           :dogfooding nil)
          tools)
    ;; Gemini-CLI — agentic CLI
    (push (make-tool-info
           :id :gemini
           :name "Gemini-CLI"
           :type :agentic-cli
           :command "gemini"
           :available-p (when (which "gemini") t)
           :capabilities '(:code-editing :multi-step-reasoning)
           :providers '(:google)
           :cost-model :per-query
           :context-format :cli-args
           :dogfooding nil)
          tools)
    ;; Cecli — agentic CLI
    (push (make-tool-info
           :id :cecli
           :name "Cecli"
           :type :agentic-cli
           :command "cecli"
           :available-p (when (which "cecli") t)
           :capabilities '(:code-editing :system-manipulation
                           :multi-step-reasoning :tool-use :mcp)
           :providers '(:anthropic :openai :google :local)
           :cost-model :per-query
           :context-format :cecli-context
           :dogfooding t)
          tools)
    ;; Anthropic API — direct API
    (push (make-tool-info
           :id :anthropic-api
           :name "Anthropic API"
           :type :direct-api
           :command "curl"
           :available-p (and (which "curl")
                             (api-key-available-p :anthropic-api-key))
           :capabilities '(:simple-output)
           :providers '(:anthropic)
           :cost-model :per-token
           :context-format :https-system-message
           :dogfooding nil)
          tools)
    ;; Google API — direct API
    (push (make-tool-info
           :id :google-api
           :name "Google API"
           :type :direct-api
           :command "curl"
           :available-p (and (which "curl")
                             (api-key-available-p :google-api-key))
           :capabilities '(:simple-output)
           :providers '(:google)
           :cost-model :per-token
           :context-format :https-system-message
           :dogfooding nil)
          tools)
    ;; OpenAI API — direct API
    (push (make-tool-info
           :id :openai-api
           :name "OpenAI API"
           :type :direct-api
           :command "curl"
           :available-p (and (which "curl")
                             (api-key-available-p :openai-api-key))
           :capabilities '(:simple-output)
           :providers '(:openai)
           :cost-model :per-token
           :context-format :https-system-message
           :dogfooding nil)
          tools)
    ;; Local OpenAI-compatible (unsloth :8888) — direct API, $0
    (push (make-tool-info
           :id :local-openai-api
           :name "Local OpenAI-Compatible (unsloth)"
           :type :direct-api
           :command "curl"
           :available-p (and (which "curl")
                             (local-endpoint-available-p "127.0.0.1" 8888))
           :capabilities '(:simple-output)
           :providers '(:local :openai-compatible)
           :cost-model :free
           :context-format :https-system-message
           :dogfooding t)
          tools)
    (nreverse tools)))

(defun api-key-available-p (secret-name)
  "Check if SECRET-NAME is available via the Secrets Manager.
  Returns T if the secret exists and is accessible, NIL otherwise."
  (handler-case
      (when (and (hngh.plugins.secrets-manager:running-p)
                 (hngh.plugins.secrets-manager:backend-available-p))
        (multiple-value-bind (value reason)
            (hngh.plugins.secrets-manager:get-secret
             secret-name "ai-tool-hub")
          (when value
            (return-from api-key-available-p t))
          (unless (eq reason :not-authorized)
            nil)
          nil))
    (error () nil))
  nil)

;;; --- Tool lookup -----------------------------------------------------

(defun find-tool (tool-id)
  "Find a tool-info struct by TOOL-ID keyword.
  Returns the struct or NIL."
  (bt:with-lock-held (*tools-lock*)
    (find tool-id *tools* :key #'tool-info-id)))

;;; --- Public API: Lifecycle -------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the AI Tool Hub.
  Detects installed CLIs, loads cost log from state store,
  builds the tool registry."
  (setf *hngh-home* hngh-home
        *running* t)
  ;; Build tool registry by detecting installed CLIs
  (bt:with-lock-held (*tools-lock*)
    (setf *tools* (make-default-tool-registry)))
  (setf *next-invocation-id* 0)
  ;; Load persisted cost log from state store
  (load-cost-log)
  (hngh.core:log-info "AI Tool Hub initialized (~D tools available)"
                       (length (available-tools-list))))

(defun shutdown ()
  "Shut down the AI Tool Hub.
  Kills all running invocations, persists cost log, clears state."
  (setf *running* nil)
  ;; Kill all running invocations
  (let ((running-invocations
          (bt:with-lock-held (*invocations-lock*)
            (loop for inv in *invocations*
                  when (eq (invocation-info-status inv) :running)
                  collect inv))))
    (dolist (inv running-invocations)
      (handler-case (kill-invocation-internal inv)
        (error (c)
          (hngh.core:log-warn "AI Tool Hub: error killing invocation ~D: ~A"
                               (invocation-info-id inv) c)))))
  ;; Persist cost log
  (persist-cost-log)
  ;; Clear state
  (bt:with-lock-held (*tools-lock*)
    (setf *tools* nil))
  (bt:with-lock-held (*invocations-lock*)
    (setf *invocations* nil))
  (bt:with-lock-held (*cost-log-lock*)
    (setf *cost-log* nil))
  (setf *next-invocation-id* 0
        *hngh-home* nil)
  (hngh.core:log-info "AI Tool Hub shut down"))

(defun running-p ()
  "Return T if the AI Tool Hub is active."
  *running*)

(defun status ()
  "Return a plist describing the AI Tool Hub status."
  (list :running *running*
        :tools-count (bt:with-lock-held (*tools-lock*)
                       (length *tools*))
        :available-tools (available-tools-list)
        :active-invocations
        (bt:with-lock-held (*invocations-lock*)
          (count-if (lambda (inv) (eq (invocation-info-status inv) :running))
                    *invocations*))))

;;; --- Public API: Tools -----------------------------------------------

(defun list-tools ()
  "Return a list of tool-info structs from *tools* (shallow copy)."
  (bt:with-lock-held (*tools-lock*)
    (copy-list *tools*)))

(defun available-tools-list ()
  "Return a list of tool-id keywords for available tools."
  (bt:with-lock-held (*tools-lock*)
    (loop for tool in *tools*
          when (tool-info-available-p tool)
          collect (tool-info-id tool))))

(defun tool-capabilities (tool-id)
  "Return the capabilities list for TOOL-ID.
  Returns NIL if the tool is not found."
  (let ((tool (find-tool tool-id)))
    (when tool
      (tool-info-capabilities tool))))

(defun estimate-cost (tool-id task)
  "Estimate the cost of running TASK with TOOL-ID.
  For agentic CLIs: returns 0.0 (unknown, per-query/subscription).
  For direct API: estimates based on task length.
  Returns a number (USD)."
  (unless (stringp task)
    (return-from estimate-cost 0.0))
  (let ((tool (find-tool tool-id)))
    (unless tool
      (return-from estimate-cost 0.0))
    (ecase (tool-info-cost-model tool)
      ((:per-query :subscription :free) 0.0)
      (:per-token
       ;; Rough estimate: ~$0.003 per 1K tokens for Claude-class models
       ;; Assume ~4 chars per token, estimate output at 2x input
       (let* ((chars (length task))
              (token-estimate (max 1 (ceiling chars 4)))
              (total-tokens (* token-estimate 3)) ; input + output estimate
              (rate-per-1k (provider-rate (tool-info-id tool))))
         (* (/ total-tokens 1000) rate-per-1k))))))

(defun provider-rate (tool-id)
  "Return the approximate USD rate per 1K tokens for TOOL-ID's provider.
  Returns 0.0 if unknown."
  (case tool-id
    (:anthropic-api 0.003)   ; Claude Sonnet ~$3/MTok input, $15/MTok output
    (:openai-api 0.002)      ; GPT-4o ~$2.50/MTok input
    (:google-api 0.00125)   ; Gemini 1.5 Flash ~$0.15/MTok input
    (t 0.0)))

(defun select-tool (task &key prefer-tool prefer-tier max-cost privacy)
  "Select the best tool for TASK.
  Filters by availability, privacy constraints, cost cap.
  Prefers agentic CLI over direct API.
  Prefers PREFER-TOOL if specified and available.
  Returns a tool-id keyword or NIL if no suitable tool found."
  (unless (stringp task)
    (setf task ""))
  ;; If prefer-tool specified and available, return it
  (when prefer-tool
    (let ((tool (find-tool prefer-tool)))
      (when (and tool (tool-info-available-p tool))
        (return-from select-tool prefer-tool))))
  ;; Gather candidates
  (let ((candidates
          (bt:with-lock-held (*tools-lock*)
            (loop for tool in *tools*
                  when (tool-info-available-p tool)
                  collect tool))))
    ;; Filter by privacy (local-only)
    (when privacy
      (setf candidates
            (remove-if-not (lambda (tool)
                             (member :local (tool-info-providers tool)))
                           candidates)))
    ;; Filter by cost cap
    (when max-cost
      (setf candidates
            (remove-if (lambda (tool)
                         (> (estimate-cost (tool-info-id tool) task) max-cost))
                       candidates)))
    ;; Filter by prefer-tier (provider preference)
    (when prefer-tier
      (setf candidates
            (remove-if-not (lambda (tool)
                             (member prefer-tier (tool-info-providers tool)))
                           candidates)))
    (when (null candidates)
      (return-from select-tool nil))
    ;; Prefer agentic CLI over direct API
    (let ((agentic (remove-if-not (lambda (tool)
                                    (eq (tool-info-type tool) :agentic-cli))
                                  candidates)))
      (when agentic
        (setf candidates agentic)))
    ;; Prefer most capable (by length of capabilities list)
    (let ((best (first candidates)))
      (dolist (cand (rest candidates))
        (when (> (length (tool-info-capabilities cand))
                 (length (tool-info-capabilities best)))
          (setf best cand)))
      (tool-info-id best))))

;;; --- Public API: Invocation ------------------------------------------

(defun invoke (tool task &key context params workdir)
  "Invoke an AI tool to perform TASK.
  TOOL: keyword (:opencode, :claude, etc.) or nil (auto-select)
  TASK: string (task description)
  CONTEXT: plist (context package from AI Orchestrator)
  PARAMS: plist (:max-cost, :max-latency, :timeout, :env)
  WORKDIR: string or nil (working directory)
  Returns an invocation-info struct."
  (unless (running-p)
    (error "AI Tool Hub not running — call INIT first"))
  (unless (stringp task)
    (error "TASK must be a string"))
  ;; Auto-select tool if nil
  (let ((selected-tool (or tool (select-tool task))))
    (unless selected-tool
      (error "No suitable AI tool available for task: ~A" task))
    (let ((tool-info (find-tool selected-tool)))
      (unless tool-info
        (error "Tool ~A not found in registry" selected-tool))
      (unless (tool-info-available-p tool-info)
        (error "Tool ~A is not available" selected-tool))
      ;; Create invocation record
      (let* ((inv-id (bt:with-lock-held (*invocations-lock*)
                       (incf *next-invocation-id*)))
             (inv (make-invocation-info
                   :id inv-id
                   :tool selected-tool
                   :task task
                   :status :pending
                   :started-at (get-universal-time)
                   :cost 0.0
                   :pid nil
                   :workdir (or workdir (when *hngh-home*
                                          (namestring
                                           (merge-pathnames
                                            (format nil "agents/~D/" inv-id)
                                            *hngh-home*))))
                   :result nil
                   :error nil)))
        ;; Register invocation
        (bt:with-lock-held (*invocations-lock*)
          (push inv *invocations*))
         ;; Emit agent.spawned event
         (publish-event "agent.spawned"
                        (list :id inv-id
                              :invocation-id inv-id
                              :tool selected-tool
                              :task task
                              :timestamp (get-universal-time)))
        ;; Execute
        (setf (invocation-info-status inv) :running)
        (handler-case
            (let ((output (execute-tool tool-info task inv params)))
              (setf (invocation-info-status inv) :completed
                    (invocation-info-result inv) output)
              ;; Emit agent.completed event
              (publish-event "agent.completed"
                              (list :id inv-id
                                    :invocation-id inv-id
                                    :tool selected-tool
                                    :result output
                                    :cost (invocation-info-cost inv)
                                    :timestamp (get-universal-time)))
              ;; Log cost
              (log-cost-entry tool-info task inv t)
              inv)
          (error (c)
            (setf (invocation-info-status inv) :failed
                  (invocation-info-error inv) (princ-to-string c))
            ;; Emit agent.failed event
            (publish-event "agent.failed"
                            (list :id inv-id
                                  :invocation-id inv-id
                                  :tool selected-tool
                                  :reason :execution-error
                                  :error (princ-to-string c)
                                  :timestamp (get-universal-time)))
            ;; Log cost (failed)
            (log-cost-entry tool-info task inv nil)
            inv))))))

(defun execute-tool (tool-info task inv params)
  "Execute TOOL-INFO for TASK synchronously.
  Returns the captured stdout as a string.
  PARAMS is a plist with :max-cost, :max-latency, :timeout, :env.
  INV is the invocation-info struct."
  (let ((command (tool-info-command tool-info))
        (tool-id (tool-info-id tool-info))
        (workdir (invocation-info-workdir inv)))
    ;; Ensure workdir exists
    (when workdir
      (ensure-directories-exist (parse-namestring workdir)))
    (ecase (tool-info-type tool-info)
      (:agentic-cli
       (execute-agentic-cli tool-id command task workdir))
      (:direct-api
       (execute-direct-api tool-id task)))))

(defun execute-agentic-cli (tool-id command task workdir)
  "Run an agentic CLI tool with TASK.
  Returns captured stdout as a string."
  (let ((args (agentic-cli-args tool-id task)))
    (hngh.core:log-info "AI Tool Hub: executing ~A ~S" command args)
    (let ((proc nil))
      (handler-case
          (progn
            (setf proc
                  (if workdir
                      (sb-ext:run-program command args
                                          :output :stream
                                          :error :output
                                          :wait t
                                          :search t
                                          :directory (parse-namestring workdir))
                      (sb-ext:run-program command args
                                          :output :stream
                                          :error :output
                                          :wait t
                                          :search t)))
            (let ((stdout (read-stream-to-string
                           (sb-ext:process-output proc))))
              (when (null stdout)
                (setf stdout ""))
              ;; Check exit code
              (let ((exit-code (sb-ext:process-exit-code proc)))
                (when (and exit-code (not (zerop exit-code)))
                  (hngh.core:log-warn
                   "AI Tool Hub: ~A exited with code ~D" command exit-code)))
              stdout))
        (error (c)
          (when (and proc (sb-ext:process-p proc))
            (ignore-errors (sb-ext:process-close proc)))
          (error "Failed to execute ~A: ~A" command c))))))

(defun execute-direct-api (tool-id task)
  "Execute a direct API call using curl.
Returns captured stdout as a string."
  (let* ((api-key (get-api-key tool-id))
         (endpoint (api-endpoint tool-id))
         (model (default-model tool-id))
         (payload (format-json-payload tool-id model task))
         (headers (provider-api-headers tool-id api-key))
         (header-file nil)
         (payload-file nil))
    (unless api-key
      (error "No API key available for ~A" tool-id))
    (unwind-protect
         (progn
           (setf header-file
                 (write-temp-file
                  "headers"
                  (with-output-to-string (out)
                    (dolist (header headers)
                      (write-string header out)
                      (terpri out)))))
           (setf payload-file (write-temp-file "payload" payload))
           (hngh.core:log-info "AI Tool Hub: executing HTTP request to ~A" endpoint)
           (let* ((process
                    (sb-ext:run-program
                     "curl"
                     (list "-sS"
                           "--fail-with-body"
                           "--connect-timeout" "10"
                           "--max-time" "120"
                           endpoint
                           "-H" (format nil "@~A" header-file)
                           "--data-binary" (format nil "@~A" payload-file))
                     :output :stream
                     :error :output
                     :wait t
                     :search t))
                  (stdout (or (read-stream-to-string (sb-ext:process-output process)) ""))
                  (exit-code (sb-ext:process-exit-code process)))
             (unless (and exit-code (zerop exit-code))
               (error "Direct API call failed for ~A (exit ~A): ~A"
                      tool-id exit-code stdout))
             stdout))
      (when header-file
        (ignore-errors (delete-file header-file)))
      (when payload-file
        (ignore-errors (delete-file payload-file))))))

(defun agentic-cli-args (tool-id task)
  "Return the command-line arguments for an agentic CLI tool for TASK."
  (ecase tool-id
    (:opencode (list "--task" task))
    (:claude (list "-p" task))
    (:codex (list task))
    (:gemini (list task))
    (:cecli (list "--message" task))))

(defparameter *provider-endpoints*
  '((:anthropic-api . "https://api.anthropic.com/v1/messages")
    (:google-api . "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
    (:openai-api . "https://api.openai.com/v1/chat/completions")
    (:local-openai-api . "http://127.0.0.1:8888/v1/chat/completions"))
  "Provider endpoint map. Rebind/extend via config instead of editing code.")
(defun api-endpoint (tool-id)
  "Return the API endpoint URL for TOOL-ID."
  (or (cdr (assoc tool-id *provider-endpoints*))
      (error "Unknown tool ID: ~A" tool-id)))

(defun provider-api-headers (tool-id api-key)
  "Return a list of provider-specific HTTP header lines.
Each line is in the form expected by curl -H @file." 
  (unless (and api-key (plusp (length api-key)))
    (error "API key is empty for ~A" tool-id))
  (ecase tool-id
    (:anthropic-api
     (list (format nil "x-api-key: ~A" api-key)
           "anthropic-version: 2023-06-01"
           "content-type: application/json"))
    (:google-api
     (list (format nil "x-goog-api-key: ~A" api-key)
           "content-type: application/json"))
    (:openai-api
     (list (format nil "Authorization: Bearer ~A" api-key)
           "content-type: application/json"))
    (:local-openai-api
     (list (format nil "Authorization: Bearer ~A" api-key)
           "content-type: application/json"))))

(defun write-temp-file (prefix content)
  "Write CONTENT to a temporary file and return its pathname string." 
  (let* ((dir (uiop:temporary-directory))
         (name (format nil "hngh-~A-~D-~D.tmp"
                       prefix
                       (get-universal-time)
                       (random 1000000)))
         (path (merge-pathnames name dir)))
    (with-open-file (stream path
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :element-type 'character)
      (write-string (or content "") stream))
    (namestring path)))

(defun default-model (tool-id)
  "Return the default model name for TOOL-ID."
  (ecase tool-id
    (:anthropic-api "claude-sonnet-4-20250514")
    (:google-api "gemini-2.5-flash")
    (:openai-api "gpt-4o")
    (:local-openai-api "unsloth/gemma-4-12b-it-qat-GGUF")))

(defun format-json-payload (tool-id model task)
  "Format a JSON payload string appropriate for TOOL-ID.
  Returns a JSON string (hand-formatted since cl-json is not a dependency)."
  (ecase tool-id
    (:anthropic-api
     (format nil
             "{\"model\":\"~A\",\"max_tokens\":1024,\"messages\":[{\"role\":\"user\",\"content\":\"~A\"}]}"
             model (escape-json-string task)))
    (:google-api
     (format nil
             "{\"contents\":[{\"parts\":[{\"text\":\"~A\"}]}]}"
             (escape-json-string task)))
    (:openai-api
     (format nil
             "{\"model\":\"~A\",\"messages\":[{\"role\":\"user\",\"content\":\"~A\"}]}"
             model (escape-json-string task)))
    (:local-openai-api
     (format nil
             "{\"model\":\"~A\",\"messages\":[{\"role\":\"user\",\"content\":\"~A\"}]}"
             model (escape-json-string task)))))

(defun escape-json-string (str)
  "Escape a string for embedding in JSON. Handles double-quote, backslash,
newline, return, tab, and any other control character as \u00XX."
  (with-output-to-string (out)
    (loop for c across str do
      (case c
        (#\" (write-string "\\\"" out))
        (#\\ (write-string "\\\\" out))
        (#\Newline (write-string "\\n" out))
        (#\Return (write-string "\\r" out))
        (#\Tab (write-string "\\t" out))
        (t (let ((code (char-code c)))
             (if (< code 32)
                 (format out "\\u~4,'0X" code)
                 (write-char c out))))))))

(defun read-stream-to-string (stream)
  "Read all output from STREAM into a string.
  Returns NIL if the stream is closed or empty."
  (handler-case
      (with-output-to-string (out)
        (loop for line = (read-line stream nil nil)
              while line
              do (write-string line out)
              do (write-char #\Newline out)))
    (error () nil)))

(defun get-api-key (tool-id)
  "Retrieve the API key for TOOL-ID from the Secrets Manager.
  Returns the key string or NIL."
  (when (eq tool-id :local-openai-api)
    (return-from get-api-key (or (uiop:getenv "UNSLOTH_API_KEY") "local-dummy-key")))
  (let ((secret-name (ecase tool-id
                       (:anthropic-api :anthropic-api-key)
                       (:google-api :google-api-key)
                       (:openai-api :openai-api-key))))
    (handler-case
        (when (hngh.plugins.secrets-manager:running-p)
          (multiple-value-bind (value reason)
              (hngh.plugins.secrets-manager:get-secret
               secret-name "ai-tool-hub")
            (when value
              (return-from get-api-key value))
            (hngh.core:log-warn "AI Tool Hub: cannot get API key ~A: ~A"
                                 secret-name reason)
            nil))
      (error (c)
        (hngh.core:log-warn "AI Tool Hub: secrets manager error: ~A" c)
        nil))))

;;; --- Public API: Invocation management -------------------------------

(defun kill-invocation (id)
  "Kill the invocation with ID.
  Sends SIGTERM to the subprocess if running.
  Returns T on success, NIL if not found or not running."
  (let ((inv (find-invocation id)))
    (unless inv
      (return-from kill-invocation nil))
    (unless (eq (invocation-info-status inv) :running)
      (return-from kill-invocation nil))
    (kill-invocation-internal inv)
    ;; Emit agent.failed event
    (publish-event "agent.failed"
                    (list :id id
                          :invocation-id id
                          :tool (invocation-info-tool inv)
                          :reason :killed
                          :timestamp (get-universal-time)))
    t))

(defun kill-invocation-internal (inv)
  "Internal: kill the subprocess of INV, update status to :killed."
  (let ((pid (invocation-info-pid inv)))
    (when pid
      #+sbcl
      (handler-case
          (sb-ext:run-program "kill" (list (format nil "~D" pid))
                              :wait t :search t)
        (error (c)
          (hngh.core:log-warn "AI Tool Hub: failed to kill PID ~D: ~A" pid c)))))
  (setf (invocation-info-status inv) :killed))

(defun find-invocation (id)
  "Find an invocation-info struct by ID.
  Returns the struct or NIL."
  (bt:with-lock-held (*invocations-lock*)
    (find id *invocations* :key #'invocation-info-id)))

(defun list-invocations ()
  "Return a list of invocation-info structs (shallow copy)."
  (bt:with-lock-held (*invocations-lock*)
    (copy-list *invocations*)))

;;; --- Public API: Cost tracking ---------------------------------------

(defun cost-log ()
  "Return a list of cost log entries (shallow copy)."
  (bt:with-lock-held (*cost-log-lock*)
    (copy-list *cost-log*)))

(defun log-cost-entry (tool-info task inv success-p)
  "Append a cost entry to *cost-log*.
  For agentic CLIs: cost = 0.0 (unknown, subscription-based).
  For direct API: uses estimated token cost.
  Persists to state store."
  (let* ((tool-id (tool-info-id tool-info))
         (provider (tool-provider tool-info))
         (model (default-model tool-id))
         (cost (if success-p (invocation-info-cost inv)
                   (estimate-cost tool-id task)))
         (entry (list :timestamp (get-universal-time)
                      :tool tool-id
                      :provider provider
                      :model model
                      :tokens-in (length task)   ; rough char count
                      :tokens-out (if success-p 256 0)
                      :cost-usd cost
                      :task-hash (format nil "~X" (sxhash task))
                      :success success-p)))
    (bt:with-lock-held (*cost-log-lock*)
      (push entry *cost-log*))
    ;; Persist to state store
    (persist-cost-log)
    entry))

(defun tool-provider (tool-info)
  "Return the primary provider keyword for TOOL-INFO."
  (let ((providers (tool-info-providers tool-info)))
    (if providers (first providers) :unknown)))

(defun persist-cost-log ()
  "Write *cost-log* to the state store."
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (handler-case
        (hngh.core.state-store:write-state
         (cost-log-path)
         (bt:with-lock-held (*cost-log-lock*)
           (reverse *cost-log*)))
      (error (c)
        (hngh.core:log-warn "AI Tool Hub: failed to persist cost log: ~A" c)))))

(defun load-cost-log ()
  "Load the cost log from the state store into *cost-log*."
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (when (hngh.core.state-store:state-exists-p (cost-log-path))
      (handler-case
          (let ((raw (hngh.core.state-store:read-state (cost-log-path))))
            (when (and raw (listp raw))
              (bt:with-lock-held (*cost-log-lock*)
                (setf *cost-log* (reverse raw))))
            (hngh.core:log-debug "AI Tool Hub: loaded ~D cost log entries"
                                  (length *cost-log*)))
        (error (c)
          (hngh.core:log-warn
           "AI Tool Hub: failed to load cost log: ~A; starting with empty log" c))))))
