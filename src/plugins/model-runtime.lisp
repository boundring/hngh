;;;; plugins/model-runtime.lisp — Hngh Model Runtime Manager (B4)
;;;;
;;;; Manages model runtime lifecycles: ollama, llama.cpp, unsloth, comfyUI.
;;;; Spawning, health checking, stopping, resource preemption handling.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.model-runtime)

;;; --- Data structures ------------------------------------------------------

(defstruct runtime-info
  "Information about a model runtime instance."
  id          ; integer (unique)
  kind        ; :ollama, :llama-cpp, :unsloth, :comfyui
  model       ; string (model name)
  pid         ; integer or nil (process ID)
  port        ; integer or nil (HTTP API port)
  status      ; :starting, :ready, :stopping, :failed, :stopped
  grant-id    ; integer or nil (Resource Manager grant)
  started-at) ; universal-time

;;; --- Internal state -------------------------------------------------------

(defvar *running* nil
  "Whether the model runtime manager plugin is active.")

(defvar *runtimes* '()
  "List of all runtime-info structs currently managed.")

(defvar *runtimes-lock* (bt:make-lock "hngh-model-runtime-runtimes")
  "Mutex protecting *runtimes* and *next-runtime-id*.")

(defvar *next-runtime-id* 0
  "Counter for monotonically increasing runtime IDs.")

(defvar *available-runtimes* '()
  "Cached plist from discover-runtimes: (:ollama t ... :models (...)).")

(defvar *event-subscriptions* '()
  "List of event subscription IDs for cleanup on shutdown.")

;;; --- Helper: run-command --------------------------------------------------

(defun run-command (program args)
  "Run PROGRAM with ARGS via sb-ext:run-program.
Returns (values output-string exit-code stderr-string).
On process-start failure (program not found), returns (values nil 127 stderr)."
  (handler-case
      (let* ((out-str (make-string-output-stream))
             (err-str (make-string-output-stream))
             (proc (sb-ext:run-program program args
                                        :output out-str
                                        :error err-str
                                        :search t
                                        :wait t))
             (exit-code (sb-ext:process-exit-code proc)))
        (values (get-output-stream-string out-str)
                exit-code
                (get-output-stream-string err-str)))
    (error (c)
      (hngh.core:log-debug "Command ~A ~{~A~^ ~} failed: ~A" program args c)
      (values nil 127 (princ-to-string c)))))

(defun run-command-lines (program args)
  "Run PROGRAM with ARGS and return stdout as a list of non-empty lines.
Returns NIL if the command fails."
  (multiple-value-bind (output exit-code stderr)
      (run-command program args)
    (declare (ignore stderr))
    (when (and output (zerop exit-code))
      (remove-if (lambda (s) (zerop (length s)))
                 (lines output)))))

(defun lines (string)
  "Split STRING into lines, trimming trailing carriage returns."
  (when (stringp string)
    (loop with len = (length string)
          for start = 0 then (1+ end)
          for end = (position #\Newline string :start start)
          for line = (subseq string start (if end end len))
          for trimmed = (string-right-trim '(#\Return) line)
          collect trimmed
          while end)))

(defun which-exists-p (program)
  "Return T if PROGRAM is available on PATH."
  (handler-case
      (let ((proc (sb-ext:run-program "which" (list program)
                                       :output :stream
                                       :error :stream
                                       :wait t
                                       :search t)))
        (zerop (sb-ext:process-exit-code proc)))
    (error () nil)))

;;; --- Helper: health-check -------------------------------------------------

(defun health-check (port)
  "Check if a runtime HTTP API is responding. Returns T or NIL."
  (handler-case
      (let ((output (with-output-to-string (s)
                      (sb-ext:run-program "curl"
                                          (list "-s"
                                                "--connect-timeout" "3"
                                                "--max-time" "8"
                                                "-o" "/dev/null"
                                                "-w" "%{http_code}"
                                                (format nil "http://localhost:~D/api/version" port))
                                          :output s :search t :wait t))))
        (string= (string-trim '(#\Space #\Newline) output) "200"))
    (error () nil)))

(defun health-check-model (port model)
  "Check if MODEL is loaded on an ollama server at PORT.
Sends POST /api/show and checks if the response contains the model name.
Returns T if model exists, NIL otherwise."
  (handler-case
      (multiple-value-bind (output code)
          (run-command "curl"
                       (list "-s"
                             "--connect-timeout" "3"
                             "--max-time" "10"
                             "-X" "POST"
                             (format nil "http://localhost:~D/api/show" port)
                             "-d" (format nil "{\"name\":\"~A\"}" model)))
        (and (zerop code)
             output
             (plusp (length output))
             (not (search "error" output :test #'char-equal))))
    (error () nil)))

;;; --- Helper: unsloth API (OpenAI-compatible, systemd-managed server) -------

(defun %read-hermes-env-key (name)
  "Read variable NAME's value from ~/.hermes/.env by name only (never echoed).
Returns the value string or NIL."
  (let ((env-path (merge-pathnames ".hermes/.env" (user-homedir-pathname))))
    (when (probe-file env-path)
      (handler-case
          (with-open-file (s env-path)
            (loop for line = (read-line s nil nil)
                  while line
                  for prefix = (concatenate 'string "export " name "=")
                  when (and (>= (length line) (length prefix))
                            (string= prefix line :end2 (length prefix)))
                    do (return (string-trim '(#\Space #\" #\')
                                            (subseq line (length prefix))))))
        (error () nil)))))

(defun unsloth-api-key ()
  "API key for the local unsloth server: env var first, hermes .env fallback."
  (or (uiop:getenv "UNSLOTH_API_KEY")
      (%read-hermes-env-key "UNSLOTH_API_KEY")
      "local-dummy-key"))

(defun unsloth-request (path &key (method :get) data (max-time 30) (port 8888))
  "Call the unsloth server at PORT with PATH. Returns (values body exit-code)."
  (let ((args (list "-s" "--connect-timeout" "3"
                    "--max-time" (write-to-string max-time)
                    "-X" (string-upcase (string method))
                    "-H" (format nil "Authorization: Bearer ~A" (unsloth-api-key))
                    "-H" "Content-Type: application/json")))
    (when data
      (setf args (append args (list "-d" data))))
    (setf args (append args (list (format nil "http://127.0.0.1:~D~A" port path))))
    (run-command "curl" args)))

(defun unsloth-health-p (&key (port 8888))
  "T when the unsloth server answers /v1/models."
  (multiple-value-bind (body code)
      (unsloth-request "/v1/models" :max-time 8 :port port)
    (and (zerop code) body (search "\"object\"" body) t)))

(defun %json-object-chunks (body)
  "Split JSON BODY on '{' to isolate object-ish chunks (no json lib)."
  (loop with start = 0
        for pos = (position #\{ body :start start)
        while pos
        for next = (position #\{ body :start (1+ pos))
        collect (subseq body pos next)
        do (setf start (or next (length body)))))

(defun %json-string-val (chunk key)
  "Extract the string value of \"key\":\"value\" from CHUNK, or NIL."
  (let* ((pat (concatenate 'string "\"" key "\":\""))
         (pos (search pat chunk)))
    (when pos
      (let* ((val-start (+ pos (length pat)))
             (val-end (position #\" chunk :start val-start)))
        (and val-end (subseq chunk val-start val-end))))))

(defun unsloth-models (&key (port 8888))
  "List of (model-id . loaded-p) from /v1/models, parsed without a JSON lib."
  (multiple-value-bind (body code)
      (unsloth-request "/v1/models" :max-time 10 :port port)
    (when (and (zerop code) body)
      (loop for chunk in (%json-object-chunks body)
            for id = (%json-string-val chunk "id")
            when id
            collect (cons id (not (null (search "\"loaded\":true" chunk))))))))

(defun unsloth-model-loaded-p (model &key (port 8888))
  "T when MODEL (id string) is currently loaded on the unsloth server."
  (cdr (assoc model (unsloth-models :port port) :test #'string=)))

(defun unsloth-warm-model (model &key (max-time 900) (port 8888))
  "Trigger a model load with a 1-token chat call (load-on-call). T on success.
NOTE: on a 20GB card this may evict the resident model. Call only on intent."
  (multiple-value-bind (body code)
      (unsloth-request "/v1/chat/completions" :method :post :port port
                       :data (format nil "{\"model\":\"~A\",\"messages\":[{\"role\":\"user\",\"content\":\"warm\"}],\"max_tokens\":1}" model)
                       :max-time max-time)
    (declare (ignore body))
    (zerop code)))

(defun systemd-user-unit-active-p (unit)
  "T when systemd --user UNIT reports active."
  (multiple-value-bind (output code stderr)
      (run-command "systemctl" (list "--user" "is-active" unit))
    (declare (ignore stderr))
    (and (zerop code) output
         (string= (string-trim '(#\Space #\Newline) output) "active"))))

(defun unsloth-ensure-server (&key (port 8888))
  "Ensure the systemd-managed unsloth server answers. Starts the unit if
needed (M0's unsloth-studio.service), then polls up to 60s. Returns T or NIL."
  (or (unsloth-health-p :port port)
      (progn
        (hngh.core:log-info "unsloth server not answering — starting unsloth-studio.service")
        (run-command "systemctl" (list "--user" "start" "unsloth-studio.service"))
        (loop for i from 0 below 60
              until (unsloth-health-p :port port)
              do (sleep 1)
              finally (return (unsloth-health-p :port port))))))

;;; --- Helper: next runtime ID ----------------------------------------------

(defun get-next-id ()
  "Return the next unique runtime ID."
  (bt:with-lock-held (*runtimes-lock*)
    (incf *next-runtime-id*)))

;;; --- Helper: event emission -----------------------------------------------

(defun emit-runtime-event (topic info &key reason error-msg)
  "Emit a runtime event on the event bus."
  (when hngh.core.event-bus:*event-bus*
    (let ((payload (list :runtime-id (runtime-info-id info)
                         :kind (runtime-info-kind info)
                         :model (runtime-info-model info)
                         :status (runtime-info-status info)
                         :pid (runtime-info-pid info)
                         :port (runtime-info-port info))))
      (when reason
        (setf payload (append payload (list :reason reason))))
      (when error-msg
        (setf payload (append payload (list :error error-msg))))
      (hngh.core.event-bus:publish topic payload :source 'model-runtime))))

;;; --- Runtime spawning -----------------------------------------------------

(defun spawn-ollama-runtime (info model-spec port)
  "Set up an ollama runtime. Returns the updated runtime-info."
  (let* ((model-name (runtime-info-model info))
         (ollama-port (or port 11434)))

    ;; Check if ollama server is running
    (unless (health-check ollama-port)
      (hngh.core:log-info "Starting ollama serve on port ~D" ollama-port)
      (let ((proc (sb-ext:run-program "ollama" '("serve")
                                       :output :stream
                                       :error :stream
                                       :wait nil
                                       :search t)))
        (setf (runtime-info-pid info) (sb-ext:process-pid proc))
        ;; Poll until server is up
        (loop for i from 0 below 60
              until (health-check ollama-port)
              do (sleep 0.5)
              finally (unless (health-check ollama-port)
                        (error "ollama server failed to start on port ~D within 30s" ollama-port)))))

    (setf (runtime-info-port info) ollama-port)

    ;; Check if the model exists; if not, attempt to pull it
    (if (health-check-model ollama-port model-name)
        (progn
          (hngh.core:log-info "Model ~A already loaded in ollama" model-name)
          (setf (runtime-info-status info) :ready))
        (progn
          (hngh.core:log-info "Model ~A not loaded — attempting pull" model-name)
          (multiple-value-bind (output code)
              (run-command "ollama" (list "pull" model-name))
            (if (zerop code)
                (progn
                  (hngh.core:log-info "Model ~A pulled successfully" model-name)
                  (setf (runtime-info-status info) :ready))
                (progn
                  (hngh.core:log-warn "Failed to pull model ~A: ~A" model-name
                                      (or output "unknown error"))
                  ;; Server is up even if model isn't loaded; mark as ready
                  ;; with a warning — the runtime is functional but the model
                  ;; must be pulled separately.
                  (hngh.core:log-warn "ollama server is running but model ~A could not be loaded"
                                      model-name)
                  (setf (runtime-info-status info) :ready))))))

    info))

(defun spawn-llama-cpp-runtime (info model-spec port)
  "Set up a llama.cpp runtime. Returns the updated runtime-info."
  (let* ((model-path (getf model-spec :path))
         (llama-port (or port 8080)))
    (unless model-path
      (error "llama.cpp requires :path in model-spec"))
    (unless (which-exists-p "llama-server")
      ;; Try llama.cpp as alternative binary name
      (unless (which-exists-p "llama.cpp")
        (error "llama-server and llama.cpp not found on PATH — install llama.cpp first")))

    (let ((binary (if (which-exists-p "llama-server") "llama-server" "llama.cpp")))
      (hngh.core:log-info "Starting ~A on port ~D with model ~A" binary llama-port model-path)
      (let ((proc (sb-ext:run-program binary
                                       (list "--model" model-path
                                             "--port" (write-to-string llama-port)
                                             "--n-gpu-layers" "99")
                                       :output :stream
                                       :error :stream
                                       :wait nil
                                       :search t)))
        (setf (runtime-info-pid info) (sb-ext:process-pid proc)
              (runtime-info-port info) llama-port)
        ;; Poll until server is up
        (loop for i from 0 below 60
              until (health-check llama-port)
              do (sleep 0.5)
              finally (unless (health-check llama-port)
                        (setf (runtime-info-status info) :failed)
                        (hngh.core:log-error "llama.cpp server failed to start within 30s")
                        (return-from spawn-llama-cpp-runtime info)))))

    (setf (runtime-info-status info) :ready)
    info))

(defun spawn-unsloth-runtime (info model-spec port)
  "Set up an unsloth runtime against the systemd-managed server (M4).
Never spawns or kills the process — systemd owns it; we manage via API.
MODEL-SPEC may include :warm t to explicitly warm (load) :name on spawn."
  (let ((unsloth-port (or port 8888))
        (model-name (runtime-info-model info)))
    (unless (unsloth-ensure-server :port unsloth-port)
      (error "unsloth server unreachable on port ~D and could not be started" unsloth-port))
    (setf (runtime-info-pid info) nil
          (runtime-info-port info) unsloth-port
          (runtime-info-status info) :ready)
    (when (and (getf model-spec :warm) (stringp model-name) (plusp (length model-name)))
      (if (unsloth-model-loaded-p model-name :port unsloth-port)
          (hngh.core:log-info "Model ~A already loaded in unsloth" model-name)
          (progn
            (hngh.core:log-info "Warming unsloth model ~A (may take minutes)..." model-name)
            (if (unsloth-warm-model model-name :port unsloth-port)
                (hngh.core:log-info "Model ~A warm" model-name)
                (hngh.core:log-warn "Warm-up call for ~A failed" model-name)))))
    info))

(defun spawn-python-runtime (info model-spec port)
  "Handle comfyUI runtimes (Python-based).
Still manual setup — return info with guidance. (unsloth is M4-managed; see above.)"
  (declare (ignore port))
  (if (which-exists-p "python3")
      (progn
        (hngh.core:log-warn "comfyUI runtime requires manual setup (python3 detected)")
        (setf (runtime-info-status info) :ready)
        info)
      (error "python3 not found — comfyUI runtime cannot be set up")))

(defun spawn-runtime (kind model-spec &key grant-id port)
  "Spawn a model runtime of the given KIND.
KIND: :ollama, :llama-cpp, :unsloth, or :comfyui
MODEL-SPEC: plist (:name \"model\" :path \"/path\" :quant :q4 ...)
GRANT-ID: optional resource grant ID from Resource Manager
PORT: optional port override
Returns a runtime-info struct on success, or NIL on failure."
  (unless *running*
    (hngh.core:log-error "Model runtime manager not initialized")
    (return-from spawn-runtime nil))

  (let* ((model-name (getf model-spec :name "unknown"))
         (runtime-id (get-next-id))
         (info (make-runtime-info
                 :id runtime-id
                 :kind kind
                 :model model-name
                 :pid nil
                 :port nil
                 :status :starting
                 :grant-id grant-id
                 :started-at (get-universal-time))))

    (bt:with-lock-held (*runtimes-lock*)
      (push info *runtimes*))

    ;; Try to spawn; on failure, mark as failed but keep in list
    (handler-case
        (ecase kind
          (:ollama
           (spawn-ollama-runtime info model-spec port))
          (:llama-cpp
           (spawn-llama-cpp-runtime info model-spec port))
          (:unsloth
           (spawn-unsloth-runtime info model-spec port))
          (:comfyui
           (spawn-python-runtime info model-spec port)))
      (error (c)
        (setf (runtime-info-status info) :failed)
        (hngh.core:log-error "Failed to spawn runtime ~D (~A): ~A" runtime-id kind c)
        (emit-runtime-event "runtime.failed" info :error-msg (princ-to-string c))
        (return-from spawn-runtime info)))

    ;; Register with supervisor
    (when (hngh.core.supervisor:running-p)
      (handler-case
          (hngh.core.supervisor:register
           (format nil "runtime-~D" runtime-id)
           :type :plugin
           :restart-policy :on-failure)
        (error (c)
          (hngh.core:log-warn "Failed to register runtime ~D with supervisor: ~A"
                              runtime-id c))))

    ;; Emit runtime.started event
    (emit-runtime-event "runtime.started" info)

    (hngh.core:log-info "Runtime ~D (~A ~A) spawned with status ~A"
                         runtime-id kind model-name (runtime-info-status info))
    info))

;;; --- Runtime stopping -----------------------------------------------------

(defun stop-runtime (id &key (reason :explicit))
  "Stop a runtime by ID.
For ollama: unloads the model from the shared server (does NOT kill the process).
For llama.cpp: kills the subprocess.
For unsloth/comfyui: kills the subprocess.
Releases resource grant if held. Unregisters from supervisor.
Returns T on success, NIL if not found."
  (let ((info nil))
    (bt:with-lock-held (*runtimes-lock*)
      (setf info (find id *runtimes* :key #'runtime-info-id))
      (when info
        (setf *runtimes* (remove info *runtimes*))
        (setf (runtime-info-status info) :stopping)))

    (unless info
      (hngh.core:log-warn "Runtime ~D not found for stopping" id)
      (return-from stop-runtime nil))

    (hngh.core:log-info "Stopping runtime ~D (~A ~A)"
                         id (runtime-info-kind info) (runtime-info-model info))

    ;; Stop the runtime by kind
    (handler-case
        (ecase (runtime-info-kind info)
          (:ollama
           ;; Don't kill the process (shared server) — just unload the model
           (let ((port (runtime-info-port info))
                 (model (runtime-info-model info)))
             (when (and port model)
                (multiple-value-bind (output code)
                    (run-command "curl"
                                 (list "-s"
                                       "--connect-timeout" "3"
                                       "--max-time" "12"
                                       "-X" "POST"
                                       (format nil "http://localhost:~D/api/generate" port)
                                       "-d" (format nil "{\"model\":\"~A\",\"keep_alive\":0}"
                                                    model)))
                 (if (zerop code)
                     (hngh.core:log-info "Model ~A unloaded from ollama" model)
                     (hngh.core:log-warn "Failed to unload model ~A from ollama: ~A"
                                         model (or output "unknown")))))
             (setf (runtime-info-status info) :stopped)))
          (:llama-cpp
           (when (runtime-info-pid info)
             (handler-case
                 (let ((proc (sb-ext:run-program "kill"
                                                 (list "-TERM" (write-to-string (runtime-info-pid info)))
                                                 :search t :wait t)))
                   (declare (ignore proc))
                   (sleep 0.5)
                   ;; Force kill if still alive
                   (handler-case
                       (sb-ext:run-program "kill"
                                           (list "-KILL" (write-to-string (runtime-info-pid info)))
                                           :search t :wait t)
                     (error () nil)))
               (error (c)
                 (hngh.core:log-warn "Error killing llama.cpp process ~D: ~A"
                                     (runtime-info-pid info) c))))
           (setf (runtime-info-status info) :stopped))
          (:unsloth
           ;; Shared systemd-managed server — never kill (M4)
           (hngh.core:log-info "unsloth runtime ~D released; systemd server left running" id)
           (setf (runtime-info-status info) :stopped))
          (:comfyui
           (when (runtime-info-pid info)
             (handler-case
                 (sb-ext:run-program "kill"
                                     (list "-TERM" (write-to-string (runtime-info-pid info)))
                                     :search t :wait t)
               (error (c)
                 (hngh.core:log-warn "Error killing python process ~D: ~A"
                                     (runtime-info-pid info) c))))
           (setf (runtime-info-status info) :stopped)))
      (error (c)
        (hngh.core:log-error "Error stopping runtime ~D: ~A" id c)
        (setf (runtime-info-status info) :failed)))

    ;; Unregister from supervisor
    (when (hngh.core.supervisor:running-p)
      (handler-case
          (hngh.core.supervisor:unregister (format nil "runtime-~D" id))
        (error () nil)))

    ;; Release resource grant if held
    (when (and (runtime-info-grant-id info)
               (not (eq reason :preempted)))
      (when (hngh.core.resource-manager:running-p)
        (handler-case
            (hngh.core.resource-manager:release (runtime-info-grant-id info))
          (error (c)
            (hngh.core:log-warn "Error releasing grant ~D: ~A"
                                (runtime-info-grant-id info) c)))))

    ;; Emit runtime.stopped event
    (emit-runtime-event "runtime.stopped" info :reason reason)

    t))

;;; --- Runtime listing ------------------------------------------------------

(defun list-runtimes ()
  "Return a list of all runtime-info structs from *runtimes*."
  (bt:with-lock-held (*runtimes-lock*)
    (copy-list *runtimes*)))

;;; --- Discovery ------------------------------------------------------------

(defun discover-runtimes ()
  "Detect which runtime binaries are available.
Returns a plist:
  (:ollama t/:llama-cpp nil/:comfyui nil/:unsloth nil :models (list-of-model-names))"
  (let ((ollama-available (which-exists-p "ollama"))
        (llama-cpp-available (or (which-exists-p "llama-server")
                                  (which-exists-p "llama.cpp")))
        (python-available (which-exists-p "python3"))
        (models '()))

    ;; Get ollama model list if available
    (when ollama-available
      (handler-case
          (let ((output (with-output-to-string (s)
                          (sb-ext:run-program "ollama" '("list")
                                              :output s
                                              :error :stream
                                              :search t
                                              :wait t))))
            (when output
              ;; Parse: lines after the header contain model names
              (dolist (line (cdr (lines output)))
                (when (plusp (length line))
                  (let ((parts (split-by-whitespace line)))
                    (when parts
                      (push (first parts) models))))))
            (setf models (nreverse models)))
        (error (c)
          (hngh.core:log-debug "Could not query ollama list: ~A" c))))

    (setf *available-runtimes*
          (list :ollama ollama-available
                :llama-cpp llama-cpp-available
                :comfyui python-available
                :unsloth (unsloth-health-p)
                :models models))
    *available-runtimes*))

(defun split-by-whitespace (string)
  "Split a string by whitespace, returning a list of tokens."
  (when (stringp string)
    (loop with len = (length string)
          with tokens = '()
          with i = 0
          while (< i len)
          do (progn
               ;; Skip whitespace
               (loop while (and (< i len) (member (char string i) '(#\Space #\Tab)))
                     do (incf i))
               ;; Collect token
               (let ((start i))
                 (loop while (and (< i len) (not (member (char string i) '(#\Space #\Tab))))
                       do (incf i))
                 (when (> i start)
                   (push (subseq string start i) tokens))))
          finally (return (nreverse tokens)))))

;;; --- Status ---------------------------------------------------------------

(defun status ()
  "Return a plist with current runtime manager status.
(:running t :active-runtimes N :available-runtimes (list) :models (list))"
  (let ((active (list-runtimes))
        (avail (or *available-runtimes* (discover-runtimes))))
    (list :running *running*
          :active-runtimes (length active)
          :available-runtimes (remove-if-not #'identity
                                              (list :ollama (getf avail :ollama)
                                                    :llama-cpp (getf avail :llama-cpp)
                                                    :comfyui (getf avail :comfyui)
                                                    :unsloth (getf avail :unsloth)))
          :models (getf avail :models))))

;;; --- Preemption helpers ---------------------------------------------------

(defun find-lowest-priority-runtime ()
  "Find the runtime with the lowest-priority preemptible grant.
Returns the runtime-info struct or NIL."
  (let ((grants (when (hngh.core.resource-manager:running-p)
                  (handler-case
                      (hngh.core.resource-manager:list-grants)
                    (error () nil))))
        (victim nil)
        (lowest-priority 999))
    (bt:with-lock-held (*runtimes-lock*)
      (dolist (rt *runtimes*)
        (when (runtime-info-grant-id rt)
          (let ((grant (find (runtime-info-grant-id rt) grants
                             :key (lambda (g) (hngh.core.resource-manager:grant-info-id g)))))
            (when (and grant
                       (hngh.core.resource-manager:grant-info-preemptible grant)
                       (< (hngh.core.resource-manager:grant-info-priority grant)
                          lowest-priority))
              (setf lowest-priority
                    (hngh.core.resource-manager:grant-info-priority grant)
                    victim rt))))))
    victim))

(defun stop-runtimes-by-grant-id (grant-id)
  "Stop all runtimes with the given GRANT-ID.
Used when resource.preempted events are received."
  (let ((victim-ids '()))
    (bt:with-lock-held (*runtimes-lock*)
      (setf victim-ids
            (mapcar #'runtime-info-id
                    (remove-if-not
                     (lambda (rt) (eql (runtime-info-grant-id rt) grant-id))
                     *runtimes*))))
    (dolist (runtime-id victim-ids)
      (handler-case
          (progn
            (hngh.core:log-info "Preempting runtime ~D — grant ~D preempted"
                                runtime-id grant-id)
            (stop-runtime runtime-id :reason :preempted))
        (error (c)
          (hngh.core:log-warn "Failed to stop preempted runtime ~D: ~A"
                              runtime-id c))))))

;;; --- Lifecycle ------------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the model runtime manager plugin.
Discovers available runtimes, subscribes to resource events."
  (declare (ignore hngh-home))
  (setf *running* t
        *event-subscriptions* '())

  ;; Discover available runtimes
  (handler-case
      (discover-runtimes)
    (error (c)
      (hngh.core:log-warn "Runtime discovery failed: ~A" c)))

  ;; Subscribe to resource.preempted events
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (push (hngh.core.event-bus:subscribe
                "resource.preempted"
                (lambda (evt)
                  (let ((payload (hngh.core.event-bus:event-payload evt))
                        (grant-id (getf payload :grant-id)))
                    (when grant-id
                      (hngh.core:log-info "Resource preempted: grant ~D" grant-id)
                      (stop-runtimes-by-grant-id grant-id)))))
              *event-subscriptions*)
      (error (c)
        (hngh.core:log-warn "Could not subscribe to resource.preempted: ~A" c)))

    ;; Subscribe to resource.pressure events (proactive preemption on critical)
    (handler-case
        (push (hngh.core.event-bus:subscribe
                "resource.pressure"
                (lambda (evt)
                  (let ((payload (hngh.core.event-bus:event-payload evt)))
                    (when (eq (getf payload :level) :critical)
                      (hngh.core:log-warn "Resource pressure critical — preempting lowest-priority runtime")
                      (let ((victim (find-lowest-priority-runtime)))
                        (when victim
                          (hngh.core:log-info "Preempting runtime ~D (~A) due to critical resource pressure"
                                              (runtime-info-id victim)
                                              (runtime-info-model victim))
                          (stop-runtime (runtime-info-id victim))))))))
              *event-subscriptions*)
      (error (c)
        (hngh.core:log-warn "Could not subscribe to resource.pressure: ~A" c))))

  (hngh.core:log-info "Model runtime manager initialized (~A available)"
                       (getf *available-runtimes* :ollama)))

(defun shutdown ()
  "Shut down the model runtime manager plugin.
Stops all active runtimes, unsubscribes from events."
  (setf *running* nil)

  ;; Stop all active runtimes
  (let ((all-runtimes (list-runtimes)))
    (dolist (rt all-runtimes)
      (handler-case
          (stop-runtime (runtime-info-id rt))
        (error (c)
          (hngh.core:log-warn "Error stopping runtime ~D during shutdown: ~A"
                              (runtime-info-id rt) c)))))

  ;; Unsubscribe from events
  (dolist (sub-id *event-subscriptions*)
    (when hngh.core.event-bus:*event-bus*
      (handler-case
          (hngh.core.event-bus:unsubscribe sub-id)
        (error () nil))))
  (setf *event-subscriptions* '())

  (hngh.core:log-info "Model runtime manager shut down"))

(defun running-p ()
  "Return T if the model runtime manager plugin is active."
  *running*)
