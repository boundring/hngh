;;;; src/plugins/acp-client.lisp — ACP client (Wave A1)
;;;;
;;;; Hngh as an Agent-Client-Protocol CLIENT: drive any ACP-capable agent
;;;; (Hermes, opencode, Gemini CLI, Claude Code via adapter) over stdio
;;;; JSON-RPC. Design: docs/design/agent-client-protocol.md.
;;;;
;;;; One uniform surface for observe (session/update), steer
;;;; (session/prompt), pause (session/cancel), and gate (session/request_
;;;; permission), with capability negotiation (steer vs queue vs interrupt)
;;;; parsed at initialize — never assumed.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.acp-client)

(defvar *running* nil
  "Whether the ACP client plugin is active.")

(defparameter *protocol-version* 1
  "ACP MAJOR protocol version this client supports (single integer).")

;;; --- Connection -----------------------------------------------------------

(defclass acp-connection ()
  ((client :initarg :client :accessor acp-client
           :documentation "Underlying cxxxr/jsonrpc client.")
   (input :initarg :input :accessor acp-input
          :documentation "Stream we read agent messages from.")
   (output :initarg :output :accessor acp-output
           :documentation "Stream we write request messages to.")
   (agent-info :initform nil :accessor acp-agent-info
               :documentation "Parsed agentInfo from initialize.")
   (agent-capabilities :initform nil :accessor acp-agent-capabilities
                       :documentation "Parsed agentCapabilities from initialize."))
  (:documentation "A live ACP connection to one agent subprocess."))

(defun acp-connect-stdio (input output)
  "Create an ACP connection whose transport is the stdio streams INPUT/
OUTPUT (a spawned agent subprocess's pipes). Returns an ACP-CONNECTION with
its JSON-RPC client connected over stdio."
  (let ((client (jsonrpc:make-client)))
    (jsonrpc:client-connect client :mode :stdio
                            :input input :output output)
    (make-instance 'acp-connection
                   :client client :input input :output output)))

(defun acp-disconnect (conn)
  "Disconnect and release the ACP connection."
  (when (and conn (acp-client conn))
    (ignore-errors (jsonrpc:client-disconnect (acp-client conn))))
  t)

;;; --- Message helpers ------------------------------------------------------

(defun %ht (&rest pairs)
  "Build an order-insensitive string-keyed hash-table (JSON object) from
even-length KEY VALUE pairs. Keys are used verbatim — ACP wire keys are
camelCase ('protocolVersion', 'sessionId') and must NOT be downcased."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on pairs by #'cddr
          do (setf (gethash k h) v))
    h))

(defun %call (conn method params &key (timeout 60))
  "Issue a JSON-RPC call METHOD with PARAMS (hash-table) and return result."
  (jsonrpc:call (acp-client conn) method params :timeout timeout))

(defun %notify (conn method params)
  "Issue a JSON-RPC notification METHOD with PARAMS (no response expected)."
  (jsonrpc:notify (acp-client conn) method params))

;;; --- Initialization / capability negotiation ------------------------------

(defun acp-initialize (conn &key (client-name "hngh") (client-version "0.0.1"))
  "Handshake with the agent: negotiate protocol version + capabilities.
Parses agentInfo and agentCapabilities into the connection. Returns the
initialize result alist. Raises on version mismatch."
  (let* ((params (%ht "protocolVersion" *protocol-version*
                      "clientCapabilities" (%ht "fs" (%ht "readTextFile" t
                                                          "writeTextFile" t)
                                                "terminal" t)
                      "clientInfo" (%ht "name" client-name
                                        "title" "Hngh ACP client"
                                        "version" client-version)))
         (result (%call conn "initialize" params)))
    (setf (acp-agent-capabilities conn)
          (gethash "agentCapabilities" result)
          (acp-agent-info conn)
          (gethash "agentInfo" result))
    (let ((agent-version (gethash "protocolVersion" result)))
      (when (and (integerp agent-version)
                 (/= agent-version *protocol-version*))
        (error "ACP protocol version mismatch: client ~D, agent ~D"
               *protocol-version* agent-version)))
    result))

(defun acp-capability (conn key &optional (default nil))
  "Read capability KEY (string, dotted path) from agentCapabilities."
  (let ((caps (acp-agent-capabilities conn)))
    (let ((val (loop for part in (and caps (cl-ppcre:split "\\." key))
                     for cur = caps then (gethash part (or cur (make-hash-table)))
                     finally (return (if (typep cur 'hash-table) nil cur)))))
      (if val val default))))

;;; Mid-turn steering mode — the negotiate-don't-assume core of the design.
(defun acp-midturn-mode (conn)
  "Decide the mid-turn steering mode for this agent from its advertised
capabilities. Returns one of:
  :steer     — agent supports in-turn injection (we can send during a turn)
  :interrupt — no injection; use session/cancel + fresh session/prompt
  :unknown   — capabilities unknown (initialize not yet done)
Never assumes: absence of an injection capability => :interrupt."
  (let ((caps (acp-agent-capabilities conn)))
    (cond
      ((null caps) :unknown)
      ;; If agent advertises a mid-turn/prompt-injection capability, we can
      ;; steer. ACP v1 baseline does not yet standardize 'steer', so this
      ;; signals an extension payload; default to interrupt when absent.
      ((gethash "steer" (or caps (make-hash-table))) :steer)
      (t :interrupt))))

(defun acp-extract-text (content)
  "Extract the concatenated text from ACP session/prompt CONTENT — a list of
content blocks (each a hash-table with a :type and :text), or a single
hash-table. Returns a string (possibly empty)."
  (if (listp content)
      (apply #'concatenate 'string
             (loop for block in content
                   for text = (and (hash-table-p block) (gethash "text" block))
                   when (stringp text) collect text))
      (or (and (hash-table-p content) (gethash "text" content)) "")))

;;; --- Session lifecycle ----------------------------------------------------

(defun acp-session-new (conn &key cwd mcp-servers title)
  "Create a new ACP session. Returns the session id, or signals on error."
  (let* ((params (%ht "cwd" (or cwd "/")))
         result)
    (when mcp-servers (setf (gethash "mcpServers" params) mcp-servers))
    (when title (setf (gethash "title" params) title))
    (setf result (%call conn "session/new" params))
    (gethash "sessionId" result)))

(defun acp-session-load (conn &key cwd session-id)
  "Resume an existing session (requires loadSession capability)."
  (let ((result (%call conn "session/load"
                       (%ht "cwd" (or cwd "/") "sessionId" session-id))))
    (gethash "sessionId" result)))

(defun acp-prompt (conn session-id text &key (timeout 300))
  "Send a user message TEXT to SESSION-ID, waiting for the turn to end.
Returns the session/prompt response (stop reason + content)."
  (%call conn "session/prompt"
         (%ht "sessionId" session-id
              "prompt" (list (%ht "type" "text" "text" text)))
         :timeout timeout))

(defun acp-cancel (conn session-id)
  "Cancel ongoing work in SESSION-ID (notification — no response)."
  (%notify conn "session/cancel" (%ht "sessionId" session-id)))

(defun acp-request-permission (conn session-id response)
  "Respond to a pending permission request with RESPONSE (true/false).
Called by the human-gate path after scoring/approval."
  (%call conn "session/request_permission"
         (%ht "sessionId" session-id "response" response)))

;;; --- Inbound notification handling (session/update) -----------------------

(defun acp-register-update-handler (conn handler)
  "Register HANDLER to be called with each inbound session/update payload
(agent message chunks, tool calls, plans). HANDLER is (lambda (update-plist))."
  (jsonrpc:expose (acp-client conn) "session/update"
                  (lambda (update)
                    (funcall handler update)
                    ;; Notifications expect no reply; returning nil is fine.
                    nil))
  t)

;;; --- Plugin lifecycle -----------------------------------------------------

(defvar *spawn-timeout* 30
  "Seconds to wait for an agent subprocess to become ready (init handshake).")

(defun acp-run-task-on-connection (conn task &key (cwd "/") (timeout 300))
  "Dispatch driver core (Wave A2), operating on an already-connected
ACPCONNECTION: initialize, create a session, prompt with TASK, capture the
turn result + any session/update observation count. Register the update
handler BEFORE prompting — the agent's session/update notifications arrive
DURING the turn and the reading thread would throw on an unknown inbound
method if no handler is registered yet.

Returns:
  (:status :done|:failed :result <text> :session-id <id>
   :stop-reason <kw-or-nil> :error <msg-or-nil> :observations <n>)

Fail-closed: any unhandled condition returns :failed, never hangs."
  (handler-case
      (progn
        (acp-initialize conn)
        (let* ((sid (acp-session-new conn :cwd cwd))
               (obs-lock (bt:make-lock "acp-obs"))
               (obs-count 0))
          (acp-register-update-handler
           conn (lambda (u)
                  (declare (ignore u))
                  (bt:with-lock-held (obs-lock) (incf obs-count))))
          (let ((resp (acp-prompt conn sid task :timeout timeout)))
            (list :status :done
                  :result (acp-extract-text (gethash "content" resp))
                  :session-id sid
                  :stop-reason (and (gethash "stopReason" resp)
                                    (intern (string-upcase (gethash "stopReason" resp))
                                            :keyword))
                  :error nil
                  :observations obs-count))))
    (condition (c)
      (list :status :failed :result nil :session-id nil
            :stop-reason nil :error (princ-to-string c) :observations 0))))

(defun acp-run-task (command task &key (cwd "/") (timeout 300) (spawn-timeout *spawn-timeout*))
  "Run TASK through an ACP agent subprocess spawned by COMMAND (a list of
program + args, e.g. '(\"opencode\" \"acp\")). Spawns the agent, connects over
stdio, then delegates to ACP-RUN-TASK-ON-CONNECTION, and tears down the
subprocess (disconnect + terminate). Returns the same result plist.
Fail-closed: a command that cannot launch returns :failed, never throws."
  (declare (ignore spawn-timeout))
  (handler-case
      (let* ((proc (uiop:launch-program command
                                        :input :stream :output :stream :error :output
                                        :wait nil))
             (input (uiop:process-info-input proc))
             (output (uiop:process-info-output proc))
             (conn nil)
             (result nil))
        (unwind-protect
            (progn
              (setf conn (acp-connect-stdio output input))
              (setf result (acp-run-task-on-connection conn task
                                                       :cwd cwd :timeout timeout))
              result)
          (when conn (ignore-errors (acp-disconnect conn)))
          (ignore-errors (uiop:terminate-process proc))))
    (condition (c)
      (list :status :failed :result nil :session-id nil
            :stop-reason nil :error (princ-to-string c) :observations 0))))

;;; --- Plugin lifecycle -----------------------------------------------------

(defun init ()
  (setf *running* t)
  (hngh.core:log-info "ACP client initialized (protocol v~D)" *protocol-version*)
  t)

(defun shutdown ()
  (setf *running* nil)
  t)

(defun running-p () *running*)

(defun status ()
  (if *running*
      (format nil "acp-client: ready (protocol v~D, steer-via-negotiation)"
              *protocol-version*)
      "acp-client: inactive"))
