;;;; hngh/data/model-probes.lisp — Model Benchmark Probe Suite
;;;;
;;;; 12 fixed tasks spanning real workload shapes. Each probe has a
;;;; procedural scorer (exact match / schema validation / grep-able property).
;;;; NO LLM judging — scorers are pure functions returning 0.0..1.0.
;;;;
;;;; Attribution: night-ralph / openrouter/nemotron-3-ultra:free / $0.
;;;;

(in-package :hngh.data.model-probes)

;;; --- Probe definition ------------------------------------------------------

(defstruct probe
  "A single benchmark probe: prompt + expected output pattern + scorer."
  (id nil :type symbol)                    ; probe identifier
  (name nil :type string)                  ; human-readable name
  (category nil :type keyword)             ; :elisp | :bash | :cl | :doc | :json | :instruct | :code | :refactor | :test | :plan | :debug | :summarize
  (prompt nil :type string)                ; the prompt to send to the model
  (scorer nil :type function)              ; (expected actual) -> 0.0..1.0
  (weight 1.0 :type float)                 ; relative weight in aggregate score
  (timeout 30 :type integer)               ; seconds
  (metadata nil :type list))               ; optional: (:temperature 0.0 :max-tokens 500 ...)

;;; --- Procedural scorers ----------------------------------------------------

(defun scorer-exact-match (expected actual)
  "Return 1.0 if ACTUAL equals EXPECTED (string=), else 0.0."
  (if (string= expected actual) 1.0 0.0))

(defun scorer-regex-match (pattern actual)
  "Return 1.0 if ACTUAL matches REGEX PATTERN, else 0.0."
  (if (cl-ppcre:scan pattern actual) 1.0 0.0))

(defun scorer-contains-all (keywords actual)
  "Return fraction of KEYWORDS found in ACTUAL (case-insensitive)."
  (let ((found (count-if (lambda (kw) (search kw actual :test #'char-equal)) keywords)))
    (if (zerop (length keywords)) 0.0
        (/ found (length keywords)))))

(defun scorer-json-schema (schema actual)
  "Return 1.0 if ACTUAL parses as JSON and validates against SCHEMA (jsown), else 0.0."
  (handler-case
      (let ((parsed (jsown:parse actual)))
        (if (validate-json-schema schema parsed) 1.0 0.0))
    (error () 0.0)))

(defun scorer-grep-property (property actual)
  "Return 1.0 if PROPERTY appears in ACTUAL (e.g., 'defun', 'require', 'package'), else 0.0."
  (if (search property actual :test #'char-equal) 1.0 0.0))

(defun scorer-line-count (min-lines actual)
  "Return 1.0 if ACTUAL has at least MIN-LINES non-empty lines, else fraction."
  (let ((lines (count-if-not #'uiop:emptyp (uiop:split-lines actual))))
    (min 1.0 (/ lines (max 1 min-lines)))))

(defun scorer-no-forbidden (forbidden actual)
  "Return 1.0 if none of FORBIDDEN strings appear in ACTUAL, else 0.0."
  (if (some (lambda (f) (search f actual :test #'char-equal)) forbidden)
      0.0 1.0))

(defun make-scorer-exact (expected)
  (lambda (actual) (scorer-exact-match expected actual)))

(defun make-scorer-regex (pattern)
  (lambda (actual) (scorer-regex-match pattern actual)))

(defun make-scorer-keywords (keywords)
  (lambda (actual) (scorer-contains-all keywords actual)))

(defun make-scorer-property (property)
  (lambda (actual) (scorer-grep-property property actual)))

(defun make-scorer-min-lines (n)
  (lambda (actual) (scorer-line-count n actual)))

(defun make-scorer-no-forbidden (forbidden)
  (lambda (actual) (scorer-no-forbidden forbidden actual)))

(defun make-scorer-combinator (scorers &optional (weights nil))
  "Combine multiple scorers with optional weights (default equal)."
  (let ((w (or weights (make-list (length scorers) :initial-element 1.0))))
    (lambda (actual)
      (let ((sum 0.0) (total 0.0))
        (loop for s in scorers
              for weight in w
              do (incf sum (* weight (funcall s actual)))
                 (incf total weight))
        (if (zerop total) 0.0 (/ sum total))))))

;;; --- Probe suite -----------------------------------------------------------

(defparameter *model-probes*
  (list
   ;; P1: Elisp idioms
   (make-probe
    :id :elisp-setq-default
    :name "Set default value with setq-default"
    :category :elisp
    :prompt "Write an Emacs Lisp snippet that sets the default value of `fill-column' to 100 using `setq-default'. Only the code, no explanation."
    :scorer (make-scorer-combinator
             [(make-scorer-property "setq-default")
              (make-scorer-property "fill-column")
              (make-scorer-regex "100")]
             [1.0 1.0 1.0])
    :weight 1.0)

   ;; P2: Bash one-liner
   (make-probe
    :id :bash-find-recent
    :name "Find files modified in last 24 hours"
    :category :bash
    :prompt "Write a single bash command that prints all .lisp files modified in the last 24 hours under the current directory. Only the command, no explanation."
    :scorer (make-scorer-combinator
             [(make-scorer-property "find")
              (make-scorer-property "\.lisp")
              (make-scorer-property "-mtime")
              (make-scorer-no-forbidden '("ls" "grep -r"))]
             [1.0 1.0 1.0 1.0])
    :weight 1.0)

   ;; P3: Common Lisp function writing
   (make-probe
    :id :cl-read-lines
    :name "Read file lines into a list"
    :category :cl
    :prompt "Write a Common Lisp function READ-LINES that takes a pathname and returns a list of strings (one per line), using only standard ANSI CL functions. Include the defun signature and body. No extra commentary."
    :scorer (make-scorer-combinator
             [(make-scorer-property "defun")
              (make-scorer-property "read-lines")
              (make-scorer-property "with-open-file")
              (make-scorer-property "read-line")
              (make-scorer-no-forbidden '("alexandria" "uiop" "iterate" "loop for" "collect"))]
             [1.0 1.0 1.0 1.0 1.0])
    :weight 1.0)

   ;; P4: Doc summarization
   (make-probe
    :id :doc-summarize
    :name "Summarize a technical paragraph"
    :category :doc
    :prompt "Summarize this paragraph in exactly ONE sentence (max 25 words): \"Hngh is a Common Lisp agent orchestration system with an event bus, scheduler, plugin host, and AI tool hub. It manages local and remote models, runs a task queue with dependency tracking, and provides a tmux-based mission control dashboard. The system daemon handles privileged operations via D-Bus.\""
    :scorer (make-scorer-combinator
             [(make-scorer-min-lines 1)
              (make-scorer-keywords '("Hngh" "Lisp" "orchestration" "event" "task"))
              (make-scorer-no-forbidden '("however" "moreover" "additionally" "furthermore" "in conclusion"))]
             [1.0 1.0 1.0])
    :weight 1.0)

   ;; P5: JSON-schema conformance
   (make-probe
    :id :json-schema-task
    :name "Emit JSON matching a schema"
    :category :json
    :prompt "Output ONLY a JSON object matching this schema: {\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"string\"},\"status\":{\"type\":\"string\",\"enum\":[\"pending\",\"running\",\"done\"]},\"result\":{\"type\":[\"string\",\"null\"]}},\"required\":[\"id\",\"status\"]}. Set id to \"task-123\", status to \"done\", result to \"ok\"."
    :scorer (make-scorer-json-schema
             '(:type :object
               :properties ((:id :type :string)
                            (:status :type :string :enum ("pending" "running" "done"))
                            (:result :type (:or :string :null)))
               :required (:id :status)))
    :weight 1.0)

   ;; P6: Instruction following
   (make-probe
    :id :instruct-no-markdown
    :name "Follow negative constraint: no markdown"
    :category :instruct
    :prompt "List three Common Lisp implementations. Output as plain text, one per line. Do NOT use markdown, bullet points, or formatting."
    :scorer (make-scorer-combinator
             [(make-scorer-min-lines 3)
              (make-scorer-no-forbidden '("**" "*" "-" "```" "#" "1." "2." "3."))]
             [1.0 1.0])
    :weight 1.0)

   ;; P7: Code generation
   (make-probe
    :id :code-queue-push
    :name "Push to thread-safe queue in CL"
    :category :code
    :prompt "Write a Common Lisp function QUEUE-PUSH that takes a Bordeaux-threads queue and an item, locks the queue, pushes the item, and unlocks. Only the defun. Use bt:with-lock-held."
    :scorer (make-scorer-combinator
             [(make-scorer-property "defun")
              (make-scorer-property "queue-push")
              (make-scorer-property "bt:with-lock-held")
              (make-scorer-property "queue")
              (make-scorer-no-forbidden '("sb-thread" "mp:" "lock-free"))]
             [1.0 1.0 1.0 1.0 1.0])
    :weight 1.0)

   ;; P8: Refactoring
   (make-probe
    :id :refactor-extract-method
    :name "Extract repeated logic into helper"
    :category :refactor
    :prompt "Refactor this code to extract the repeated validation into a helper function VALIDATE-INPUT. Only the refactored code:
(defun process-a (x) (when (and (integerp x) (> x 0) (< x 100)) (do-a x)))
(defun process-b (x) (when (and (integerp x) (> x 0) (< x 100)) (do-b x)))"
    :scorer (make-scorer-combinator
             [(make-scorer-property "validate-input")
              (make-scorer-property "process-a")
              (make-scorer-property "process-b")
              (make-scorer-no-forbidden '("(and (integerp x) (> x 0) (< x 100))"))]
             [1.0 1.0 1.0 1.0])
    :weight 1.0)

   ;; P9: Test generation
   (make-probe
    :id :test-fiveam-basic
    :name "Write a FiveAM test for a pure function"
    :category :test
    :prompt "Write a FiveAM test for a function ADD2 that takes two integers and returns their sum. Include def-suite, in-suite, and a test case. Only the test code."
    :scorer (make-scorer-combinator
             [(make-scorer-property "def-suite")
              (make-scorer-property "in-suite")
              (make-scorer-property "test")
              (make-scorer-property "is")
              (make-scorer-property "add2")]
             [1.0 1.0 1.0 1.0 1.0])
    :weight 1.0)

   ;; P10: Architecture planning
   (make-probe
    :id :plan-plugin-structure
    :name "Design plugin component structure"
    :category :plan
    :prompt "List the 5 files a new Hngh plugin needs (by convention), one per line. No explanation. Example format: src/plugins/foo.lisp"
    :scorer (make-scorer-combinator
             [(make-scorer-min-lines 5)
              (make-scorer-keywords '("src/plugins" ".lisp" "packages.lisp" "hngh.asd" "tests"))
              (make-scorer-no-forbidden '("explanation" "note:" "see also"))]
             [1.0 1.0 1.0])
    :weight 1.0)

   ;; P11: Debugging
   (make-probe
    :id :debug-nil-error
    :name "Diagnose NIL passed to function expecting string"
    :category :debug
    :prompt "A function expects a string but receives NIL. The backtrace shows the error in FORMAT. What is the most likely cause and fix? Answer in one paragraph, max 50 words."
    :scorer (make-scorer-combinator
             [(make-scorer-keywords '("nil" "string" "format" "check" "type" "guard"))
              (make-scorer-no-forbidden '("maybe" "perhaps" "could be" "might" "possible"))]
             [1.0 1.0])
    :weight 1.0)

   ;; P12: Summarization
   (make-probe
    :id :summarize-changelog
    :name "Summarize changelog entry to one line"
    :category :summarize
    :prompt "Summarize this changelog entry in ONE line (max 80 chars): \"### Added\n- New plugin system with hot-reload capability\n- Support for user-defined plugin directories\n- Automatic dependency resolution between plugins\n\n### Fixed\n- Memory leak in event bus when unsubscribing\n- Race condition in scheduler tick handler\""
    :scorer (make-scorer-combinator
             [(make-scorer-min-lines 1)
              (make-scorer-keywords '("plugin" "hot-reload" "memory leak" "race condition"))
              (make-scorer-no-forbidden '("however" "additionally" "moreover" "furthermore"))]
             [1.0 1.0 1.0])
    :weight 1.0))

;;; --- Runner interface ------------------------------------------------------

(defun run-probe (probe model-endpoint &key (model "unsloth/gemma-4-12b-it-qat-GGUF"))
  "Run PROBE against MODEL at MODEL-ENDPOINT. Returns (score actual-output)."
  (declare (ignore model-endpoint model))
  ;; TODO: implement via ai-tool-hub when runner is built
  (values 0.0 ""))

(defun run-probe-suite (&key (probes *model-probes*) (model-endpoint "http://127.0.0.1:8888/v1") (model "unsloth/gemma-4-12b-it-qat-GGUF"))
  "Run all PROBES, return aggregate score + per-probe results."
  (loop for probe in probes
        collect (multiple-value-bind (score output)
                    (run-probe probe model-endpoint :model model)
                  (list :id (probe-id probe)
                        :name (probe-name probe)
                        :category (probe-category probe)
                        :score score
                        :output output))))

(defun probe-suite-report (results)
  "Format RESULTS as a human-readable report."
  (let ((total 0.0) (weight 0.0))
    (format t "~&~%=== Model Probe Suite Report ===~%")
    (dolist (r results)
      (let ((s (getf r :score))
            (w (probe-weight (find (getf r :id) *model-probes* :key #'probe-id))))
        (incf total (* s w))
        (incf weight w)
        (format t "~&~A (~A): ~,3F~%" (getf r :name) (getf r :category) s)))
    (format t "~&Aggregate: ~,3F (~A probes)~%" (if (zerop weight) 0.0 (/ total weight)) (length results))))

;;; --- Export ----------------------------------------------------------------

(export '*model-probes*
        'run-probe
        'run-probe-suite
        'probe-suite-report
        'make-scorer-exact
        'make-scorer-regex
        'make-scorer-keywords
        'make-scorer-property
        'make-scorer-min-lines
        'make-scorer-no-forbidden
        'make-scorer-combinator)