;;;; tests/unit/test-ai-tool-hub.lisp — Tests for AI Tool Hub (B11)
;;;;
;;;; Tests registry, selection, lifecycle, and metadata.
;;;; Does NOT actually invoke AI tools (no money, no hanging).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

;; Tell the compiler these are special variables (defined in ai-tool-hub plugin)
(declaim (special hngh.plugins.ai-tool-hub:*tools*
                  hngh.plugins.ai-tool-hub:*invocations*
                  hngh.plugins.ai-tool-hub:*cost-log*))

(def-suite :hngh.ai-tool-hub
  :description "Tests for AI Tool Hub (B11) — tool registry, selection, cost tracking"
  :in :hngh)

(in-suite :hngh.ai-tool-hub)

;;; --- Fixture helpers -------------------------------------------------

(defvar *ath-tmp-home* nil
  "Temp home directory for the current test fixture.")

(defun ath-setup ()
  "Set up the AI Tool Hub with a temp home directory.
  Initializes event bus, state store, secrets manager, then AI Tool Hub."
  (let ((home (make-tmp-home)))
    (setf *ath-tmp-home* home)
    (ensure-directories-exist home)
    (hngh.core.event-bus:init :hngh-home home)
    (hngh.core.state-store:init :hngh-home home)
    ;; Initialize secrets manager so API key detection works
    (hngh.plugins.secrets-manager:init :hngh-home home)
    (hngh.plugins.ai-tool-hub:init :hngh-home home)))

(defun ath-teardown ()
  "Tear down the AI Tool Hub and clean up temp directory."
  (hngh.plugins.ai-tool-hub:shutdown)
  (hngh.plugins.secrets-manager:shutdown)
  (hngh.core.state-store:shutdown)
  (hngh.core.event-bus:shutdown)
  (when *ath-tmp-home*
    (cleanup-tmp-home *ath-tmp-home*)
    (setf *ath-tmp-home* nil)))

;;; --- Tests: Lifecycle -----------------------------------------------

(test ath-lifecycle-init-shutdown
  "AI Tool Hub: init sets running-p, shutdown clears it."
  (ath-setup)
  (unwind-protect
       (progn
         (is (hngh.plugins.ai-tool-hub:running-p)
             "AI Tool Hub should be running after init")
         (let ((st (hngh.plugins.ai-tool-hub:status)))
           (is (getf st :running)
               "Status :running should be T")
           (is (> (getf st :tools-count) 0)
               "Status :tools-count should be > 0")))
    (ath-teardown))
  (is (not (hngh.plugins.ai-tool-hub:running-p))
      "AI Tool Hub should not be running after shutdown"))

;;; --- Tests: List Tools ----------------------------------------------

(test ath-list-tools-non-empty
  "AI Tool Hub: list-tools returns a non-empty list."
  (ath-setup)
  (unwind-protect
       (let ((tools (hngh.plugins.ai-tool-hub:list-tools)))
         (is (> (length tools) 0)
             "list-tools should return at least one tool")
         (is (every (lambda (x) (typep x 'hngh.plugins.ai-tool-hub:tool-info)) tools)
             "Each element should be a tool-info struct"))
    (ath-teardown)))

(test ath-list-tools-includes-opencode
  "AI Tool Hub: list-tools includes :opencode."
  (ath-setup)
  (unwind-protect
       (let ((tools (hngh.plugins.ai-tool-hub:list-tools)))
         (let ((opencode-tool
                 (find :opencode tools
                       :key #'hngh.plugins.ai-tool-hub:tool-info-id)))
           (is (not (null opencode-tool))
               ":opencode should be present in the tool registry")
           (is (string= (hngh.plugins.ai-tool-hub:tool-info-name opencode-tool)
                        "Opencode")
               ":opencode should have name \"Opencode\"")))
    (ath-teardown)))

;;; --- Tests: Tool Capabilities ---------------------------------------

(test ath-tool-capabilities-opencode
  "AI Tool Hub: :opencode has :code-editing in its capabilities."
  (ath-setup)
  (unwind-protect
       (let ((caps (hngh.plugins.ai-tool-hub:tool-capabilities :opencode)))
         (is (member :code-editing caps)
             ":opencode should have :code-editing in its capabilities")
         (is (member :multi-step-reasoning caps)
             ":opencode should have :multi-step-reasoning in its capabilities")
         (is (member :tool-use caps)
             ":opencode should have :tool-use in its capabilities"))
    (ath-teardown)))

;;; --- Tests: Select Tool ---------------------------------------------

(test ath-select-tool-default
  "AI Tool Hub: select-tool returns a tool by default."
  (ath-setup)
  (unwind-protect
       (let ((result (hngh.plugins.ai-tool-hub:select-tool "Do a thing")))
         (is (not (null result))
             "select-tool should return a tool for a valid task")
         (is (keywordp result)
             "select-tool should return a keyword"))
    (ath-teardown)))

(test ath-select-tool-prefer
  "AI Tool Hub: select-tool with :prefer-tool returns the preferred tool."
  (ath-setup)
  (unwind-protect
       ;; :claude should be available on this system (has claude CLI)
       (let* ((claude-tool
                (find :claude (hngh.plugins.ai-tool-hub:list-tools)
                      :key #'hngh.plugins.ai-tool-hub:tool-info-id))
              (claude-available
                (when claude-tool
                  (hngh.plugins.ai-tool-hub:tool-info-available-p claude-tool))))
         (when claude-available
           (let ((result (hngh.plugins.ai-tool-hub:select-tool
                          "Do a thing" :prefer-tool :claude)))
             (is (eq result :claude)
                 "select-tool with :prefer-tool :claude should return :claude"))))
    (ath-teardown)))

(test ath-select-tool-bogus-task
  "AI Tool Hub: select-tool works with various task inputs."
  (ath-setup)
  (unwind-protect
       ;; select-tool should handle empty string
       (let ((result (hngh.plugins.ai-tool-hub:select-tool "")))
         (is (not (null result))
             "select-tool should return a tool even for empty task"))
    (ath-teardown)))

;;; --- Tests: Estimate Cost -------------------------------------------

(test ath-estimate-cost-non-negative
  "AI Tool Hub: estimate-cost returns a non-negative number."
  (ath-setup)
  (unwind-protect
       (let ((cost (hngh.plugins.ai-tool-hub:estimate-cost
                    :opencode "Write a function that reverses a string")))
         (is (numberp cost)
             "estimate-cost should return a number")
         (is (>= cost 0)
             "estimate-cost should return a non-negative number"))
    (ath-teardown)))

(test ath-estimate-cost-api-tool
  "AI Tool Hub: estimate-cost for :anthropic-api returns a positive number."
  (ath-setup)
  (unwind-protect
       (let ((cost (hngh.plugins.ai-tool-hub:estimate-cost
                    :anthropic-api "Write a function that reverses a string and handles edge cases")))
         (is (numberp cost)
             "estimate-cost for direct API should return a number")
         (is (>= cost 0)
             "estimate-cost for direct API should be non-negative"))
    (ath-teardown)))

;;; --- Tests: List Invocations ----------------------------------------

(test ath-list-invocations-empty
  "AI Tool Hub: list-invocations is initially empty."
  (ath-setup)
  (unwind-protect
       (let ((invs (hngh.plugins.ai-tool-hub:list-invocations)))
         (is (= (length invs) 0)
             "list-invocations should be empty after init"))
    (ath-teardown)))

;;; --- Tests: Status --------------------------------------------------

(test ath-status-plist
  "AI Tool Hub: status returns a plist with :running and :tools-count."
  (ath-setup)
  (unwind-protect
       (let ((st (hngh.plugins.ai-tool-hub:status)))
         (is (getf st :running)
             "Status :running should be T")
         (is (> (getf st :tools-count) 0)
             "Status :tools-count should be > 0")
         (is (listp (getf st :available-tools))
             "Status :available-tools should be a list")
         (is (integerp (getf st :active-invocations))
             "Status :active-invocations should be an integer"))
    (ath-teardown)))

;;; --- Tests: Cost Log ------------------------------------------------

(test ath-cost-log-empty-initially
  "AI Tool Hub: cost-log returns an empty list initially."
  (ath-setup)
  (unwind-protect
       (let ((log (hngh.plugins.ai-tool-hub:cost-log)))
         (is (= (length log) 0)
             "cost-log should be empty after init"))
    (ath-teardown)))

(test ath-cost-log-grows
  "AI Tool Hub: cost-log grows when entries are added."
  (ath-setup)
  (unwind-protect
       (progn
         (is (= (length (hngh.plugins.ai-tool-hub:cost-log)) 0)
             "cost-log should start empty")
         ;; Simulate a cost entry being added (this would normally happen
         ;; during invoke, but we avoid actual tool execution in tests)
         (push '(:timestamp 1000000
                 :tool :claude
                 :provider :anthropic
                 :model "claude-sonnet-4-20250514"
                 :tokens-in 500
                 :tokens-out 200
                 :cost-usd 0.003
                 :task-hash "DEADBEEF"
                 :success t)
               hngh.plugins.ai-tool-hub:*cost-log*)
         (is (= (length (hngh.plugins.ai-tool-hub:cost-log)) 1)
             "cost-log should have 1 entry after insertion"))
    (ath-teardown)))

;;; --- Tests: Tool Availability ---------------------------------------

(test ath-tool-availability-opencode
  "AI Tool Hub: :opencode tool-info shows available-p = T."
  (ath-setup)
  (unwind-protect
       (let* ((tools (hngh.plugins.ai-tool-hub:list-tools))
              (opencode (find :opencode tools
                              :key #'hngh.plugins.ai-tool-hub:tool-info-id)))
         (is (not (null opencode))
             ":opencode should exist in the registry")
         (is (hngh.plugins.ai-tool-hub:tool-info-available-p opencode)
             ":opencode should be available-p = T"))
    (ath-teardown)))

(test ath-tool-availability-nonexistent
  "AI Tool Hub: a non-existent tool (:pi) is not in the registry."
  (ath-setup)
  (unwind-protect
       (let* ((tools (hngh.plugins.ai-tool-hub:list-tools))
              (not-found (find :pi tools
                               :key #'hngh.plugins.ai-tool-hub:tool-info-id)))
         (is (null not-found)
             ":pi should NOT be in the tool registry (not installed)"))
    (ath-teardown)))

;;; --- Tests: Tool Registry Size --------------------------------------

(test ath-tool-registry-size
  "AI Tool Hub: registry contains exactly 9 default tools (incl. local unsloth)."
  (ath-setup)
  (unwind-protect
       (let ((tools (hngh.plugins.ai-tool-hub:list-tools)))
         (is (= (length tools) 9)
             "Tool registry should have 9 default entries")
         (is (not (null (hngh.plugins.ai-tool-hub::find-tool :local-openai-api)))
             "Registry should include :local-openai-api"))
    (ath-teardown)))

;;; --- Tests: Direct API headers --------------------------------------

(test ath-provider-api-headers
  "AI Tool Hub: provider-api-headers uses provider-correct auth headers."
  (let ((anthropic (hngh.plugins.ai-tool-hub::provider-api-headers :anthropic-api "anth-key"))
        (google (hngh.plugins.ai-tool-hub::provider-api-headers :google-api "goog-key"))
        (openai (hngh.plugins.ai-tool-hub::provider-api-headers :openai-api "open-key")))
    (is (find "x-api-key: anth-key" anthropic :test #'string=)
        "Anthropic should use x-api-key header")
    (is (find "anthropic-version: 2023-06-01" anthropic :test #'string=)
        "Anthropic should include version header")
    (is (find "x-goog-api-key: goog-key" google :test #'string=)
        "Google should use x-goog-api-key header")
    (is (find "Authorization: Bearer open-key" openai :test #'string=)
        "OpenAI should use Authorization Bearer header")))


;;; --- Tests: JSON escaping (M6.1 dogfood catch) -------------------------------

(test ath-escape-json-string-control-chars
  "escape-json-string escapes control characters as \u00XX (NUL found by dogfooding)."
  (let ((escaped (hngh.plugins.ai-tool-hub::escape-json-string
                  (format nil "a~Ab" #\Null))))
    (is (search "\\u0000" escaped))
    (is (not (find #\Null escaped))))
  (is (string= "\\u001F"
                (hngh.plugins.ai-tool-hub::escape-json-string (string (code-char 31))))))

;;; --- Tests: agentic CLI args (M6.2) ------------------------------------------

(test ath-agentic-cli-args-opencode
  "agentic-cli-args for :opencode uses opencode 1.18 'run' syntax with the free local model pinned."
  (let ((args (hngh.plugins.ai-tool-hub::agentic-cli-args :opencode "do a thing")))
    (is (equal "run" (first args)))
    (is (member "--auto" args :test #'string=))
    (is (member "-m" args :test #'string=))
    (is (member "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF" args :test #'string=))
    (is (equal "do a thing" (car (last args))))))

(test ath-default-model-total
  "default-model never falls through for agentic CLI tools (M6.2 dogfood catch)."
  (is (string= "opencode" (hngh.plugins.ai-tool-hub::default-model :opencode)))
  (is (string= "claude" (hngh.plugins.ai-tool-hub::default-model :claude)))
  (is (string= "gpt-4o" (hngh.plugins.ai-tool-hub::default-model :openai-api))))