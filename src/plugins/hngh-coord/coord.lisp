;;;; src/plugins/hngh-coord/coord.lisp — squad coordination plane (card 101).
;;;;
;;;; Any-number-of-agents coordinator: two faces, one append-only store —
;;;;   MCP face (Content-Length framing — the stock cxxxr/jsonrpc stdio
;;;;   transport IS MCP framing; registered as the :mcp mode below),
;;;;   ACP face (newline-delimited JSON — the shipped :acp mode from
;;;;   acp-transport.lisp).
;;;;
;;;; Not a control plane: no session driving, no process parentage. Seats
;;;; stay normal Hermes sessions; this is the auditable channel through
;;;; which Hngh's autonomy loop observes and steers agents.
;;;;
;;;; Store: state-store journal "coord/messages" — append-only Lisp forms
;;;; (one per line), compatible with read-journal and the card-94 audit
;;;; story. Entry shape:
;;;;   (:ts <unix> :from <id> :to <id|*> :kind <string> :body <string>
;;;;    :id "coord-0001")

(defpackage :hngh.plugins.hngh-coord
  (:documentation "Squad coordination plane (card 101): MCP + ACP faces,
one append-only journal. Agents register, post messages, read inboxes,
report status. The channel through which Hngh's autonomy loop observes
and steers squads.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:serve-mcp
           #:serve-acp
           #:post-message
           #:read-inbox
           #:coord-view
           #:*agent-id*))

(in-package #:hngh.plugins.hngh-coord)

(defvar *running* nil)
(defvar *agent-id* "coordinator"
  "Agent identity for MCP tools; overridable via --agent.")
(defvar *journal-name* "coord/messages")
(defvar *msg-seq* 0)

(defun %ensure-store ()
  "state-store:init must be called once for *hngh-home*; the coordinator is
self-contained (standalone tests, MCP launch) so we bind it to the daemon
default when nil rather than failing on a NIL pathname."
  (unless (hngh.core.state-store:running-p)
    (hngh.core.state-store:init)))

(defun %next-id ()
  (incf *msg-seq*)
  (format nil "coord-~4,'0D" *msg-seq*))

(defun post-message (from to kind body)
  "Append one message to the coordinator journal. Returns the entry."
  (%ensure-store)
  (let* ((entry (list :ts (get-universal-time)
                      :from from
                      :to to
                      :kind kind
                      :body body
                      :id (%next-id))))
    (hngh.core.state-store:append-journal *journal-name* entry)
    entry))

(defun read-inbox (for-id)
  "Return messages addressed to FOR-ID (or broadcast), oldest first."
  (%ensure-store)
  (remove-if-not (lambda (entry)
                   (let ((to (getf entry :to)))
                     (or (equal to for-id) (equal to "*"))))
                 (hngh.core.state-store:read-journal *journal-name*)))

(defun coord-view ()
  "Coordinator view: registered agents + recent activity."
  (%ensure-store)
  (let ((agents nil)
        (message-count 0))
    (dolist (entry (hngh.core.state-store:read-journal *journal-name*))
      (incf message-count)
      (let* ((from (getf entry :from))
             (cell (assoc from agents :test #'equal)))
        (cond (cell (setf (cdr cell) (1+ (cdr cell))))
              (t (push (cons from 1) agents)))))
    (let ((lines (list "agents:")))
      (dolist (agent-cell (sort agents #'string< :key #'car))
        (push (format nil "  ~A: ~D msgs" (car agent-cell) (cdr agent-cell))
              lines))
      (setf lines (nreverse lines))
      (format nil "~{~A~%~}messages: ~D" lines message-count))))

(in-package #:hngh.plugins.hngh-coord)

(defun %mcp-object (&rest pairs)
  "Build a string-keyed hash-table (JSON object) from even-length KEY VALUE
pairs. yason encodes hash-tables as objects; alists would be walked as
arrays and dump the dotted tail (seen: initialize crash on the wire)."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on pairs by #'cddr
          do (setf (gethash k h) v))
    h))

(defun %mcp-tool (name desc props required)
  "Build one MCP tool descriptor as a hash-table (yason emits objects for
hash-tables; keyword keys would need a symbol policy yason lacks)."
  (%mcp-object "name" name
               "description" desc
               "inputSchema" (%mcp-object "type" "object"
                                          "properties" props
                                          "required" required)))

(defun mcp-server (handler)
  "Build an MCP server: same JSON-RPC server machinery as the ACP server
but with the STOCK transport, whose stdio framing is LSP-style
Content-Length — which IS the MCP framing. Exposes the coordinator tools.
Return values are yason-safe hash-tables (see %MCP-OBJECT)."
  (let ((server (make-instance 'jsonrpc:server)))

    (jsonrpc:expose
     server "tools/list"
     (lambda (params)
       (declare (ignore params))
       (%mcp-object
        "tools"
        (list
         (%mcp-tool "register" "join the squad"
                    (%mcp-object "agent_id" (%mcp-object "type" "string")
                                 "role" (%mcp-object "type" "string"))
                    (list "agent_id"))
         (%mcp-tool "post_message" "deliver a message to an agent"
                    (%mcp-object "to" (%mcp-object "type" "string")
                                 "kind" (%mcp-object "type" "string")
                                 "body" (%mcp-object "type" "string"))
                    (list "to" "kind" "body"))
         (%mcp-tool "read_inbox" "read messages addressed to me"
                    (%mcp-object "agent_id" (%mcp-object "type" "string"))
                    nil)
         (%mcp-tool "status" "coordinator view" nil nil)
         (%mcp-tool "steer" "inject a coordination note"
                    (%mcp-object "agent_id" (%mcp-object "type" "string")
                                 "text" (%mcp-object "type" "string"))
                    (list "agent_id" "text"))))))

    (jsonrpc:expose
     server "tools/call"
     (lambda (params)
       (let* ((name (gethash "name" params))
              (args (gethash "arguments" params))
              (args (or args (make-hash-table :test #'equal)))
              (result (funcall handler name args)))
         (%mcp-object
          "content"
          (list
           (%mcp-object "type" "text"
                        "text" result))))))

    (jsonrpc:expose
     server "initialize"
     (lambda (params)
       (%mcp-object
        "protocolVersion" (or (gethash "protocolVersion" params)
                              "2024-11-05")
        "capabilities" (%mcp-object "tools" nil)
        "serverInfo" (%mcp-object "name" "hngh-coord"
                                  "version" "0.1.0"))))

    ;; notifications/initialized is a notification — returning a result
    ;; would mislead; expose a no-op handler so it isn't 'unknown method'.
    (jsonrpc:expose
     server "notifications/initialized"
     (lambda (params) (declare (ignore params)) nil))

    server))

(defun handle-tool-call (name args)
  "Dispatch an MCP tools/call. ARGS is a hash-table of string keys."
  (flet ((arg (k) (gethash k args)))
    (cond
      ((equal name "register")
       (let ((agent (or (arg "agent_id") *agent-id*)))
         (post-message agent "*" "state"
                       (format nil "registered role=~A" (or (arg "role") "unknown")))
         (format nil "registered ~A" agent)))
      ((equal name "post_message")
       (post-message (or (arg "from") *agent-id*)
                     (or (arg "to") "*")
                     (or (arg "kind") "note")
                     (or (arg "body") ""))
       "posted")
      ((equal name "read_inbox")
       (let ((me (or (arg "agent_id") *agent-id*)))
         (let ((inbox (read-inbox me)))
           (if (null inbox)
               "(empty)"
               (format nil "~{~A~%~}"
                       (mapcar (lambda (e)
                                 (format nil "[~D] ~A ~A: ~A"
                                         (getf e :ts) (getf e :from)
                                         (getf e :kind) (getf e :body)))
                               inbox))))))
      ((equal name "status")
       (coord-view))
      ((equal name "steer")
       (post-message "coordinator" (or (arg "agent_id") "*") "steer"
                     (or (arg "text") ""))
       "steer delivered")
      (t (error "unknown tool: ~A" name)))))

(defun serve-mcp (&key (input *standard-input*) (output *standard-output*)
                       (log-stream *error-output*))
  "Run the MCP face on INPUT/OUTPUT (default stdio). The stock
JSON-RPC stdio transport uses LSP-style Content-Length framing — which
IS the MCP framing — so :mode :stdio is exactly the MCP transport
(framing per the mcp-server-setup 2026-08-08 lesson: MCP Content-Length
vs ACP newline are NOT interchangeable). LOG-STREAM receives logger
output; MCP OUTPUT carries ONLY Content-Length frames, so logs must not
share that stream (default: *error-output*). Blocks until the stream
closes."
  (let* ((mcp-in (or input *standard-input*))
         (mcp-out (or output *standard-output*))
         (server (mcp-server #'handle-tool-call))
         (*standard-output* (or log-stream *error-output*)))
    (jsonrpc:server-listen server :mode :stdio
                           :input mcp-in :output mcp-out)))

;;; --- ACP face (newline framing, shipped transport) -------------------------

(defun acp-server (handler)
  "Build an ACP server exposing coordinator methods (coord/post,
coord/status). Mirrors acp-client.lisp's acp-make-server shape: hash-table
results (keyword plists would be walked as a JSON array by yason's list
encoder and the symbol keys crash the encoder — same trap as the MCP face)."
  (declare (ignore handler))
  (let ((server (make-instance 'jsonrpc:server)))
    (jsonrpc:expose
     server "initialize"
     (lambda (params)
       (declare (ignore params))
       (%mcp-object "protocolVersion" 1
                    "agentCapabilities" (%mcp-object "loadSession" nil)
                    "agentInfo" (%mcp-object "name" "hngh-coord"
                                             "version" "0.1.0"))))
    (jsonrpc:expose
     server "coord/post"
     (lambda (params)
       (post-message (or (gethash "from" params) "acp")
                     (or (gethash "to" params) "*")
                     (or (gethash "kind" params) "note")
                     (or (gethash "body" params) ""))
       (%mcp-object "posted" t)))
    (jsonrpc:expose
     server "coord/status"
     (lambda (params)
       (declare (ignore params))
       (%mcp-object "status" (coord-view))))
    server))

(defun serve-acp (&key (input *standard-input*) (output *standard-output*)
                       (log-stream *error-output*))
  "Run the ACP face on INPUT/OUTPUT (default stdio). Newline framing — the
shipped :acp mode from acp-transport.lisp. LOG-STREAM receives logger
output; the ACP wire carries ONLY newline-delimited JSON lines, so logs
must not share it (default: *error-output*). Blocks until the stream
closes."
  (let ((server (acp-server nil))
        (*standard-output* (or log-stream *error-output*)))
    (jsonrpc:server-listen server :mode :acp
                           :input input :output output)))

;;; --- Plugin lifecycle -----------------------------------------------------

(defun init (&key agent-id)
  (when agent-id
    (setf *agent-id* agent-id))
  (setf *running* t)
  (hngh.core:log-info "hngh-coord initialized (agent ~A)" *agent-id*)
  t)

(defun shutdown ()
  (setf *running* nil)
  t)

(defun running-p () *running*)

(defun status ()
  (if *running*
      (format nil "hngh-coord: ready (agent ~A, journal ~A)" *agent-id* *journal-name*)
      "hngh-coord: inactive"))