;;;; core/daemon.lisp — Hngh Headless Daemon Core
;;;;
;;;; Unix socket server, client handling, event broadcast.
;;;; Owns the event loop, scheduler, state store, plugin host.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.daemon)

;;; --- Dependencies ---------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-bsd-sockets)
  (require :babel))

;;; --- State ----------------------------------------------------------------

(defvar *daemon-socket-path* "daemon/socket"
  "Unix socket path relative to *hngh-home*.")

(defvar *daemon-server* nil
  "The listening socket (SB-BSD-SOCKETS:SOCKET).")

(defvar *client-connections* (make-hash-table :test 'equal)
  "Map of client-id -> connection info plist, including a per-stream write lock.")

(defvar *client-lock* (bt:make-lock "hngh-daemon-clients")
  "Mutex protecting *client-connections*.")

(defvar *next-client-id* 0
  "Monotonic client ID counter.")

(defvar *daemon-running* nil
  "T when daemon is accepting connections.")

(defvar *request-handlers* (make-hash-table :test 'eq)
  "Map of operation keyword -> handler function.
Handler signature: (handler client-id request-msg) -> response-plist.")

(defvar *event-subscribers* (make-hash-table :test 'equal)
  "Map of topic -> list of client-ids subscribed to that topic.")

(defvar *event-lock* (bt:make-lock "hngh-daemon-events")
  "Mutex protecting *event-subscribers*.")

(defvar *accept-thread* nil
  "Thread running the server accept loop.")

(defvar *active-socket-path* nil
  "Absolute pathname currently bound by the daemon.")

(defvar *event-bus-subscription* nil
  "Event bus subscription used to bridge internal events to daemon clients.")

;;; --- Socket Path Resolution -----------------------------------------------

(defun default-hngh-home ()
  "Return the configured Hngh home without requiring its variable at compile time."
  (let ((symbol (find-symbol "*HNGH-HOME*" :hngh)))
    (if (and symbol (boundp symbol))
        (symbol-value symbol)
        (merge-pathnames ".hngh/" (user-homedir-pathname)))))

(defun daemon-socket-path (&optional (hngh-home (default-hngh-home)))
  "Resolve the absolute socket path."
  (merge-pathnames *daemon-socket-path* hngh-home))

(defun ensure-socket-dir (&optional (hngh-home (default-hngh-home)))
  "Ensure the socket directory exists."
  (let ((dir (merge-pathnames "daemon/" hngh-home)))
    (ensure-directories-exist dir)
    dir))

;;; --- Client Management ----------------------------------------------------

(defun register-client (stream)
  "Register a new client connection. Returns client-id."
  (bt:with-lock-held (*client-lock*)
    (let ((id (incf *next-client-id*)))
      (setf (gethash id *client-connections*)
            (list :stream stream
                  :thread (bt:current-thread)
                  :write-lock (bt:make-lock (format nil "hngh-client-~D-write" id))
                  :connected-at (get-universal-time)
                  :last-heartbeat (get-universal-time)))
      id)))

(defun unregister-client (client-id)
  "Remove a client connection and its subscriptions."
  (bt:with-lock-held (*client-lock*)
    (let ((conn (gethash client-id *client-connections*)))
      (when conn
        (ignore-errors (close (getf conn :stream)))
        (remhash client-id *client-connections*))))
  (bt:with-lock-held (*event-lock*)
    (maphash (lambda (topic subscribers)
               (setf (gethash topic *event-subscribers*)
                     (remove client-id subscribers)))
             *event-subscribers*)))

(defun get-client-stream (client-id)
  "Get the stream for a client ID."
  (bt:with-lock-held (*client-lock*)
    (getf (gethash client-id *client-connections*) :stream)))

(defun write-client-message (client-id encoded)
  "Write one encoded frame atomically to CLIENT-ID. Return T on success."
  (let ((connection (bt:with-lock-held (*client-lock*)
                      (copy-list (gethash client-id *client-connections*)))))
    (when connection
      (bt:with-lock-held ((getf connection :write-lock))
        (write-sequence encoded (getf connection :stream))
        (force-output (getf connection :stream)))
      t)))

(defun update-client-heartbeat (client-id)
  "Update the last-heartbeat timestamp for a client."
  (bt:with-lock-held (*client-lock*)
    (let ((conn (gethash client-id *client-connections*)))
      (when conn
        (setf (getf conn :last-heartbeat) (get-universal-time))))))

(defun list-connected-clients ()
  "Return a list of connected client IDs."
  (bt:with-lock-held (*client-lock*)
    (loop for id being the hash-keys of *client-connections* collect id)))

;;; --- Event Subscription ---------------------------------------------------

(defun subscribe-client (client-id topic)
  "Subscribe a client to a topic."
  (bt:with-lock-held (*event-lock*)
    (pushnew client-id (gethash (canonical-topic topic) *event-subscribers*))))

(defun unsubscribe-client (client-id topic)
  "Unsubscribe a client from a topic."
  (bt:with-lock-held (*event-lock*)
    (let* ((key (canonical-topic topic))
           (subscribers (gethash key *event-subscribers*)))
      (when subscribers
        (let ((remaining (remove client-id subscribers)))
          (if remaining
              (setf (gethash key *event-subscribers*) remaining)
              (remhash key *event-subscribers*)))))))

(defun canonical-topic (topic)
  "Normalize a wire or event-bus topic to a lowercase string."
  (cond
    ((eq topic :all) "*")
    ((keywordp topic) (string-downcase (symbol-name topic)))
    ((stringp topic) (string-downcase topic))
    (t (error "Event topic must be a keyword or string: ~S" topic))))

(defun topic-subscribers (topic)
  "Return a snapshot of clients subscribed to TOPIC, including wildcards."
  (let ((canonical (canonical-topic topic)))
    (bt:with-lock-held (*event-lock*)
      (remove-duplicates
       (loop for pattern being the hash-keys of *event-subscribers*
               using (hash-value subscribers)
             when (hngh.core.event-bus:topic-match-p pattern canonical)
               append (copy-list subscribers))))))

(defun broadcast-event (topic payload)
  "Send an event to all clients subscribed to TOPIC."
  (let ((encoded (hngh.core.wire-protocol:encode-event topic payload))
        (failed '())
        (subscribers (topic-subscribers topic)))
    (dolist (client-id subscribers)
      (handler-case
          (write-client-message client-id encoded)
        (error (c)
          (hngh.core:log-debug "Failed to send event to client ~D: ~A" client-id c)
          (push client-id failed))))
    (dolist (client-id failed)
      (unregister-client client-id))
    (- (length subscribers) (length failed))))

(defun bridge-event (event)
  "Forward one internal event-bus EVENT to subscribed daemon clients."
  (broadcast-event (hngh.core.event-bus:event-topic event)
                   (hngh.core.event-bus:event-payload event)))

(defun start-event-bridge ()
  "Subscribe the daemon to all internal event-bus events."
  (when (and (hngh.core.event-bus:running-p)
             (null *event-bus-subscription*))
    (setf *event-bus-subscription*
          (hngh.core.event-bus:subscribe "*" #'bridge-event :drop-policy :drop))))

(defun stop-event-bridge ()
  "Remove the internal event-bus bridge subscription."
  (when *event-bus-subscription*
    (ignore-errors (hngh.core.event-bus:unsubscribe *event-bus-subscription*))
    (setf *event-bus-subscription* nil)))

;;; --- Request Handling -----------------------------------------------------

(defun register-request-handler (op handler)
  "Register a handler function for operation OP.
HANDLER: (client-id request-msg) -> response-plist"
  (setf (gethash op *request-handlers*) handler))

(defun default-request-handler (client-id request-msg)
  "Default handler for unknown operations."
  (declare (ignore client-id))
  (hngh.core.wire-protocol:make-response
   (hngh.core.wire-protocol:request-id request-msg)
   :error
   :result (format nil "Unknown operation: ~A" (hngh.core.wire-protocol:request-op request-msg))))

(defun handle-request (client-id request-msg)
  "Dispatch a request to the appropriate handler."
  (let* ((op (hngh.core.wire-protocol:request-op request-msg))
         (handler (gethash op *request-handlers*)))
    (if handler
        (handler-case
            (funcall handler client-id request-msg)
          (error (c)
            (hngh.core:log-error "Handler for ~A failed: ~A" op c)
            (hngh.core.wire-protocol:make-response
             (hngh.core.wire-protocol:request-id request-msg)
             :error
             :result (format nil "Handler error: ~A" c))))
        (default-request-handler client-id request-msg))))

;;; --- Client Connection Loop -----------------------------------------------

(defun client-connection-loop (client-id stream)
  "Main loop for a single client connection. Runs in its own thread."
  (unwind-protect
      (handler-case
          (loop
            (multiple-value-bind (msg err) (hngh.core.wire-protocol:read-message stream)
              (when err
                (case err
                  (:eof (hngh.core:log-info "Client ~D disconnected (EOF)" client-id))
                  (:error (hngh.core:log-warn "Client ~D protocol error" client-id)))
                (return))
              (update-client-heartbeat client-id)
              (cond
                ((hngh.core.wire-protocol:request-p msg)
                 (let ((response (handle-request client-id msg)))
                   (write-client-message
                    client-id (hngh.core.wire-protocol:encode-message response))))
                ((hngh.core.wire-protocol:event-p msg)
                 (hngh.core:log-debug "Client ~D sent event (unexpected): ~A" client-id msg))
                (t
                 (hngh.core:log-warn "Client ~D sent unknown message type: ~A" client-id msg)))))
        (error (condition)
          (when *daemon-running*
            (hngh.core:log-warn "Client ~D connection error: ~A"
                                client-id condition))))
    (unregister-client client-id)
    (hngh.core:log-info "Client ~D connection closed" client-id)))

(defun accept-loop ()
  "Main accept loop for the daemon server socket. Runs in its own thread."
  (handler-case
      (loop while *daemon-running* do
        (handler-case
            (let ((client-socket (sb-bsd-sockets:socket-accept *daemon-server*)))
              (let ((stream (sb-bsd-sockets:socket-make-stream client-socket
                                                               :input t :output t
                                                               :element-type '(unsigned-byte 8)
                                                               :buffering :full)))
                (let ((client-id (register-client stream)))
                  (hngh.core:log-info "Client ~D connected" client-id)
                  (bt:make-thread
                   (lambda () (client-connection-loop client-id stream))
                   :name (format nil "hngh-client-~D" client-id)))))
          (error (c)
            (when *daemon-running*
              (hngh.core:log-error "Accept error: ~A" c)
              (sleep 1)))))
    (error (c)
      (hngh.core:log-error "Accept loop crashed: ~A" c))
    (:no-error (&rest vals)
      (declare (ignore vals))
      (hngh.core:log-info "Accept loop stopped"))))

;;; --- Public API -----------------------------------------------------------

(defun daemon-start (&key (hngh-home (default-hngh-home)))
  "Start the Unix socket server. Called after plugin init."
  (when *daemon-running*
    (hngh.core:log-warn "Daemon already running")
    (return-from daemon-start t))
  (ensure-socket-dir hngh-home)
  (let ((socket-path (daemon-socket-path hngh-home)))
    (when (and (probe-file socket-path) (socket-path-active-p socket-path))
      (hngh.core:log-error "Another daemon is already listening on ~A" socket-path)
      (return-from daemon-start nil))
    (ignore-errors (delete-file socket-path))
    (handler-case
        (progn
          (setf *daemon-server*
                (make-instance 'sb-bsd-sockets:local-socket :type :stream))
          (sb-bsd-sockets:socket-bind *daemon-server* (namestring socket-path))
          (sb-bsd-sockets:socket-listen *daemon-server* 16)
          ;; Set permissions (owner read/write only)
          #+sbcl
          (sb-ext:run-program "chmod" (list "600" (namestring socket-path))
                              :search t :wait t :output nil)
          (setf *daemon-running* t
                *active-socket-path* socket-path)
          ;; Start accept loop in background thread
          (setf *accept-thread*
                (bt:make-thread #'accept-loop :name "hngh-daemon-accept"))
          (hngh.core:log-info "Daemon listening on ~A" (namestring socket-path))
          t)
      (error (c)
        (hngh.core:log-error "Failed to start daemon: ~A" c)
        (when *daemon-server*
          (ignore-errors (sb-bsd-sockets:socket-close *daemon-server*))
          (setf *daemon-server* nil))
        nil))))

(defun socket-path-active-p (socket-path)
  "Return T when a server accepts connections at SOCKET-PATH."
  (let ((socket (make-instance 'sb-bsd-sockets:local-socket :type :stream)))
    (unwind-protect
         (handler-case
             (progn
               (sb-bsd-sockets:socket-connect socket (namestring socket-path))
               t)
           (error () nil))
      (ignore-errors (sb-bsd-sockets:socket-close socket)))))

(defun daemon-stop ()
  "Close server socket and all client connections."
  (unless *daemon-running*
    (hngh.core:log-warn "Daemon not running")
    (return-from daemon-stop nil))
  (setf *daemon-running* nil)
  ;; Close all client connections
  (bt:with-lock-held (*client-lock*)
    (maphash (lambda (id conn)
               (declare (ignore id))
               (ignore-errors (close (getf conn :stream))))
             *client-connections*)
    (clrhash *client-connections*))
  ;; Close server socket
  (when *daemon-server*
    (ignore-errors (sb-bsd-sockets:socket-close *daemon-server*))
    (setf *daemon-server* nil))
  ;; Clean up socket file
  (when *active-socket-path*
    (ignore-errors (delete-file *active-socket-path*)))
  (setf *active-socket-path* nil
        *accept-thread* nil)
  (hngh.core:log-info "Daemon stopped")
  t)

(defun daemon-status ()
  "Return daemon status plist."
  (list :running *daemon-running*
        :socket-path (namestring (daemon-socket-path))
        :connected-clients (length (list-connected-clients))
        :subscribed-topics (bt:with-lock-held (*event-lock*)
                                    (loop for k being the hash-keys of *event-subscribers* collect k))))

;;; --- Built-in Request Handlers --------------------------------------------

(defun handle-health (client-id request-msg)
  "Health check endpoint."
  (declare (ignore client-id))
  (hngh.core.wire-protocol:make-response
   (hngh.core.wire-protocol:request-id request-msg)
   :ok
   :result (list :status :healthy :uptime (get-universal-time))))

(defun handle-get-status (client-id request-msg)
  "Return daemon status."
  (declare (ignore client-id))
  (hngh.core.wire-protocol:make-response
   (hngh.core.wire-protocol:request-id request-msg)
   :ok
   :result (append (daemon-status) (orchestrator-control-status))))

(defun %orchestrator-function (name)
  "Return the late-bound AI orchestrator function named NAME, if available."
  (let* ((package (find-package :hngh.plugins.ai-orchestrator))
         (symbol (and package (find-symbol name package))))
    (when (and symbol (fboundp symbol))
      (symbol-function symbol))))

(defun %orchestrator-running-p ()
  "Return true only when the late-bound orchestrator is initialized and active."
  (let ((running-fn (%orchestrator-function "RUNNING-P")))
    (and running-fn (funcall running-fn))))

(defun orchestrator-control-status ()
  "Return H-A3 dispatch control state when that implementation is present."
  (let ((paused-fn (%orchestrator-function "DISPATCH-PAUSED-P"))
        (resume-at-fn (%orchestrator-function "DISPATCH-RESUME-AT")))
    (when paused-fn
      (list :dispatch-paused (funcall paused-fn)
            :dispatch-resume-at (and resume-at-fn (funcall resume-at-fn))))))

(defun handle-submit-task (client-id request-msg)
  "Enqueue a task through the AI orchestrator when it is available."
  (declare (ignore client-id))
  (let* ((id (hngh.core.wire-protocol:request-id request-msg))
         (task (hngh.core.wire-protocol:request-payload request-msg))
         (policy (hngh.core.wire-protocol:request-policy request-msg))
         (submit-fn (%orchestrator-function "SUBMIT-TASK")))
    (cond
      ((or (null submit-fn) (not (%orchestrator-running-p)))
       (hngh.core.wire-protocol:make-response
        id :error :result "AI orchestrator unavailable"))
      ((not (stringp task))
       (hngh.core.wire-protocol:make-response
        id :error :result "TASK must be a string"))
      (policy
       (hngh.core.wire-protocol:make-response
        id :ok :result (funcall submit-fn task :policy policy)))
      (t
       (hngh.core.wire-protocol:make-response
        id :ok :result (funcall submit-fn task))))))

(defun handle-list-tasks (client-id request-msg)
  "Return persisted task records, optionally filtered by status."
  (declare (ignore client-id))
  (let* ((id (hngh.core.wire-protocol:request-id request-msg))
         (payload (hngh.core.wire-protocol:request-payload request-msg))
         (list-fn (%orchestrator-function "LIST-TASKS")))
    (cond
      ((or (null list-fn) (not (%orchestrator-running-p)))
       (hngh.core.wire-protocol:make-response
        id :error :result "AI orchestrator unavailable"))
      ((or (null payload) (equal payload ""))
       (hngh.core.wire-protocol:make-response
        id :ok :result (funcall list-fn)))
      ((and (listp payload) (keywordp (getf payload :status)))
       (hngh.core.wire-protocol:make-response
        id :ok :result (funcall list-fn :status (getf payload :status))))
      (t
       (hngh.core.wire-protocol:make-response
        id :error :result "LIST-TASKS payload must be empty or (:status KEYWORD)")))))

(defun request-topics (request-msg)
  "Parse and validate an event subscription payload."
  (let* ((payload (hngh.core.wire-protocol:request-payload request-msg))
         (topics (if (and (listp payload) (member :topics payload))
                     (getf payload :topics)
                     payload)))
    (when (or (keywordp topics) (stringp topics))
      (setf topics (list topics)))
    (unless (and (listp topics) topics
                 (every (lambda (topic) (or (keywordp topic) (stringp topic))) topics))
      (error "Topics must be a non-empty list of keywords or strings"))
    (mapcar #'canonical-topic topics)))

(defun handle-subscribe-events (client-id request-msg)
  "Subscribe CLIENT-ID to event topics from REQUEST-MSG."
  (let ((topics (request-topics request-msg)))
    (dolist (topic topics) (subscribe-client client-id topic))
    (hngh.core.wire-protocol:make-response
     (hngh.core.wire-protocol:request-id request-msg) :ok :result topics)))

(defun handle-unsubscribe-events (client-id request-msg)
  "Remove CLIENT-ID subscriptions named by REQUEST-MSG."
  (let ((topics (request-topics request-msg)))
    (dolist (topic topics) (unsubscribe-client client-id topic))
    (hngh.core.wire-protocol:make-response
     (hngh.core.wire-protocol:request-id request-msg) :ok :result topics)))

(defun handle-pause (client-id request-msg)
  "Pause H-A3 task dispatch, optionally until :RESUME-AT."
  (declare (ignore client-id))
  (let ((pause-fn (%orchestrator-function "PAUSE-DISPATCH"))
        (resume-at (getf (hngh.core.wire-protocol:request-payload request-msg)
                         :resume-at)))
    (unless pause-fn (error "H-A3 pause control unavailable"))
    (if resume-at
        (funcall pause-fn :resume-at resume-at)
        (funcall pause-fn))
    (hngh.core.wire-protocol:make-response
     (hngh.core.wire-protocol:request-id request-msg) :ok
     :result (orchestrator-control-status))))

(defun handle-resume (client-id request-msg)
  "Resume H-A3 task dispatch."
  (declare (ignore client-id))
  (let ((resume-fn (%orchestrator-function "RESUME-DISPATCH")))
    (unless resume-fn (error "H-A3 resume control unavailable"))
    (funcall resume-fn)
    (hngh.core.wire-protocol:make-response
     (hngh.core.wire-protocol:request-id request-msg) :ok
     :result (orchestrator-control-status))))

(defun handle-stop-daemon (client-id request-msg)
  "Acknowledge then stop Hngh asynchronously so the response can be flushed."
  (declare (ignore client-id))
  (bt:make-thread
   (lambda ()
     (sleep 0.1)
     (let* ((package (find-package :hngh))
            (symbol (and package (find-symbol "STOP" package))))
       (if (and symbol (fboundp symbol))
           (funcall symbol)
           (daemon-stop))))
   :name "hngh-daemon-stop")
  (hngh.core.wire-protocol:make-response
   (hngh.core.wire-protocol:request-id request-msg) :ok :result :stopping))

;;; --- Lifecycle ------------------------------------------------------------

(defun init (&key (hngh-home (default-hngh-home)))
  "Initialize the daemon core. Does not start the server."
  (declare (ignore hngh-home))
  (clrhash *request-handlers*)
  (clrhash *event-subscribers*)
  (setf *next-client-id* 0)
  (stop-event-bridge)
  ;; Register built-in handlers
  (register-request-handler :health #'handle-health)
  (register-request-handler :get-status #'handle-get-status)
  (register-request-handler :submit-task #'handle-submit-task)
  (register-request-handler :list-tasks #'handle-list-tasks)
  (register-request-handler :subscribe-events #'handle-subscribe-events)
  (register-request-handler :unsubscribe-events #'handle-unsubscribe-events)
  (register-request-handler :pause #'handle-pause)
  (register-request-handler :resume #'handle-resume)
  (register-request-handler :stop-daemon #'handle-stop-daemon)
  (start-event-bridge)
  (hngh.core:log-info "Daemon core initialized")
  t)

(defun shutdown ()
  "Shut down the daemon core."
  (daemon-stop)
  (stop-event-bridge)
  (clrhash *request-handlers*)
  (clrhash *event-subscribers*)
  (hngh.core:log-info "Daemon core shut down")
  t)

(defun running-p ()
  "Return T if daemon is running."
  *daemon-running*)
