;;;; tests/unit/test-secrets-manager.lisp — Tests for Secrets Manager (B8)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

;; Tell the compiler these are special variables (defined in secrets-manager plugin)
(declaim (special hngh.plugins.secrets-manager:*policies*))

(def-suite :hngh.secrets-manager
  :description "Tests for Secrets Manager (B8) — policy-checked secret access"
  :in :hngh)

(in-suite :hngh.secrets-manager)

;;; --- Fixture helpers ---

(defvar *sm-tmp-home* nil
  "Temp home directory for the current test fixture.")

(defun collect-events (topic-pattern)
  "Subscribe to TOPIC-PATTERN and return a closure that collects events.
  Returns (lambda () collected-events) — call it to get the list."
  (let ((events nil)
        (sub-id nil))
    (setf sub-id
          (hngh.core.event-bus:subscribe topic-pattern
            (lambda (evt)
              (push evt events))))
    ;; Return a function to get collected events + cleanup
    (lambda ()
      (handler-case (hngh.core.event-bus:unsubscribe sub-id)
        (error () nil))
      (nreverse events))))

(defun sm-setup ()
  "Set up the secrets manager with a temp home directory."
  (let ((home (make-tmp-home)))
    (setf *sm-tmp-home* home)
    (ensure-directories-exist home)
    (hngh.core.event-bus:init :hngh-home home)
    (hngh.core.state-store:init :hngh-home home)
    (hngh.plugins.secrets-manager:init :hngh-home home)))

(defun sm-teardown ()
  "Tear down the secrets manager and clean up temp directory."
  (hngh.plugins.secrets-manager:shutdown)
  (hngh.core.state-store:shutdown)
  (hngh.core.event-bus:shutdown)
  (when *sm-tmp-home*
    (cleanup-tmp-home *sm-tmp-home*)
    (setf *sm-tmp-home* nil)))

;;; --- Tests: Lifecycle ---

(test sm-lifecycle-init-shutdown
  "Secrets manager: init sets running-p, shutdown clears it."
  (sm-setup)
  (unwind-protect
       (progn
         (is (hngh.plugins.secrets-manager:running-p)
             "Secrets manager should be running after init")
         (is (hngh.plugins.secrets-manager:backend-available-p)
             "Backend should be available after init (local-vault unlocked)")
         (let ((st (hngh.plugins.secrets-manager:status)))
           (is (getf st :running) "Status :running should be T")
           (is (getf st :backend) "Status :backend should be non-nil")))
    (sm-teardown))
  (is (not (hngh.plugins.secrets-manager:running-p))
      "Secrets manager should not be running after shutdown"))

;;; --- Tests: Policy Management ---

(test sm-policy-authorize-adds-secret
  "Secrets manager: authorize adds a secret to a plugin's policy."
  (sm-setup)
  (unwind-protect
       (progn
         (is (hngh.plugins.secrets-manager:authorize "test-plugin" :my-api-key)
             "authorize should return T")
         (let ((policies (hngh.plugins.secrets-manager:list-policies)))
           (is (= 1 (length policies)) "Should have 1 policy")
           (let ((policy (first policies)))
             (is (string= "test-plugin"
                          (hngh.plugins.secrets-manager::secret-policy-plugin policy))
                 "Policy should be for test-plugin")
             (is (member :my-api-key
                         (hngh.plugins.secrets-manager::secret-policy-secrets policy))
                 "Policy should include :my-api-key"))))
    (sm-teardown)))

(test sm-policy-authorize-multiple-secrets
  "Secrets manager: authorize adds multiple secrets to same plugin."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:authorize "test-plugin" :key-a)
         (hngh.plugins.secrets-manager:authorize "test-plugin" :key-b)
         (let ((policies (hngh.plugins.secrets-manager:list-policies)))
           (is (= 1 (length policies)) "Should still have 1 policy")
           (let ((secrets (hngh.plugins.secrets-manager::secret-policy-secrets
                           (first policies))))
             (is (member :key-a secrets))
             (is (member :key-b secrets)))))
    (sm-teardown)))

(test sm-policy-revoke-removes-secret
  "Secrets manager: revoke removes a secret from a plugin's policy."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:authorize "test-plugin" :secret-keep)
         (hngh.plugins.secrets-manager:authorize "test-plugin" :secret-remove)
         (is (hngh.plugins.secrets-manager:revoke "test-plugin" :secret-remove)
             "revoke should return T")
         (let ((policy (first (hngh.plugins.secrets-manager:list-policies))))
           (is (member :secret-keep
                       (hngh.plugins.secrets-manager::secret-policy-secrets policy))
               ":secret-keep should remain")
           (is (not (member :secret-remove
                            (hngh.plugins.secrets-manager::secret-policy-secrets policy)))
               ":secret-remove should be removed")))
    (sm-teardown)))

(test sm-policy-list-policies-returns-all
  "Secrets manager: list-policies returns all policies."
  (sm-setup)
  (unwind-protect
       (progn
         ;; Initially empty
         (is (null (hngh.plugins.secrets-manager:list-policies))
             "No policies initially")
         ;; Add two plugins
         (hngh.plugins.secrets-manager:authorize "plugin-1" :a)
         (hngh.plugins.secrets-manager:authorize "plugin-2" :b)
         (let ((policies (hngh.plugins.secrets-manager:list-policies)))
           (is (= 2 (length policies)) "Should have 2 policies")))
    (sm-teardown)))

;;; --- Tests: Get Secret ---

(test sm-get-secret-authorized
  "Secrets manager: authorized plugin retrieves a stored secret."
  (sm-setup)
  (unwind-protect
       (progn
         ;; Store a secret and authorize
         (hngh.plugins.secrets-manager:set-secret :my-token "sekret-value-123")
         (hngh.plugins.secrets-manager:authorize "ai-plugin" :my-token)
         ;; Retrieve
         (multiple-value-bind (val err)
             (hngh.plugins.secrets-manager:get-secret :my-token "ai-plugin")
           (is (equal "sekret-value-123" val)
               "Should return the stored secret value")
           (is (null err)
               "Should not return an error")))
    (sm-teardown)))

(test sm-get-secret-unauthorized-denied
  "Secrets manager: unauthorized plugin is denied with :not-authorized."
  (sm-setup)
  (unwind-protect
       (progn
         ;; Store a secret but do NOT authorize any plugin
         (hngh.plugins.secrets-manager:set-secret :protected-key "shhhh")
         ;; Try to retrieve without authorization
         (multiple-value-bind (val err)
             (hngh.plugins.secrets-manager:get-secret :protected-key "evil-plugin")
           (is (null val)
               "Should not return the secret value")
           (is (eq :not-authorized err)
               "Should return :not-authorized error")))
    (sm-teardown)))

(test sm-get-secret-denied-emits-event
  "Secrets manager: denied access emits secret.denied event."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:set-secret :denied-key "denied-value")
         ;; Subscribe to secret.denied events
         (let ((get-events (collect-events "secret.denied")))
           (hngh.plugins.secrets-manager:get-secret :denied-key "unauthorized-plugin")
           (let ((events (funcall get-events)))
             (is (= 1 (length events))
                 "Should have 1 secret.denied event")
             (let ((payload (hngh.core.event-bus:event-payload (first events))))
               (is (equal "DENIED-KEY" (getf payload :name))
                   "Event should name the denied secret")
               (is (equal "unauthorized-plugin" (getf payload :requester))
                   "Event should name the requester")
               (is (eq :not-authorized (getf payload :reason))
                   "Event reason should be :not-authorized")))))
    (sm-teardown)))

(test sm-get-secret-success-emits-event
  "Secrets manager: successful access emits secret.accessed event."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:set-secret :accessed-key "ok-value")
         (hngh.plugins.secrets-manager:authorize "good-plugin" :accessed-key)
         ;; Subscribe to secret.accessed events
         (let ((get-events (collect-events "secret.accessed")))
           (hngh.plugins.secrets-manager:get-secret :accessed-key "good-plugin")
           (let ((events (funcall get-events)))
             (is (>= (length events) 1)
                 "Should have at least 1 secret.accessed event")
             (let ((payload (hngh.core.event-bus:event-payload (first events))))
               (is (equal "ACCESSED-KEY" (getf payload :name))
                   "Event should name the accessed secret")
               (is (equal "good-plugin" (getf payload :requester))
                   "Event should name the requester")
               (is (getf payload :timestamp)
                   "Event should have a timestamp")))))
    (sm-teardown)))

;;; --- Tests: Backend ---

(test sm-backend-available-p
  "Secrets manager: backend-available-p returns T when local-vault is unlocked."
  (sm-setup)
  (unwind-protect
       (progn
         (is (hngh.plugins.secrets-manager:backend-available-p)
             "Backend should be available after init (local-vault unlocked)")
         ;; Lock
         (hngh.plugins.secrets-manager:lock)
         (is (not (hngh.plugins.secrets-manager:backend-available-p))
             "Backend should NOT be available after lock")
         ;; Unlock again
         (hngh.plugins.secrets-manager:unlock :backend-type :local-vault)
         (is (hngh.plugins.secrets-manager:backend-available-p)
             "Backend should be available after re-unlock"))
    (sm-teardown)))

(test sm-lock-clears-backend
  "Secrets manager: lock clears the active backend."
  (sm-setup)
  (unwind-protect
       (progn
         ;; Before lock: get-secret works (policy permitting)
         (hngh.plugins.secrets-manager:set-secret :pre-lock-key "pre-lock-val")
         (hngh.plugins.secrets-manager:authorize "pre-lock-plugin" :pre-lock-key)
        (multiple-value-bind (val err)
            (hngh.plugins.secrets-manager:get-secret :pre-lock-key "pre-lock-plugin")
          (is (not (null val)) "Should get secret before lock")
          (is (null err) "Should not return an error before lock"))
         ;; Lock
         (hngh.plugins.secrets-manager:lock)
         ;; After lock: get-secret should fail with :backend-unavailable
         (multiple-value-bind (val err)
             (hngh.plugins.secrets-manager:get-secret :pre-lock-key "pre-lock-plugin")
           (is (null val) "Should not get secret after lock")
           (is (eq :backend-unavailable err)
               "Should get :backend-unavailable after lock")))
    (sm-teardown)))

;;; --- Tests: Access Log ---

(test sm-access-log-entries-on-get
  "Secrets manager: access log entries are created on get operations."
  (sm-setup)
  (unwind-protect
       (progn
         ;; Successful get
         (hngh.plugins.secrets-manager:set-secret :logged-key "logged-value")
         (hngh.plugins.secrets-manager:authorize "log-plugin" :logged-key)
         (hngh.plugins.secrets-manager:get-secret :logged-key "log-plugin")
         ;; Unauthorized attempt
         (hngh.plugins.secrets-manager:get-secret :logged-key "intruder")
         ;; Check access log
          (let* ((log (symbol-value 'hngh.plugins.secrets-manager:*access-log*))
                (success-entries
                  (remove-if-not #'hngh.plugins.secrets-manager::access-log-entry-success-p log))
                (fail-entries
                  (remove-if #'hngh.plugins.secrets-manager::access-log-entry-success-p log)))
           (is (>= (length success-entries) 1)
               "Should have at least one successful access log entry")
           (is (>= (length fail-entries) 1)
               "Should have at least one failed access log entry")
           ;; Verify successful entry
           (let ((entry (first success-entries)))
             (is (equal "log-plugin"
                        (hngh.plugins.secrets-manager::access-log-entry-plugin entry))
                 "Successful entry should record correct plugin")
             (is (eq :get (hngh.plugins.secrets-manager::access-log-entry-action entry))
                 "Successful entry should record :get action"))
           ;; Verify failed entry
           (let ((entry (first fail-entries)))
             (is (equal "intruder"
                        (hngh.plugins.secrets-manager::access-log-entry-plugin entry))
                 "Failed entry should record correct plugin")
             (is (eq :not-authorized
                     (hngh.plugins.secrets-manager::access-log-entry-reason entry))
                 "Failed entry should record :not-authorized reason"))))
    (sm-teardown)))

(test sm-access-log-never-contains-values
  "Secrets manager: access log entries never contain secret values."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:set-secret :valuable-secret "SUPER-SECRET-VALUE-123")
         (hngh.plugins.secrets-manager:authorize "safe-plugin" :valuable-secret)
         (hngh.plugins.secrets-manager:get-secret :valuable-secret "safe-plugin")
         ;; Check the log — must NOT contain the secret value
          (let ((log (symbol-value 'hngh.plugins.secrets-manager:*access-log*)))
           (dolist (entry log)
             (let* ((entry-str (format nil "~A" entry))
                    (secret-name (hngh.plugins.secrets-manager::access-log-entry-secret-name entry)))
               ;; The entry struct has no value slot
               (is (not (search "SUPER-SECRET-VALUE-123" entry-str))
                   (format nil "Access log entry must NOT contain secret value: ~A" entry-str))
               ;; It should have the name though
               (is (or (null secret-name)
                       (equal "VALUABLE-SECRET" secret-name))
                   "Access log should contain only the secret name, not value")))))
    (sm-teardown)))

;;; --- Tests: Set Secret ---

(test sm-set-secret-stores-and-retrieves
  "Secrets manager: set-secret stores a value and get-secret retrieves it."
  (sm-setup)
  (unwind-protect
       (progn
         (is (hngh.plugins.secrets-manager:set-secret :store-key "stored-data")
             "set-secret should return T on success")
         ;; Authorize and retrieve
         (hngh.plugins.secrets-manager:authorize "retriever" :store-key)
         (multiple-value-bind (val err)
             (hngh.plugins.secrets-manager:get-secret :store-key "retriever")
           (is (equal "stored-data" val)
               "Retrieved value should equal stored value")
           (is (null err) "Should not return an error")))
    (sm-teardown)))

(test sm-set-secret-overwrites-existing
  "Secrets manager: set-secret overwrites an existing secret."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:set-secret :overwrite-key "v1")
         (hngh.plugins.secrets-manager:set-secret :overwrite-key "v2")
         (hngh.plugins.secrets-manager:authorize "updater" :overwrite-key)
         (multiple-value-bind (val err)
             (hngh.plugins.secrets-manager:get-secret :overwrite-key "updater")
           (is (equal "v2" val) "Should return the latest value")
           (is (null err))))
    (sm-teardown)))

;;; --- Tests: List Secrets ---

(test sm-list-secrets-returns-names
  "Secrets manager: list-secrets returns secret names, not values."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:set-secret :alpha "a-value")
         (hngh.plugins.secrets-manager:set-secret :beta "b-value")
         (let ((names (hngh.plugins.secrets-manager:list-secrets)))
           (is (>= (length names) 2) "Should list at least 2 secrets")
           ;; Names are strings (since we use keyword names, they get stringified)
           (is (find "ALPHA" names :test #'string=) "Should include ALPHA")
           (is (find "BETA" names :test #'string=) "Should include BETA")
           ;; Must NOT contain values
           (is (not (find "a-value" names :test #'string=))
               "Should NOT contain secret values")))
    (sm-teardown)))

;;; --- Tests: Status ---

(test sm-status-returns-plist
  "Secrets manager: status returns a plist with :running and :backend keys."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:set-secret :stat-sec "stat-val")
         (hngh.plugins.secrets-manager:authorize "stat-plugin" :stat-sec)
         (let ((st (hngh.plugins.secrets-manager:status)))
           (is (getf st :running)
               "Status :running should be T")
           (is (eq :local-vault (getf st :backend))
               "Status :backend should be :local-vault")
           (is (>= (getf st :secrets-count) 1)
               "Status :secrets-count should be >= 1")
           (is (>= (getf st :policies-count) 1)
               "Status :policies-count should be >= 1")))
    (sm-teardown)))

(test sm-status-after-lock
  "Secrets manager: status reflects locked state."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:lock)
         (let ((st (hngh.plugins.secrets-manager:status)))
           (is (getf st :running)
               "Status :running should still be T after lock")
           (is (null (getf st :backend))
               "Status :backend should be NIL after lock")
           (is (= 0 (getf st :secrets-count))
               "Status :secrets-count should be 0 after lock")))
    (sm-teardown)))

;;; --- Tests: authorize/revoke events ---

(test sm-authorize-emits-granted-event
  "Secrets manager: authorize emits secret.granted event."
  (sm-setup)
  (unwind-protect
       (progn
         (let ((get-events (collect-events "secret.granted")))
           (hngh.plugins.secrets-manager:authorize "granted-plugin" :granted-key)
           (let ((events (funcall get-events)))
             (is (= 1 (length events)) "Should have 1 secret.granted event")
             (let ((payload (hngh.core.event-bus:event-payload (first events))))
               (is (equal "granted-plugin" (getf payload :plugin)))
               (is (equal "GRANTED-KEY" (getf payload :secret)))))))
    (sm-teardown)))

(test sm-revoke-emits-revoked-event
  "Secrets manager: revoke emits secret.revoked event."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:authorize "revoked-plugin" :revoked-key)
         (let ((get-events (collect-events "secret.revoked")))
           (hngh.plugins.secrets-manager:revoke "revoked-plugin" :revoked-key)
           (let ((events (funcall get-events)))
             (is (= 1 (length events)) "Should have 1 secret.revoked event")
             (let ((payload (hngh.core.event-bus:event-payload (first events))))
               (is (equal "revoked-plugin" (getf payload :plugin)))
               (is (equal "REVOKED-KEY" (getf payload :secret)))))))
    (sm-teardown)))

;;; --- Tests: Policy Persistence ---

(test sm-policy-persists-across-init-shutdown
  "Secrets manager: policies persist across shutdown and re-init."
  (let ((home nil))
    (unwind-protect
         (progn
           ;; First session: authorize a plugin
           (setf home (make-tmp-home))
           (ensure-directories-exist home)
           (hngh.core.event-bus:init :hngh-home home)
           (hngh.core.state-store:init :hngh-home home)
           (hngh.plugins.secrets-manager:init :hngh-home home)
           (hngh.plugins.secrets-manager:authorize "persistent-plugin" :persistent-key)
           ;; Shutdown
           (hngh.plugins.secrets-manager:shutdown)
           (hngh.core.state-store:shutdown)
           (hngh.core.event-bus:shutdown)
           ;; Second session: verify policy loaded
           (hngh.core.event-bus:init :hngh-home home)
           (hngh.core.state-store:init :hngh-home home)
           (hngh.plugins.secrets-manager:init :hngh-home home)
           (let ((policies (hngh.plugins.secrets-manager:list-policies)))
             (is (= 1 (length policies)) "Policy should persist across restarts")
             (let ((policy (first policies)))
               (is (string= "persistent-plugin"
                            (hngh.plugins.secrets-manager::secret-policy-plugin policy)))
               (is (member :persistent-key
                           (hngh.plugins.secrets-manager::secret-policy-secrets policy)))))
           ;; Clean up
           (hngh.plugins.secrets-manager:shutdown)
           (hngh.core.state-store:shutdown)
           (hngh.core.event-bus:shutdown))
      (when home
        (cleanup-tmp-home home)))))

;;; --- Tests: Security ---

(test sm-secrets-not-in-access-log-contents
  "Secrets manager: set-secret values never appear in the access log."
  (sm-setup)
  (unwind-protect
       (progn
         (hngh.plugins.secrets-manager:set-secret :safe-key "PRIVATE-DATA-DO-NOT-LEAK")
         (hngh.plugins.secrets-manager:authorize "reader" :safe-key)
         (hngh.plugins.secrets-manager:get-secret :safe-key "reader")
         ;; Scan all access log entries for the secret value
         (let ((found nil))
            (dolist (entry (symbol-value 'hngh.plugins.secrets-manager:*access-log*))
             (let ((all-fields
                     (list (hngh.plugins.secrets-manager::access-log-entry-plugin entry)
                           (hngh.plugins.secrets-manager::access-log-entry-secret-name entry)
                           (hngh.plugins.secrets-manager::access-log-entry-reason entry)
                           (princ-to-string
                            (hngh.plugins.secrets-manager::access-log-entry-action entry)))))
               (dolist (field all-fields)
                 (when (and (stringp field)
                            (search "PRIVATE-DATA-DO-NOT-LEAK" field))
                   (setf found t)))))
           (is (not found)
               "Secret value must NOT appear anywhere in the access log")))
    (sm-teardown)))
