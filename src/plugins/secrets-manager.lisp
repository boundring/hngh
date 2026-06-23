;;;; plugins/secrets-manager.lisp — Hngh Secrets Manager (B8)
;;;;
;;;; Policy-checked secret access with pluggable backends:
;;;;   1Password (op CLI), KeePassXC (keepassxc-cli), Local age vault.
;;;;
;;;; For M1: local-vault backend stores secrets in a Lisp plist file
;;;; at ~/.hngh/secrets/vault.lisp (NOT encrypted yet).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.secrets-manager)

;;; --- Data structures ---

(defstruct secret-policy
  "A policy granting a plugin access to one or more secrets."
  plugin      ; string — plugin name
  secrets)    ; list of keyword secret names this plugin may access

(defstruct access-log-entry
  "An entry in the secrets access log.
  NEVER contains secret values — only names and metadata."
  timestamp   ; universal-time
  plugin      ; string — requesting plugin name
  action      ; :get, :set, :list, :grant, :revoke
  secret-name ; string — name of secret accessed (never the value)
  success-p   ; boolean
  reason)     ; string or nil — failure reason

(defstruct backend-info
  "Information about an available secret backend."
  type        ; :onepassword | :keepassxc | :local-vault | :dummy
  path        ; string — path to the CLI binary or vault file
  available-p ; boolean
  configured-p) ; boolean — is it set up?

;;; --- Global state ---

(defvar *running* nil
  "Whether the secrets manager is active.")

(defvar *hngh-home* nil
  "The Hngh state directory (set during INIT).")

(defvar *backend* nil
  "The active backend info struct, or NIL if locked.")

(defvar *backend-lock* (bt:make-lock "hngh-secrets-backend")
  "Mutex protecting *backend*.")

(defvar *policies* nil
  "List of secret-policy structs defining access rules.")

(defvar *policies-lock* (bt:make-lock "hngh-secrets-policies")
  "Mutex protecting *policies*.")

(defvar *access-log* nil
  "List of access-log-entry structs (append-only).
  Persisted to state/plugins/secrets-manager/access-log.lisp on shutdown.")

(defvar *access-log-lock* (bt:make-lock "hngh-secrets-access-log")
  "Mutex protecting *access-log*.")

(defvar *available-backends* nil
  "List of backend-info structs detected during init.")

;;; --- Helpers ---

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

(defun vault-dir ()
  "Return the path to the secrets vault directory."
  (merge-pathnames "secrets/" *hngh-home*))

(defun vault-file-path ()
  "Return the path to the local vault file."
  (merge-pathnames "vault.lisp" (vault-dir)))

(defun policy-file-path ()
  "Return the relative path for policy persistence."
  "config/plugins/secrets-manager/policy.lisp")

(defun access-log-path ()
  "Return the relative path for access log persistence."
  "state/plugins/secrets-manager/access-log.lisp")

;;; --- Backend detection ---

(defun detect-backends ()
  "Detect available secret backends and return a list of backend-info structs.
  Does NOT modify global state."
  (let ((backends nil))
    ;; 1Password
    (let ((op-path (which "op")))
      (when op-path
        (let ((configured-p nil))
          (handler-case
              (let* ((proc (uiop:launch-program
                            (list op-path "account" "list")
                            :output :stream :error-output :stream))
                     (out (uiop:slurp-stream-string
                           (uiop:process-info-output proc)))
                     (exit-code (uiop:wait-process proc)))
                (setf configured-p
                      (and (zerop exit-code)
                           (> (length (string-trim '(#\Space #\Newline #\Return #\Tab) out))
                              0))))
            (error (c)
              (declare (ignore c))
              (setf configured-p nil)))
          (push (make-backend-info :type :onepassword
                                   :path op-path
                                   :available-p t
                                   :configured-p configured-p)
                backends))))
    ;; KeePassXC
    (let ((kc-path (which "keepassxc-cli")))
      (when kc-path
        (push (make-backend-info :type :keepassxc
                                 :path kc-path
                                 :available-p t
                                 :configured-p nil) ; M1: always nil until config added
              backends)))
    ;; Local age vault — check if age exists and vault file exists
    ;; For M1: local vault is always "available" if the directory exists or can be created
    (push (make-backend-info :type :local-vault
                             :path (namestring (vault-file-path))
                             :available-p t
                             :configured-p (probe-file (vault-file-path)))
          backends)
    ;; Dummy backend (always available, for testing)
    (push (make-backend-info :type :dummy
                             :path "memory"
                             :available-p t
                             :configured-p t)
          backends)
    ;; 1Password and KeePassXC are available but not configured by default
    (nreverse backends)))

;;; --- Local vault backend ---

(defun local-vault-read-secrets ()
  "Read the local vault file and return a plist of (name . value) pairs.
  Returns NIL if the vault file doesn't exist.
  Binds *read-eval* to nil for security."
  (let ((path (vault-file-path)))
    (when (probe-file path)
      (handler-case
          (with-open-file (stream path :direction :input :element-type 'character)
            (let ((*read-eval* nil))
              (read stream nil nil)))
        (error (c)
          (hngh.core:log-error "Failed to read vault file ~A: ~A" (namestring path) c)
          nil)))))

(defun local-vault-write-secrets (secrets-plist)
  "Write SECRETS-PLIST to the local vault file.
  Creates the directory if needed. Returns T on success."
  (let ((path (vault-file-path)))
    (ensure-directories-exist path)
    (handler-case
        (progn
          (with-open-file (stream path :direction :output
                                       :if-exists :supersede
                                       :if-does-not-exist :create)
            (let ((*print-case* :downcase)
                  (*print-pretty* t))
              (prin1 secrets-plist stream)
              (terpri stream)))
          t)
      (error (c)
        (hngh.core:log-error "Failed to write vault file ~A: ~A" (namestring path) c)
        nil))))

(defun local-vault-get (name)
  "Get secret NAME from the local vault. Returns the value or NIL."
  (let ((secrets (local-vault-read-secrets)))
    (when secrets
      (getf secrets (if (keywordp name) name (intern (string-upcase (string name)) :keyword))))))

(defun local-vault-set (name value)
  "Set secret NAME to VALUE in the local vault. Returns T on success."
  (let* ((secrets (or (local-vault-read-secrets) (list)))
         (key (if (keywordp name) name (intern (string-upcase (string name)) :keyword)))
         (found nil))
    ;; Update or insert
    (loop for (k v) on secrets by #'cddr
          when (eq k key)
          do (setf (getf secrets key) value
                   found t))
    (unless found
      (setf (getf secrets key) value))
    (when (local-vault-write-secrets secrets)
      t)))

(defun local-vault-list-names ()
  "Return a list of secret name strings from the local vault."
  (let ((secrets (local-vault-read-secrets)))
    (when secrets
      (loop for (k v) on secrets by #'cddr
            collect (string k)))))

;;; --- Backend dispatch ---

(defun backend-type ()
  "Return the :type of the active backend, or nil if locked."
  (bt:with-lock-held (*backend-lock*)
    (when *backend*
      (backend-info-type *backend*))))

(defun backend-get (name)
  "Get secret NAME from the active backend. Returns the value or NIL."
  (bt:with-lock-held (*backend-lock*)
    (unless *backend*
      (return-from backend-get (values nil :backend-locked)))
    (ecase (backend-info-type *backend*)
      (:local-vault (local-vault-get name))
      (:dummy (local-vault-get name))   ; dummy uses same storage
      (:onepassword (values nil :not-implemented))
      (:keepassxc (values nil :not-implemented)))))

(defun backend-set (name value)
  "Set secret NAME to VALUE in the active backend. Returns T on success."
  (bt:with-lock-held (*backend-lock*)
    (unless *backend*
      (return-from backend-set nil))
    (ecase (backend-info-type *backend*)
      (:local-vault (local-vault-set name value))
      (:dummy (local-vault-set name value))
      (:onepassword nil)
      (:keepassxc nil))))

(defun backend-list-names ()
  "Return a list of secret name strings from the active backend."
  (bt:with-lock-held (*backend-lock*)
    (unless *backend*
      (return-from backend-list-names nil))
    (ecase (backend-info-type *backend*)
      (:local-vault (local-vault-list-names))
      (:dummy (local-vault-list-names))
      (:onepassword nil)
      (:keepassxc nil))))

;;; --- Policy management ---

(defun find-policy (plugin-name)
  "Find the secret-policy for PLUGIN-NAME. Returns the struct or NIL."
  (bt:with-lock-held (*policies-lock*)
    (find plugin-name *policies*
          :key #'secret-policy-plugin
          :test #'string=)))

(defun plugin-authorized-p (plugin-name secret-name)
  "Check if PLUGIN-NAME is authorized to access SECRET-NAME.
  Returns T if authorized, NIL otherwise."
  (let ((policy (find-policy plugin-name)))
    (when policy
      (let ((secret-key (if (keywordp secret-name)
                            secret-name
                            (intern (string-upcase (string secret-name)) :keyword))))
        (member secret-key (secret-policy-secrets policy))))))

(defun persist-policies ()
  "Write *policies* to the state store."
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (handler-case
        (hngh.core.state-store:write-state
         (policy-file-path)
         (loop for p in (bt:with-lock-held (*policies-lock*) (copy-list *policies*))
               collect (list (secret-policy-plugin p)
                             (secret-policy-secrets p))))
      (error (c)
        (hngh.core:log-warn "Failed to persist policies: ~A" c)))))

(defun load-policies ()
  "Load policies from the state store into *policies*."
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (when (hngh.core.state-store:state-exists-p (policy-file-path))
      (handler-case
          (let ((raw (hngh.core.state-store:read-state (policy-file-path))))
            (when (and raw (listp raw))
              (bt:with-lock-held (*policies-lock*)
                (setf *policies*
                      (loop for entry in raw
                            when (listp entry)
                            collect (let ((plugin (first entry))
                                          (secrets (second entry)))
                                      (make-secret-policy
                                       :plugin plugin
                                       :secrets secrets))))))
            (hngh.core:log-debug "Loaded ~D policies" (length *policies*)))
        (error (c)
          (hngh.core:log-warn "Failed to load policies: ~A; starting with empty policies" c))))))

;;; --- Access log ---

(defun log-access (plugin action secret-name success-p &optional reason)
  "Append an entry to the access log. SECRET-NAME is a string, never the value."
  (let ((entry (make-access-log-entry :timestamp (get-universal-time)
                                      :plugin plugin
                                      :action action
                                      :secret-name secret-name
                                      :success-p success-p
                                      :reason reason)))
    (bt:with-lock-held (*access-log-lock*)
      (push entry *access-log*))
    (hngh.core:log-debug "Secrets access: ~A ~A ~A (success: ~A~@[, reason: ~A~])"
                         plugin action secret-name success-p reason)
    entry))

(defun persist-access-log ()
  "Write *access-log* to the state store."
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (handler-case
        (hngh.core.state-store:write-state
         (access-log-path)
         (bt:with-lock-held (*access-log-lock*)
           (loop for entry in (reverse *access-log*)
                 collect (list :timestamp (access-log-entry-timestamp entry)
                               :plugin (access-log-entry-plugin entry)
                               :action (access-log-entry-action entry)
                               :secret-name (access-log-entry-secret-name entry)
                               :success-p (access-log-entry-success-p entry)
                               :reason (access-log-entry-reason entry)))))
      (error (c)
        (hngh.core:log-warn "Failed to persist access log: ~A" c)))))

(defun load-access-log ()
  "Load access log from the state store into *access-log*."
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (when (hngh.core.state-store:state-exists-p (access-log-path))
      (handler-case
          (let ((raw (hngh.core.state-store:read-state (access-log-path))))
            (when (and raw (listp raw))
              (bt:with-lock-held (*access-log-lock*)
                (setf *access-log*
                      (loop for entry in (reverse raw)
                            when (listp entry)
                            collect (make-access-log-entry
                                     :timestamp (getf entry :timestamp)
                                     :plugin (getf entry :plugin)
                                     :action (getf entry :action)
                                     :secret-name (getf entry :secret-name)
                                     :success-p (getf entry :success-p)
                                     :reason (getf entry :reason)))))))
        (error (c)
          (hngh.core:log-warn "Failed to load access log: ~A; starting with empty log" c))))))

;;; --- Event publishing ---

(defun publish-secret-event (topic payload)
  "Publish a secret-related event to the event bus, if initialized."
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish topic payload :source 'secrets-manager)
      (error (c)
        (hngh.core:log-warn "Failed to publish event ~A: ~A" topic c)))))

;;; --- Public API ---

(defun get-secret (name requester)
  "Get secret NAME on behalf of REQUESTER (string).
  Checks policy, retrieves from backend, emits events, logs access.
  Returns (values secret-value nil) on success,
          (values nil reason) on failure.
  NEVER logs the secret value."
  (unless (running-p)
    (return-from get-secret (values nil :not-running)))
  ;; Check backend
  (unless (backend-available-p)
    (log-access requester :get (string name) nil :backend-unavailable)
    (publish-secret-event "secret.denied"
                          (list :name (string name)
                                :requester requester
                                :reason :backend-unavailable))
    (return-from get-secret (values nil :backend-unavailable)))
  ;; Check authorization
  (unless (plugin-authorized-p requester name)
    (log-access requester :get (string name) nil :not-authorized)
    (publish-secret-event "secret.denied"
                          (list :name (string name)
                                :requester requester
                                :reason :not-authorized))
    (return-from get-secret (values nil :not-authorized)))
  ;; Retrieve from backend
  (let ((value (backend-get name)))
    (if value
        (progn
          (log-access requester :get (string name) t)
          (publish-secret-event "secret.accessed"
                                (list :name (string name)
                                      :requester requester
                                      :timestamp (get-universal-time)))
          (values value nil))
        (progn
          (log-access requester :get (string name) nil :not-found)
          (values nil :not-found)))))

(defun set-secret (name value &key (requester "system"))
  "Store secret NAME = VALUE via the active backend.
  Logs the name only (never the value).
  Returns T on success, NIL on failure."
  (unless (running-p)
    (return-from set-secret nil))
  (unless (backend-available-p)
    (log-access requester :set (string name) nil :backend-unavailable)
    (return-from set-secret nil))
  (let ((result (backend-set name value)))
    (when result
      (log-access requester :set (string name) t)
      (publish-secret-event "secret.accessed"
                            (list :name (string name)
                                  :requester requester
                                  :timestamp (get-universal-time))))
    result))

(defun list-secrets ()
  "Return a list of secret name strings from the backend.
  Returns NIL if locked or no backend."
  (unless (running-p)
    (return-from list-secrets nil))
  (backend-list-names))

(defun authorize (plugin-name secret-name)
  "Grant PLUGIN-NAME access to SECRET-NAME.
  Creates a policy if none exists for the plugin.
  Returns T on success."
  (unless (running-p)
    (return-from authorize nil))
  (let ((secret-key (if (keywordp secret-name)
                        secret-name
                        (intern (string-upcase (string secret-name)) :keyword))))
    (bt:with-lock-held (*policies-lock*)
      (let ((policy (find plugin-name *policies*
                          :key #'secret-policy-plugin
                          :test #'string=)))
        (if policy
            ;; Add secret to existing policy if not already present
            (unless (member secret-key (secret-policy-secrets policy))
              (setf (secret-policy-secrets policy)
                    (cons secret-key (secret-policy-secrets policy))))
            ;; Create new policy
            (push (make-secret-policy :plugin plugin-name
                                      :secrets (list secret-key))
                  *policies*))))
    (log-access plugin-name :grant (string secret-name) t)
    (publish-secret-event "secret.granted"
                          (list :plugin plugin-name
                                :secret (string secret-name)))
    (persist-policies)
    t))

(defun revoke (plugin-name secret-name)
  "Revoke PLUGIN-NAME's access to SECRET-NAME.
  Returns T on success (even if secret was not in the policy — idempotent)."
  (unless (running-p)
    (return-from revoke nil))
  (let ((secret-key (if (keywordp secret-name)
                        secret-name
                        (intern (string-upcase (string secret-name)) :keyword))))
    (bt:with-lock-held (*policies-lock*)
      (let ((policy (find plugin-name *policies*
                          :key #'secret-policy-plugin
                          :test #'string=)))
        (when policy
          (setf (secret-policy-secrets policy)
                (remove secret-key (secret-policy-secrets policy))))))
    (log-access plugin-name :revoke (string secret-name) t)
    (publish-secret-event "secret.revoked"
                          (list :plugin plugin-name
                                :secret (string secret-name)))
    (persist-policies)
    t))

(defun list-policies ()
  "Return a list of all secret-policy structs (shallow copy)."
  (bt:with-lock-held (*policies-lock*)
    (copy-list *policies*)))

(defun backend-available-p ()
  "Return T if any backend is active and available."
  (bt:with-lock-held (*backend-lock*)
    (and *backend* (backend-info-available-p *backend*))))

(defun unlock (&key (backend-type :local-vault))
  "Set the active backend to BACKEND-TYPE.
  :local-vault — check vault directory, create if missing
  :onepassword — check op exists and is signed in
  :keepassxc — check keepassxc-cli exists
  :dummy — use dummy backend for testing
  Returns T on success, NIL on failure."
  (let ((backend (find backend-type *available-backends*
                       :key #'backend-info-type)))
    (unless backend
      (hngh.core:log-warn "Backend ~A is not available" backend-type)
      (return-from unlock nil))
    (ecase backend-type
      (:onepassword
       (if (backend-info-configured-p backend)
           (progn
             (bt:with-lock-held (*backend-lock*)
               (setf *backend* backend))
             (hngh.core:log-info "Secrets backend: 1Password unlocked")
             t)
           (progn
             (hngh.core:log-warn "1Password is not configured (no accounts)")
             nil)))
      (:keepassxc
       (hngh.core:log-warn "KeePassXC backend not yet implemented — use :local-vault")
       nil)
      (:local-vault
       (let ((vault-file (vault-file-path)))
         ;; Create the vault directory and file if they don't exist
         (unless (probe-file vault-file)
           (ensure-directories-exist vault-file)
           (local-vault-write-secrets nil))
         (bt:with-lock-held (*backend-lock*)
           (setf *backend* backend))
         (hngh.core:log-info "Secrets backend: local vault unlocked at ~A" (namestring vault-file))
         t))
      (:dummy
       (bt:with-lock-held (*backend-lock*)
         (setf *backend* backend))
       (hngh.core:log-info "Secrets backend: dummy unlocked")
       t))))

(defun lock ()
  "Clear the active backend. Returns T."
  (bt:with-lock-held (*backend-lock*)
    (setf *backend* nil))
  (hngh.core:log-info "Secrets backend locked")
  t)

;;; --- Lifecycle ---

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the secrets manager.
  Loads policies from state store, loads access log,
  detects available backends, and defaults to local-vault."
  (setf *hngh-home* hngh-home
        *running* t)
  ;; Ensure secrets directory exists
  (ensure-directories-exist (vault-dir))
  ;; Detect backends
  (setf *available-backends* (detect-backends))
  ;; Load persisted state (requires state store to be running)
  (load-policies)
  (load-access-log)
  ;; Default: unlock local-vault
  (unlock :backend-type :local-vault)
  (hngh.core:log-info "Secrets manager initialized (~D backends available, ~D policies, ~D access-log entries)"
                      (length *available-backends*)
                      (length *policies*)
                      (length *access-log*)))

(defun shutdown ()
  "Shut down the secrets manager.
  Persists access log, clears state."
  (setf *running* nil)
  ;; Persist access log before shutdown
  (persist-access-log)
  ;; Lock backend
  (lock)
  ;; Clear local state
  (bt:with-lock-held (*policies-lock*)
    (setf *policies* nil))
  (bt:with-lock-held (*access-log-lock*)
    (setf *access-log* nil))
  (setf *available-backends* nil
        *hngh-home* nil)
  (hngh.core:log-info "Secrets manager shut down"))

(defun running-p ()
  "Return T if the secrets manager is active."
  *running*)

(defun status ()
  "Return a plist describing the secrets manager status."
  (list :running *running*
        :backend (bt:with-lock-held (*backend-lock*)
                   (when *backend*
                     (backend-info-type *backend*)))
        :secrets-count (if (backend-available-p)
                           (length (backend-list-names))
                           0)
        :policies-count (bt:with-lock-held (*policies-lock*)
                          (length *policies*))))
