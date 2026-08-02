;;;; tests/unit/test-ai-orchestrator.lisp -- AI Orchestrator Plugin Unit Tests
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

;;; --- Test Suite -----------------------------------------------------------

(def-suite ai-orchestrator-suite
  :description "AI Orchestrator plugin unit tests"
  :in :hngh)

(in-suite ai-orchestrator-suite)

;;; --- Test Helpers ---------------------------------------------------------

(defun make-tmp-home ()
  "Create a temporary directory for tests."
  (let ((path (format nil "/tmp/test-aio-~A/" (random 1000000))))
    (ensure-directories-exist path)
    path))

(defun cleanup-tmp-home (path)
  "Remove temporary directory."
  (uiop:delete-directory-tree (uiop:parse-native-namestring path)
                             :validate t
                             :if-does-not-exist :ignore))

(defun aio-setup (tmp)
  "Initialize event bus, state store, resource manager, and orchestrator."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.core.resource-manager:init :hngh-home tmp)
  (hngh.plugins.ai-orchestrator:init :hngh-home tmp))

(defun aio-teardown (tmp)
  "Shut down orchestrator, resource manager, event bus, state store, clean TMP."
  (hngh.plugins.ai-orchestrator:shutdown)
  (hngh.core.resource-manager:shutdown)
  (hngh.core.event-bus:shutdown)
  (hngh.core.state-store:shutdown)
  (cleanup-tmp-home tmp))

(defmacro with-aio ((tmp-var) &body body)
  "Execute BODY with full test setup/teardown."
  `(let ((,tmp-var (make-tmp-home)))
     (declare (ignorable ,tmp-var))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn (aio-setup ,tmp-var) ,@body)
       (aio-teardown ,tmp-var))))

(defun aio-setup-light (tmp)
  "Initialize event bus, state store, and orchestrator only (no resource manager)."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.plugins.ai-orchestrator:init :hngh-home tmp))

(defun aio-teardown-light (tmp)
  "Shut down orchestrator, event bus, state store, clean TMP."
  (hngh.plugins.ai-orchestrator:shutdown)
  (hngh.core.event-bus:shutdown)
  (hngh.core.state-store:shutdown)
  (cleanup-tmp-home tmp))

(defmacro with-aio-light ((tmp-var) &body body)
  "Execute BODY with minimal services (no resource manager)."
  `(let ((,tmp-var (make-tmp-home)))
     (declare (ignorable ,tmp-var))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn (aio-setup-light ,tmp-var) ,@body)
       (aio-teardown-light ,tmp-var))))

;;; --- Test 1: Lifecycle (init/shutdown) -----------------------------------

(test aio-init-shutdown
  "AI Orchestrator initializes and shuts down cleanly."
  (with-aio-light (tmp)
    (is (hngh.plugins.ai-orchestrator:running-p)
        "Should be running after init")
    (hngh.plugins.ai-orchestrator:shutdown)
    (is (not (hngh.plugins.ai-orchestrator:running-p))
        "Should not be running after shutdown")
    (hngh.plugins.ai-orchestrator:init :hngh-home tmp)
    (is (hngh.plugins.ai-orchestrator:running-p)
        "Should be running after re-init")))

;;; --- Test 2: List agents initially empty ---------------------------------

(test aio-list-agents-empty
  "List-agents returns empty list after fresh init."
  (with-aio-light (tmp)
    (let ((agents (hngh.plugins.ai-orchestrator:list-agents)))
      (is (listp agents) "Result should be a list")
      (is (zerop (length agents)) "Should be empty on fresh init"))))

;;; --- Test 3: Meta-context returns plist with :system-state ----------------

(test aio-meta-context-system-state
  "Meta-context returns a plist containing :system-state key."
  (with-aio (tmp)
    (let ((ctx (hngh.plugins.ai-orchestrator:meta-context)))
      (is (listp ctx) "Meta-context should be a plist (list)")
      (is (getf ctx :system-state) "Should have :system-state key")
      (let ((sys-state (getf ctx :system-state)))
        (is (listp sys-state) ":system-state should be a plist")
        (is (member :hardware sys-state) "Should contain :hardware")
        (is (member :packages sys-state) "Should contain :packages")
        (is (member :config sys-state) "Should contain :config")))))

;;; --- Test 4: Meta-context returns plist with :recent-activity -------------

(test aio-meta-context-recent-activity
  "Meta-context returns a plist containing :recent-activity key."
  (with-aio (tmp)
    (let ((ctx (hngh.plugins.ai-orchestrator:meta-context)))
      (is (listp ctx) "Meta-context should be a plist (list)")
      (is (getf ctx :recent-activity) "Should have :recent-activity key")
      (let ((activity (getf ctx :recent-activity)))
        (is (listp activity) ":recent-activity should be a plist")
        (is (getf activity :count) "Should have :count key")
        (is (integerp (getf activity :count)) ":count should be an integer")
        (is (member :events activity) "Should have :events key")
        (is (listp (getf activity :events)) ":events should be a list")))))

;;; --- Test 5: Status returns plist with :running key -----------------------

(test aio-status-returns-plist
  "Status function returns a plist with required keys."
  (with-aio-light (tmp)
    (let ((s (hngh.plugins.ai-orchestrator:status)))
      (is (listp s) "Status should be a plist (list)")
      (is (getf s :running) "Should have :running key")
      (is (eq t (getf s :running)) "Should report running")
      (is (getf s :active-agents) "Should have :active-agents key")
      (is (integerp (getf s :active-agents)) ":active-agents should be integer")
      (is (getf s :total-agents) "Should have :total-agents key")
      (is (integerp (getf s :total-agents)) ":total-agents should be integer")
      (is (getf s :total-cost) "Should have :total-cost key")
      (is (numberp (getf s :total-cost)) ":total-cost should be number"))))

;;; --- Test 6: Default policy has :prefer-tier :any -------------------------

(test aio-default-policy-prefer-tier
  "Default policy has :prefer-tier :any."
  (with-aio-light (tmp)
    (let ((policy (hngh.plugins.ai-orchestrator::default-policy)))
      (is (not (null policy)) "Default policy should exist")
      (is (eq :any (hngh.plugins.ai-orchestrator::delegate-policy-prefer-tier
                    policy))
          "Default policy should have :prefer-tier :any")
      (is (eq :any (hngh.plugins.ai-orchestrator::delegate-policy-privacy
                    policy))
          "Default policy should have :privacy :any"))))

;;; --- Test 7: Agent-info struct has correct fields -------------------------

(test aio-agent-info-fields
  "Agent-info struct has the required accessor fields."
  (let ((agent (hngh.plugins.ai-orchestrator::make-agent-info
                :id 42 :tool :opencode :task "test task"
                :status :running :cost 1.5 :started-at 1000
                :context '(:foo :bar) :result "done"
                :transcript-path "agents/42/transcript.lisp")))
    ;; Exported accessors
    (is (= 42 (hngh.plugins.ai-orchestrator:agent-info-id agent))
        "Should have correct :id")
    (is (eq :opencode (hngh.plugins.ai-orchestrator:agent-info-tool agent))
        "Should have correct :tool")
    (is (string= "test task"
                 (hngh.plugins.ai-orchestrator:agent-info-task agent))
        "Should have correct :task")
    (is (eq :running (hngh.plugins.ai-orchestrator:agent-info-status agent))
        "Should have correct :status")
    (is (= 1.5 (hngh.plugins.ai-orchestrator:agent-info-cost agent))
        "Should have correct :cost")
    (is (= 1000 (hngh.plugins.ai-orchestrator:agent-info-started-at agent))
        "Should have correct :started-at")
    ;; Internal accessors (not exported, use ::)
    (is (equal '(:foo :bar)
               (hngh.plugins.ai-orchestrator::agent-info-context agent))
        "Should have correct :context")
    (is (string= "done"
                 (hngh.plugins.ai-orchestrator::agent-info-result agent))
        "Should have correct :result")
    (is (string= "agents/42/transcript.lisp"
                 (hngh.plugins.ai-orchestrator::agent-info-transcript-path
                  agent))
        "Should have correct :transcript-path")))

;;; --- Test 8: Delegate with unavailable tool returns :failed status ---------

(test aio-delegate-unavailable-tool-fails-gracefully
  "Delegate returns agent-info with :failed status when no tools are available."
  (with-aio-light (tmp)
    (let ((result (hngh.plugins.ai-orchestrator:delegate
                   "Test task - should fail gracefully")))
      (is (not (null result)) "Should return an agent-info, not NIL")
      (is (typep result 'hngh.plugins.ai-orchestrator:agent-info)
          "Result should be an agent-info struct")
      (let ((status (hngh.plugins.ai-orchestrator:agent-info-status result)))
        (is (member status '(:failed :completed))
            "Status should be :failed or :completed (graceful handling)")
        (is (stringp (hngh.plugins.ai-orchestrator::agent-info-result result))
            "Result should be a string describing the outcome")))))

;;; --- Test 9: Kill agent returns nil for nonexistent agent -----------------

(test aio-kill-nonexistent-agent
  "Kill-agent returns NIL for a nonexistent agent ID."
  (with-aio-light (tmp)
    (is (not (hngh.plugins.ai-orchestrator:kill-agent 99999))
        "Kill-agent for nonexistent ID should return NIL")))

;;; --- Test 10: Handoff returns nil for nonexistent agent -------------------

(test aio-handoff-nonexistent-agent
  "Handoff returns NIL when the source agent doesn't exist."
  (with-aio-light (tmp)
    (is (not (hngh.plugins.ai-orchestrator:handoff 99999 :opencode))
        "Handoff from nonexistent agent should return NIL")))

;;; --- Test 11: List-agents returns a list (may be empty) -------------------

(test aio-list-agents-returns-list
  "List-agents returns a list after init."
  (with-aio-light (tmp)
    (let ((agents (hngh.plugins.ai-orchestrator:list-agents)))
      (is (listp agents) "List-agents should return a list"))))

;;; --- Test 12: Delegate-policy struct fields -------------------------------

(test aio-delegate-policy-fields
  "Delegate-policy struct has correct fields with default values."
  (let ((policy (hngh.plugins.ai-orchestrator::make-delegate-policy)))
    (is (null (hngh.plugins.ai-orchestrator::delegate-policy-prefer-tool
               policy))
        "Default prefer-tool should be NIL")
    (is (eq :any (hngh.plugins.ai-orchestrator::delegate-policy-prefer-tier
                  policy))
        "Default prefer-tier should be :any")
    (is (null (hngh.plugins.ai-orchestrator::delegate-policy-max-cost policy))
        "Default max-cost should be NIL")
    (is (null (hngh.plugins.ai-orchestrator::delegate-policy-max-latency
               policy))
        "Default max-latency should be NIL")
    (is (eq :any (hngh.plugins.ai-orchestrator::delegate-policy-privacy
                  policy))
        "Default privacy should be :any")
    (is (null (hngh.plugins.ai-orchestrator::delegate-policy-model policy))
        "Default model should be NIL"))
  ;; With explicit values
  (let ((policy (hngh.plugins.ai-orchestrator::make-delegate-policy
                 :prefer-tool :ollama :prefer-tier :local
                 :max-cost 0.50 :max-latency 30
                 :privacy :local-only :model "llama3.2-3b")))
    (is (eq :ollama (hngh.plugins.ai-orchestrator::delegate-policy-prefer-tool
                     policy))
        "Should store prefer-tool")
    (is (eq :local (hngh.plugins.ai-orchestrator::delegate-policy-prefer-tier
                    policy))
        "Should store prefer-tier")
    (is (= 0.50 (hngh.plugins.ai-orchestrator::delegate-policy-max-cost
                 policy))
        "Should store max-cost")
    (is (= 30 (hngh.plugins.ai-orchestrator::delegate-policy-max-latency
               policy))
        "Should store max-latency")
    (is (eq :local-only (hngh.plugins.ai-orchestrator::delegate-policy-privacy
                         policy))
        "Should store privacy")
    (is (string= "llama3.2-3b"
                 (hngh.plugins.ai-orchestrator::delegate-policy-model policy))
        "Should store model")))

;;; --- Test 13: Policy persistence round-trip -------------------------------

(test aio-policy-persistence
  "Policies survive shutdown and re-init (round-trip via state store)."
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.core.state-store:init :hngh-home tmp)
           (hngh.plugins.ai-orchestrator:init :hngh-home tmp)
           (let ((custom (hngh.plugins.ai-orchestrator::make-delegate-policy
                          :prefer-tool :claude :prefer-tier :cloud
                          :privacy :any)))
             (hngh.plugins.ai-orchestrator::set-policy :my-policy custom)
             (is (eq :claude
                     (hngh.plugins.ai-orchestrator::delegate-policy-prefer-tool
                      (hngh.plugins.ai-orchestrator::get-policy :my-policy)))
                 "Custom policy should be retrievable in same session"))
           (hngh.plugins.ai-orchestrator:shutdown)
           (hngh.core.event-bus:shutdown)
           (hngh.core.state-store:shutdown)
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.core.state-store:init :hngh-home tmp)
           (hngh.plugins.ai-orchestrator:init :hngh-home tmp)
           (let ((loaded (hngh.plugins.ai-orchestrator::get-policy
                          :my-policy)))
             (is (not (null loaded)) "Policy should survive shutdown/re-init")
             (when loaded
               (is (eq :claude
                       (hngh.plugins.ai-orchestrator::delegate-policy-prefer-tool
                        loaded))
                   "Persisted policy should have correct prefer-tool"))))
      (hngh.plugins.ai-orchestrator:shutdown)
      (hngh.core.event-bus:shutdown)
      (hngh.core.state-store:shutdown)
      (cleanup-tmp-home tmp))))

;;; --- Test 14: Shutdown kills running agents -------------------------------

(test aio-shutdown-kills-running-agents
  "Shutdown cleans up all running agents without error."
  (with-aio-light (tmp)
    (hngh.plugins.ai-orchestrator:delegate "shutdown test task")
    (is (plusp (length (hngh.plugins.ai-orchestrator:list-agents)))
        "Should have at least one agent after delegation")
    (hngh.plugins.ai-orchestrator:shutdown)
    (is (not (hngh.plugins.ai-orchestrator:running-p))
        "Should not be running after shutdown")
    (hngh.plugins.ai-orchestrator:init :hngh-home tmp)
    (is (zerop (length (hngh.plugins.ai-orchestrator:list-agents)))
        "Agent list should be empty after re-init")))

;;; --- Test 15: Event payload mapping by :invocation-id ----------------------

(test aio-handle-agent-completed-invocation-id
  "handle-agent-completed maps :invocation-id payloads to backend-id agents."
  (with-aio-light (tmp)
    (let ((agent (hngh.plugins.ai-orchestrator::make-agent-info
                  :id 101 :tool :opencode :task "task"
                  :status :running :cost 0.0 :started-at (get-universal-time)
                  :backend-id 777 :context nil :result nil :transcript-path nil)))
      (hngh.plugins.ai-orchestrator::register-agent agent)
      (hngh.plugins.ai-orchestrator::handle-agent-completed
       (hngh.core.event-bus:make-event
        :id 1
        :topic "agent.completed"
        :payload (list :invocation-id 777 :result "ok" :cost 0.42)
        :timestamp (get-universal-time)
        :source 'hngh.plugins.ai-tool-hub))
      (let ((updated (hngh.plugins.ai-orchestrator::find-agent 101)))
        (is (eq :completed (hngh.plugins.ai-orchestrator:agent-info-status updated))
            "Agent status should become :completed")
        (is (string= "ok" (hngh.plugins.ai-orchestrator::agent-info-result updated))
            "Agent result should be set from payload")
        (is (= 0.42 (hngh.plugins.ai-orchestrator:agent-info-cost updated))
            "Agent cost should be set from payload")))))

(test aio-handle-agent-completed-ignores-self-source
  "handle-agent-completed ignores events emitted by ai-orchestrator itself."
  (with-aio-light (tmp)
    (let ((agent (hngh.plugins.ai-orchestrator::make-agent-info
                  :id 201 :tool :opencode :task "task"
                  :status :running :cost 0.0 :started-at (get-universal-time)
                  :backend-id 808 :context nil :result nil :transcript-path nil)))
      (hngh.plugins.ai-orchestrator::register-agent agent)

      (hngh.plugins.ai-orchestrator::handle-agent-completed
       (hngh.core.event-bus:make-event
        :id 1
        :topic "agent.completed"
        :payload (list :invocation-id 808 :result "self" :cost 0.10)
        :timestamp (get-universal-time)
        :source 'hngh.plugins.ai-orchestrator::ai-orchestrator))

      (let ((unchanged (hngh.plugins.ai-orchestrator::find-agent 201)))
        (is (eq :running (hngh.plugins.ai-orchestrator:agent-info-status unchanged))
            "Self-sourced completion event should be ignored"))

      (hngh.plugins.ai-orchestrator::handle-agent-completed
       (hngh.core.event-bus:make-event
        :id 2
        :topic "agent.completed"
        :payload (list :invocation-id 808 :result "foreign" :cost 0.20)
        :timestamp (get-universal-time)
        :source 'ai-tool-hub))

      (let ((updated (hngh.plugins.ai-orchestrator::find-agent 201)))
        (is (eq :completed (hngh.plugins.ai-orchestrator:agent-info-status updated))
            "Foreign completion event should be processed")
        (is (string= "foreign" (hngh.plugins.ai-orchestrator::agent-info-result updated))
            "Foreign completion should update result")))))

;;; --- Test 16: Local invoke uses plist model-spec + backend-id --------------

(test aio-invoke-agent-local-runtime-model-spec
  "invoke-agent passes model-spec plist to spawn-runtime and stores backend-id."
  (with-aio-light (tmp)
    (let* ((spawn-sym (find-symbol "SPAWN-RUNTIME" :hngh.plugins.model-runtime))
           (running-sym (find-symbol "RUNNING-P" :hngh.plugins.model-runtime))
           (orig-spawn (and spawn-sym (symbol-function spawn-sym)))
           (orig-running (and running-sym (symbol-function running-sym)))
           (captured nil))
      (is (and spawn-sym running-sym)
          "Model runtime symbols should exist")
      (unwind-protect
           (progn
             (setf (symbol-function running-sym) (lambda () t))
             (setf (symbol-function spawn-sym)
                   (lambda (kind model-spec &key grant-id port)
                     (declare (ignore grant-id port))
                     (setf captured (list kind model-spec))
                     (hngh.plugins.model-runtime::make-runtime-info
                      :id 9001
                      :kind kind
                      :model (getf model-spec :name)
                      :pid nil
                      :port nil
                      :status :ready
                      :grant-id nil
                      :started-at (get-universal-time))))
             (let* ((agent (hngh.plugins.ai-orchestrator::make-agent-info
                            :id 42 :tool :ollama :task "local task"
                            :status :running :cost 0.0 :started-at (get-universal-time)
                            :backend-id nil :context nil :result nil :transcript-path nil))
                    (policy (hngh.plugins.ai-orchestrator::make-delegate-policy
                             :model "llama3.2-3b")))
               (hngh.plugins.ai-orchestrator::register-agent agent)
               (is (eq :success (hngh.plugins.ai-orchestrator::invoke-agent agent policy))
                   "invoke-agent should succeed for ready local runtime")
               (is (equal (second captured) (list :name "llama3.2-3b"))
                   "model-spec should be passed as plist with :name")
               (is (= 9001 (hngh.plugins.ai-orchestrator::agent-info-backend-id agent))
                   "backend-id should track spawned runtime id")))
        (when spawn-sym
          (setf (symbol-function spawn-sym) orig-spawn))
        (when running-sym
          (setf (symbol-function running-sym) orig-running))))))
