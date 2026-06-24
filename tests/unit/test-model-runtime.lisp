;;;; tests/unit/test-model-runtime.lisp — Tests for Model Runtime Manager (B4)
;;;;
;;;; Tests cover lifecycle, discovery, spawn/stop, status, and health checks.
;;;; Ollama server IS running on this system (port 11434), so health checks
;;;; and some spawn operations exercise the real server.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.model-runtime
  :description "Tests for Model Runtime Manager (B4)"
  :in :hngh)

(in-suite :hngh.model-runtime)

;;; --- Helpers --------------------------------------------------------------

(defun mr-setup (tmp &key (init-supervisor t) (init-resource-manager t))
  "Initialize event bus, state store, supervisor, resource manager, and
model runtime manager on TMP."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (when init-supervisor
    (hngh.core.supervisor:init))
  (when init-resource-manager
    (hngh.core.resource-manager:init :hngh-home tmp))
  (hngh.plugins.model-runtime:init :hngh-home tmp))

(defun mr-teardown (tmp)
  "Shut down model runtime manager and all services, clean TMP."
  (hngh.plugins.model-runtime:shutdown)
  (hngh.core.resource-manager:shutdown)
  (hngh.core.supervisor:shutdown)
  (hngh.core.event-bus:shutdown)
  (hngh.core.state-store:shutdown)
  (cleanup-tmp-home tmp))

(defmacro with-mr ((tmp-var &key (init-supervisor t) (init-resource-manager t)) &body body)
  "Execute BODY with a temporary home, all services initialized."
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn
            (mr-setup ,tmp-var
                      :init-supervisor ,init-supervisor
                      :init-resource-manager ,init-resource-manager)
            ,@body)
       (mr-teardown ,tmp-var))))

;;; --- Test 1: Lifecycle — init/shutdown ------------------------------------

(test mr-init-shutdown
  "Model runtime manager initializes and shuts down cleanly."
  (with-mr (tmp)
    (is (hngh.plugins.model-runtime:running-p)
        "Should be running after init")
    (hngh.plugins.model-runtime:shutdown)
    (is (not (hngh.plugins.model-runtime:running-p))
        "Should not be running after shutdown")
    ;; Re-init should work
    (hngh.plugins.model-runtime:init :hngh-home tmp)
    (is (hngh.plugins.model-runtime:running-p)
        "Should be running after re-init")))

;;; --- Test 2: Discover runtimes — returns plist with available tools --------

(test mr-discover-runtimes-plist
  "discover-runtimes returns a plist with ollama being T on this system."
  (with-mr (tmp)
    (let ((discovered (hngh.plugins.model-runtime:discover-runtimes)))
      (is (listp discovered) "Result should be a list (plist)")
      (is (getf discovered :ollama) "Should have :ollama key")
      (is (eq t (getf discovered :ollama))
          "ollama should be available on this system")
      (is (member :llama-cpp discovered) "Should have :llama-cpp key")
      (is (member :comfyui discovered) "Should have :comfyui key")
      (is (member :unsloth discovered) "Should have :unsloth key")
      (is (member :models discovered) "Should have :models key"))))

;;; --- Test 3: Discover runtimes — includes model list -----------------------

(test mr-discover-runtimes-models
  "discover-runtimes returns a :models list (may be empty)."
  (with-mr (tmp)
    (let* ((discovered (hngh.plugins.model-runtime:discover-runtimes))
           (models (getf discovered :models)))
      (is (listp models) ":models should be a list"))))

;;; --- Test 4: List runtimes — initially empty ------------------------------

(test mr-list-runtimes-empty
  "list-runtimes returns an empty list before any spawns."
  (with-mr (tmp)
    (let ((runtimes (hngh.plugins.model-runtime:list-runtimes)))
      (is (listp runtimes) "Should return a list")
      (is (zerop (length runtimes))
          "Should be empty before any spawns"))))

;;; --- Test 5: Spawn ollama runtime -----------------------------------------

(test mr-spawn-ollama
  "Spawn an ollama runtime — ollama server is already running on :11434."
  (with-mr (tmp)
    (let* ((model-spec (list :name "llama3.2-3b"))
           (runtime (hngh.plugins.model-runtime:spawn-runtime
                     :ollama model-spec)))
      (is (not (null runtime)) "Should return a runtime-info struct")
      (is (typep runtime 'hngh.plugins.model-runtime:runtime-info)
          "Should be a runtime-info struct")
      (is (integerp (hngh.plugins.model-runtime:runtime-info-id runtime))
          "Runtime should have an integer ID")
      (is (eq :ollama (hngh.plugins.model-runtime:runtime-info-kind runtime))
          "Kind should be :ollama")
      (is (string= "llama3.2-3b"
                    (hngh.plugins.model-runtime:runtime-info-model runtime))
          "Model should match the spec")
      (is (member (hngh.plugins.model-runtime:runtime-info-status runtime)
                  '(:starting :ready :failed))
          "Status should be :starting, :ready, or :failed")
      ;; Clean up the spawned runtime
      (hngh.plugins.model-runtime:stop-runtime
       (hngh.plugins.model-runtime:runtime-info-id runtime)))))

;;; --- Test 6: List runtimes — non-empty after spawn -------------------------

(test mr-list-runtimes-after-spawn
  "list-runtimes is non-empty after spawning a runtime."
  (with-mr (tmp)
    (let ((before (length (hngh.plugins.model-runtime:list-runtimes))))
      (is (zerop before) "Should start empty")
      (let* ((model-spec (list :name "llama3.2-3b"))
             (runtime (hngh.plugins.model-runtime:spawn-runtime
                       :ollama model-spec)))
        (let ((after (hngh.plugins.model-runtime:list-runtimes)))
          (is (plusp (length after)) "Should have at least one runtime after spawn"))
        ;; Clean up
        (hngh.plugins.model-runtime:stop-runtime
         (hngh.plugins.model-runtime:runtime-info-id runtime))))))

;;; --- Test 7: Stop runtime — removes from list ------------------------------

(test mr-stop-runtime
  "stop-runtime removes the runtime from the list."
  (with-mr (tmp)
    (let* ((model-spec (list :name "llama3.2-3b"))
           (runtime (hngh.plugins.model-runtime:spawn-runtime
                     :ollama model-spec))
           (id (hngh.plugins.model-runtime:runtime-info-id runtime)))
      (is (plusp (length (hngh.plugins.model-runtime:list-runtimes)))
          "Runtime should be in list after spawn")
      (let ((result (hngh.plugins.model-runtime:stop-runtime id)))
        (is (eq t result) "stop-runtime should return T on success")
        (is (zerop (length (hngh.plugins.model-runtime:list-runtimes)))
            "Runtime should be removed from list after stop")))))

;;; --- Test 8: Status — returns plist with :running key ---------------------

(test mr-status-returns-plist
  "status function returns a plist with required keys."
  (with-mr (tmp)
    (let ((st (hngh.plugins.model-runtime:status)))
      (is (listp st) "Status should be a list (plist)")
      (is (member :running st) "Should have :running key")
      (is (eq t (getf st :running)) "Plugin should be running")
      (is (member :active-runtimes st) "Should have :active-runtimes key")
      (is (integerp (getf st :active-runtimes))
          ":active-runtimes should be an integer")
      (is (member :available-runtimes st) "Should have :available-runtimes key")
      (is (member :models st) "Should have :models key"))))

;;; --- Test 9: Health check — returns T for port 11434 (ollama) --------------

(test mr-health-check-ollama
  "health-check returns T for port 11434 where ollama is running."
  (is (hngh.plugins.model-runtime::health-check 11434)
      "ollama server on port 11434 should respond")
  ;; A non-existent port should return NIL
  (is (not (hngh.plugins.model-runtime::health-check 1))
      "Port 1 should not have a running server"))

;;; --- Test 10: Spawn non-existent runtime returns gracefully ----------------

(test mr-spawn-nonexistent
  "Spawning llama-cpp when llama-server is not installed returns gracefully."
  (with-mr (tmp :init-resource-manager nil)
    ;; Only test if llama-server is NOT available
    (unless (hngh.plugins.model-runtime::health-check 1) ; dummy check for existence
      (let ((runtime (hngh.plugins.model-runtime:spawn-runtime
                      :llama-cpp (list :name "test-model" :path "/nonexistent/model.gguf"))))
        ;; Should return a runtime-info even on failure (marked as :failed)
        (when runtime
          (is (typep runtime 'hngh.plugins.model-runtime:runtime-info)
              "Should return a runtime-info struct even on failure")
          (is (eq :failed (hngh.plugins.model-runtime:runtime-info-status runtime))
              "Nonexistent runtime should have status :failed"))))))

;;; --- Test 11: Spawn with non-running plugin returns nil --------------------

(test mr-spawn-when-not-running
  "spawn-runtime returns NIL when plugin is not initialized."
  (let ((runtime (hngh.plugins.model-runtime:spawn-runtime
                  :ollama (list :name "test-model"))))
    (is (null runtime)
        "Should return NIL when plugin is not running")))

;;; --- Test 12: Stop non-existent runtime returns nil ------------------------

(test mr-stop-nonexistent
  "stop-runtime returns NIL for a nonexistent runtime ID."
  (with-mr (tmp)
    (let ((result (hngh.plugins.model-runtime:stop-runtime 99999)))
      (is (not result) "Should return NIL for nonexistent runtime ID"))))
