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

(defun validate-json-schema (schema parsed)
  "Validate jsown-parsed PARSED against SCHEMA plist. T when valid.
Supports :type :object / :string / :number / :boolean / :null / (:or ...),
plus :properties (list of (key &key type enum)), :required (list of keys),
and :enum (list of allowed string values). Unknown keys are allowed."
  (labels ((type-ok (type val)
             (case type
               (:object (and (listp val) (eq (first val) :obj)))
               (:string (stringp val))
               (:number (numberp val))
               (:boolean (typep val 'boolean))
               (:null (null val))
               (otherwise nil)))
           (validate-value (spec val)
             (let ((t2 (getf spec :type))
                   (enum (getf spec :enum)))
               (and (or (null t2)
                        (if (and (listp t2) (eq (first t2) :or))
                            (some (lambda (sub) (type-ok sub val)) (rest t2))
                            (type-ok t2 val)))
                    (or (null enum)
                        (and (stringp val)
                             (member val enum :test #'string=))))))
           (validate-object (props required obj)
             (labels ((key-str (k) (string-downcase (if (keywordp k) (symbol-name k) k))))
               (and (every (lambda (k) (jsown:keyp obj (key-str k))) required)
                    (every (lambda (prop)
                             (destructuring-bind (key &rest spec) prop
                               (let ((ks (key-str key)))
                                 (or (not (jsown:keyp obj ks))
                                     (validate-value spec (jsown:val obj ks))))))
                           props)))))
    (let ((type (getf schema :type)))
      (cond
        ((and (listp type) (eq (first type) :or))
         (some (lambda (t2)
                 (if (eq t2 :object)
                     (validate-object (getf schema :properties)
                                      (getf schema :required)
                                      parsed)
                     (type-ok t2 parsed)))
               (rest type)))
        ((eq type :object)
         (validate-object (getf schema :properties)
                          (getf schema :required)
                          parsed))
        (t (type-ok type parsed))))))

(defun make-scorer-json-schema (schema)
  (lambda (actual) (scorer-json-schema schema actual)))

(defun scorer-grep-property (property actual)
  "Return 1.0 if PROPERTY appears in ACTUAL (e.g., 'defun', 'require', 'package'), else 0.0."
  (if (search property actual :test #'char-equal) 1.0 0.0))

(defun scorer-line-count (min-lines actual)
  "Return 1.0 if ACTUAL has at least MIN-LINES non-empty lines, else fraction."
  (let ((lines (remove-if #'uiop:emptyp
                          (uiop:split-string actual :separator '(#\Newline)))))
    (min 1.0 (/ (length lines) (max 1 min-lines)))))

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
             (list (make-scorer-property "setq-default")
              (make-scorer-property "fill-column")
              (make-scorer-regex "100"))
             (list 1.0 1.0 1.0))
    :weight 1.0)

   ;; P2: Bash one-liner
   (make-probe
    :id :bash-find-recent
    :name "Find files modified in last 24 hours"
    :category :bash
    :prompt "Write a single bash command that prints all .lisp files modified in the last 24 hours under the current directory. Only the command, no explanation."
    :scorer (make-scorer-combinator
             (list (make-scorer-property "find")
              (make-scorer-property "\.lisp")
              (make-scorer-property "-mtime")
              (make-scorer-no-forbidden '("ls" "grep -r")))
             (list 1.0 1.0 1.0 1.0))
    :weight 1.0)

   ;; P3: Common Lisp function writing
   (make-probe
    :id :cl-read-lines
    :name "Read file lines into a list"
    :category :cl
    :prompt "Write a Common Lisp function READ-LINES that takes a pathname and returns a list of strings (one per line), using only standard ANSI CL functions. Include the defun signature and body. No extra commentary."
    :scorer (make-scorer-combinator
             (list (make-scorer-property "defun")
              (make-scorer-property "read-lines")
              (make-scorer-property "with-open-file")
              (make-scorer-property "read-line")
              (make-scorer-no-forbidden '("alexandria" "uiop" "iterate" "loop for" "collect")))
             (list 1.0 1.0 1.0 1.0 1.0))
    :weight 1.0)

   ;; P4: Doc summarization
   (make-probe
    :id :doc-summarize
    :name "Summarize a technical paragraph"
    :category :doc
    :prompt "Summarize this paragraph in exactly ONE sentence (max 25 words): \"Hngh is a Common Lisp agent orchestration system with an event bus, scheduler, plugin host, and AI tool hub. It manages local and remote models, runs a task queue with dependency tracking, and provides a tmux-based mission control dashboard. The system daemon handles privileged operations via D-Bus.\""
    :scorer (make-scorer-combinator
             (list (make-scorer-min-lines 1)
              (make-scorer-keywords '("Hngh" "Lisp" "orchestration" "event" "task"))
              (make-scorer-no-forbidden '("however" "moreover" "additionally" "furthermore" "in conclusion")))
             (list 1.0 1.0 1.0))
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
             (list (make-scorer-min-lines 3)
              (make-scorer-no-forbidden '("**" "*" "-" "```" "#" "1." "2." "3.")))
             (list 1.0 1.0))
    :weight 1.0)

   ;; P7: Code generation
   (make-probe
    :id :code-queue-push
    :name "Push to thread-safe queue in CL"
    :category :code
    :prompt "Write a Common Lisp function QUEUE-PUSH that takes a Bordeaux-threads queue and an item, locks the queue, pushes the item, and unlocks. Only the defun. Use bt:with-lock-held."
    :scorer (make-scorer-combinator
             (list (make-scorer-property "defun")
              (make-scorer-property "queue-push")
              (make-scorer-property "bt:with-lock-held")
              (make-scorer-property "queue")
              (make-scorer-no-forbidden '("sb-thread" "mp:" "lock-free")))
             (list 1.0 1.0 1.0 1.0 1.0))
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
             (list (make-scorer-property "validate-input")
              (make-scorer-property "process-a")
              (make-scorer-property "process-b")
              (make-scorer-no-forbidden '("(and (integerp x) (> x 0) (< x 100))")))
             (list 1.0 1.0 1.0 1.0))
    :weight 1.0)

   ;; P9: Test generation
   (make-probe
    :id :test-fiveam-basic
    :name "Write a FiveAM test for a pure function"
    :category :test
    :prompt "Write a FiveAM test for a function ADD2 that takes two integers and returns their sum. Include def-suite, in-suite, and a test case. Only the test code."
    :scorer (make-scorer-combinator
             (list (make-scorer-property "def-suite")
              (make-scorer-property "in-suite")
              (make-scorer-property "test")
              (make-scorer-property "is")
              (make-scorer-property "add2"))
             (list 1.0 1.0 1.0 1.0 1.0))
    :weight 1.0)

   ;; P10: Architecture planning
   (make-probe
    :id :plan-plugin-structure
    :name "Design plugin component structure"
    :category :plan
    :prompt "List the 5 files a new Hngh plugin needs (by convention), one per line. No explanation. Example format: src/plugins/foo.lisp"
    :scorer (make-scorer-combinator
             (list (make-scorer-min-lines 5)
              (make-scorer-keywords '("src/plugins" ".lisp" "packages.lisp" "hngh.asd" "tests"))
              (make-scorer-no-forbidden '("explanation" "note:" "see also")))
             (list 1.0 1.0 1.0))
    :weight 1.0)

   ;; P11: Debugging
   (make-probe
    :id :debug-nil-error
    :name "Diagnose NIL passed to function expecting string"
    :category :debug
    :prompt "A function expects a string but receives NIL. The backtrace shows the error in FORMAT. What is the most likely cause and fix? Answer in one paragraph, max 50 words."
    :scorer (make-scorer-combinator
             (list (make-scorer-keywords '("nil" "string" "format" "check" "type" "guard"))
              (make-scorer-no-forbidden '("maybe" "perhaps" "could be" "might" "possible")))
             (list 1.0 1.0))
    :weight 1.0)

   ;; P12: Summarization
   (make-probe
    :id :summarize-changelog
    :name "Summarize changelog entry to one line"
    :category :summarize
    :prompt "Summarize this changelog entry in ONE line (max 80 chars): \"### Added\n- New plugin system with hot-reload capability\n- Support for user-defined plugin directories\n- Automatic dependency resolution between plugins\n\n### Fixed\n- Memory leak in event bus when unsubscribing\n- Race condition in scheduler tick handler\""
    :scorer (make-scorer-combinator
             (list (make-scorer-min-lines 1)
              (make-scorer-keywords '("plugin" "hot-reload" "memory leak" "race condition"))
              (make-scorer-no-forbidden '("however" "additionally" "moreover" "furthermore")))
             (list 1.0 1.0 1.0))
    :weight 1.0)))

;;; --- Runner interface ------------------------------------------------------

(defun %json-escape (s)
  "Escape S for embedding in a JSON string literal."
  (with-output-to-string (out)
    (loop for ch across s
          do (case ch
               (#\" (write-string "\\\"" out))
               (#\\ (write-string "\\\\" out))
               (#\Newline (write-string "\\n" out))
               (#\Return (write-string "\\r" out))
               (#\Tab (write-string "\\t" out))
               (otherwise (write-char ch out))))))

(defun %http-post-json (url data &key (max-time 60) headers)
  "POST DATA (JSON string) to URL via curl. Returns (values body exit-code).
HEADERS is a list of \"Name: value\" strings. Uses sb-ext directly so this
data file stays loadable at runtime without depending on a plugin."
  (handler-case
      (let* ((args (append (list "-s" "--connect-timeout" "5"
                                 "--max-time" (write-to-string max-time)
                                 "-X" "POST" "-H" "Content-Type: application/json")
                           (loop for h in headers append (list "-H" h))
                           (list "-d" data url)))
             (out-str (make-string-output-stream))
             (err-str (make-string-output-stream))
             (proc (sb-ext:run-program "curl" args
                                       :output out-str :error err-str
                                       :search t :wait t)))
        (values (get-output-stream-string out-str)
                (sb-ext:process-exit-code proc)))
    (error (c)
      (values nil 127))))

(defun %endpoint-kind (model-endpoint)
  ":ollama when MODEL-ENDPOINT targets the native ollama API (port 11434),
else :openai (OpenAI-compatible /chat/completions)."
  (if (search ":11434" model-endpoint) :ollama :openai))

(defun %chat-url (model-endpoint kind)
  (if (eq kind :ollama)
      (concatenate 'string (string-right-trim "/" model-endpoint) "/api/chat")
      (concatenate 'string (string-right-trim "/" model-endpoint) "/chat/completions")))

(defun %chat-request-body (model prompt kind &key (temperature 0.0) (max-tokens nil))
  "Build the JSON request body for PROMPT against MODEL on KIND endpoint."
  (let ((escaped (%json-escape prompt)))
    (if (eq kind :ollama)
        (format nil "{\"model\":\"~A\",\"messages\":[{\"role\":\"user\",\"content\":\"~A\"}],\"stream\":false,\"options\":{\"temperature\":~F}}"
                model escaped temperature)
        (format nil "{\"model\":\"~A\",\"messages\":[{\"role\":\"user\",\"content\":\"~A\"}],\"stream\":false,\"temperature\":~F~@[,\"max_tokens\":~D~]}"
                model escaped temperature max-tokens))))

(defun %extract-content (body kind)
  "Extract the assistant content string from a chat response BODY."
  (let ((obj (jsown:parse body)))
    (if (eq kind :ollama)
        (jsown:val (jsown:val obj "message") "content")
        (let ((choices (jsown:val obj "choices")))
          (when (and choices (listp choices) (first choices))
            (jsown:val (jsown:val (first choices) "message") "content"))))))

(defun %extract-perf (body kind)
  "Extract timing/usage perf from a chat response BODY. Returns a plist.
Ollama native gives exact ns timing; OpenAI-compatible gives token counts."
  (let ((obj (jsown:parse body)))
    (if (eq kind :ollama)
        (let ((eval-count (jsown:val obj "eval_count"))
              (eval-dur (jsown:val obj "eval_duration"))
              (prefill-dur (jsown:val obj "prompt_eval_duration"))
              (load-dur (jsown:val-safe obj "load_duration")))
          (list :eval-count eval-count
                :eval-duration-ns eval-dur
                :prefill-duration-ns prefill-dur
                :load-duration-ns load-dur
                :tokens-per-sec (and (numberp eval-count) (numberp eval-dur)
                                     (plusp eval-dur)
                                     (/ eval-count (/ eval-dur 1e9)))
                :prefill-ms (and (numberp prefill-dur) (/ prefill-dur 1e6))))
        (let ((usage (jsown:val obj "usage")))
          (list :prompt-tokens (and usage (jsown:val usage "prompt_tokens"))
                :completion-tokens (and usage (jsown:val usage "completion_tokens"))
                :tokens-per-sec nil
                :prefill-ms nil)))))

(defun run-probe (probe model-endpoint &key (model "unsloth/gemma-4-12b-it-qat-GGUF")
                                       (max-time (probe-timeout probe))
                                       headers
                                       (temperature 0.0))
  "Run PROBE against MODEL at MODEL-ENDPOINT.
Returns (values score actual-output perf-plist). On any failure returns
(0.0 \"\" (:error message))."
  (let* ((kind (%endpoint-kind model-endpoint))
         (meta (probe-metadata probe))
         (max-tokens (or (getf meta :max-tokens) 500))
         (body (%chat-request-body model (probe-prompt probe) kind
                                   :temperature temperature
                                   :max-tokens max-tokens))
         (url (%chat-url model-endpoint kind)))
    (multiple-value-bind (resp code)
        (%http-post-json url body :max-time max-time :headers headers)
      (if (or (null resp) (not (zerop code)))
          (values 0.0 "" (list :error (format nil "HTTP ~A" code)))
          (handler-case
              (let ((content (%extract-content resp kind))
                    (perf (%extract-perf resp kind)))
                (if (null content)
                    (values 0.0 "" (list :error "no content in response"))
                    (values (funcall (probe-scorer probe) content)
                            content
                            perf)))
            (error (c)
              (values 0.0 "" (list :error (princ-to-string c)))))))))

(defun run-probe-suite (&key (probes *model-probes*)
                             (model-endpoint "http://127.0.0.1:11434")
                             (model "gemma-4-12b-it-qat")
                             headers)
  "Run all PROBES, return aggregate score + per-probe results.
Each result: (:id :name :category :score :output :perf)."
  (loop for probe in probes
        collect (multiple-value-bind (score output perf)
                    (run-probe probe model-endpoint :model model :headers headers)
                  (list :id (probe-id probe)
                        :name (probe-name probe)
                        :category (probe-category probe)
                        :score score
                        :output output
                        :perf perf))))

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

;;; --- Local snapshot writer ---------------------------------------------------

(defun %sysfs-vram (path)
  "Read a sysfs VRAM counter as an integer, or NIL."
  (handler-case
      (with-open-file (in path :direction :input :if-does-not-exist nil)
        (when in (parse-integer (read-line in))))
    (error () nil)))

(defun %vram-plist ()
  "Current VRAM totals/usage from sysfs (rootless)."
  (let ((card (or (and (probe-file "/sys/class/drm/card1/device/mem_info_vram_total") "card1")
                  (and (probe-file "/sys/class/drm/card0/device/mem_info_vram_total") "card0"))))
    (when card
      (list :drm-card card
            :vram-total-bytes (%sysfs-vram (format nil "/sys/class/drm/~A/device/mem_info_vram_total" card))
            :vram-used-bytes (%sysfs-vram (format nil "/sys/class/drm/~A/device/mem_info_vram_used" card))))))

(defun %date-stamp ()
  "YYYYMMDD for snapshot filenames."
  (multiple-value-bind (s m h d mo y) (get-decoded-time)
    (declare (ignore s m h))
    (format nil "~4,'0D~2,'0D~2,'0D" y mo d)))

(defun write-benchmark-snapshot (results &key (model "gemma-4-12b-it-qat")
                                            (endpoint "http://127.0.0.1:11434")
                                            (provider "ollama")
                                            (out-dir (merge-pathnames "data/" (asdf:system-source-directory :hngh))))
  "Write a dated snapshot JSON per the benchmark-sourcing design brief.
Returns the written pathname. RESULT entries: (:id :name :category :score
:perf ...); aggregate is the weighted mean over *model-probes* weights."
  (let* ((stamp (%date-stamp))
         (path (merge-pathnames (format nil "model-benchmarks-local-~A.json" stamp) out-dir))
         (vram (%vram-plist))
         (total 0.0) (weight 0.0))
    (dolist (r results)
      (let ((w (probe-weight (find (getf r :id) *model-probes* :key #'probe-id))))
        (incf total (* (getf r :score) w))
        (incf weight w)))
    (with-open-file (out path :direction :output :if-exists :supersede)
      (format out "{~%  \"fetched\": [\"run-probe\", \"sysfs-vram\"],~%  \"date\": \"~A\",~%"
              (multiple-value-bind (s m h d mo y) (get-decoded-time)
                (declare (ignore s m h))
                (format nil "~4,'0D-~2,'0D-~2,'0D" y mo d)))
      (format out "  \"provider\": \"~A\",~%  \"endpoint\": \"~A\",~%" provider endpoint)
      (format out "  \"model\": \"~A\",~%" model)
      (when vram
        (format out "  \"vram\": {~%    \"drm_card\": \"~A\",~%    \"total_bytes\": ~A,~%    \"used_bytes\": ~A~%  },~%"
                (getf vram :drm-card) (getf vram :vram-total-bytes) (getf vram :vram-used-bytes)))
      (format out "  \"aggregate_score\": ~,3F,~%" (if (zerop weight) 0.0 (/ total weight)))
      (format out "  \"probes\": [~%")
      (loop for r in results
            for i from 0
            do (format out "    {~%      \"id\": \"~A\",~%      \"name\": \"~A\",~%      \"category\": \"~A\",~%      \"score\": ~,3F,~%      \"perf\": ~A~%    }~A~%"
                        (getf r :id) (getf r :name) (getf r :category) (getf r :score)
                        (let ((p (getf r :perf)))
                          (if (getf p :error)
                              (format nil "{\"error\":\"~A\"}" (getf p :error))
                              (format nil "{\"tokens_per_sec\":~A,\"prefill_ms\":~A}"
                                      (if (getf p :tokens-per-sec)
                                          (format nil "~,2F" (getf p :tokens-per-sec))
                                          "null")
                                      (if (getf p :prefill-ms)
                                          (format nil "~,1F" (getf p :prefill-ms))
                                          "null"))))
                        (if (= i (1- (length results))) "" ",")))
      (format out "  ]~%}~%"))
    path))

;;; --- Export ----------------------------------------------------------------

(export '(*model-probes*
          run-probe
          run-probe-suite
          probe-suite-report
          write-benchmark-snapshot
          validate-json-schema
          make-scorer-exact
          make-scorer-regex
          make-scorer-keywords
          make-scorer-property
          make-scorer-json-schema
          make-scorer-min-lines
          make-scorer-no-forbidden
          make-scorer-combinator)
        :hngh.data.model-probes)