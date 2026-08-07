;;;; tests/unit/test-model-probes.lisp — Model probe suite tests
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring

(in-package :hngh.tests)

;; The probes file is a static data module loaded at runtime, not compiled
;; into the system. Load it explicitly so symbols resolve at compile time.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (load (asdf:system-relative-pathname :hngh "data/model-probes.lisp")))

(def-suite :hngh.model-probes
  :description "Model benchmark probe suite — procedural scorers and runner"
  :in :hngh)

(in-suite :hngh.model-probes)

(test mp-json-schema-valid
  "P5 scorer accepts a valid JSON object matching the schema."
  (let ((p (find :json-schema-task hngh.data.model-probes:*model-probes*
                 :key (lambda (x) (hngh.data.model-probes::probe-id x)))))
    (is (not (null p)))
    (is (= 1.0 (funcall (hngh.data.model-probes::probe-scorer p)
                        "{\"id\":\"task-123\",\"status\":\"done\",\"result\":\"ok\"}")))))

(test mp-json-schema-rejects
  "P5 scorer rejects bad enum, missing required key, and non-JSON."
  (let ((p (find :json-schema-task hngh.data.model-probes:*model-probes*
                 :key (lambda (x) (hngh.data.model-probes::probe-id x)))))
    (is (= 0.0 (funcall (hngh.data.model-probes::probe-scorer p)
                        "{\"id\":\"task-123\",\"status\":\"nope\"}")))
    (is (= 0.0 (funcall (hngh.data.model-probes::probe-scorer p)
                        "{\"status\":\"done\"}")))
    (is (= 0.0 (funcall (hngh.data.model-probes::probe-scorer p)
                        "not json")))))

(test mp-probe-count
  "The suite has 12 probes spanning the declared categories."
  (is (= 12 (length hngh.data.model-probes:*model-probes*)))
  (is (equal '(:elisp :bash :cl :doc :json :instruct :code :refactor :test
               :plan :debug :summarize)
             (mapcar (lambda (x) (hngh.data.model-probes::probe-category x))
                     hngh.data.model-probes:*model-probes*))))

(test mp-scorer-combinator-weighting
  "Weighted combination: 1.0*0.25 + 0.0*0.75 = 0.25."
  (let ((scorer (hngh.data.model-probes:make-scorer-combinator
                 (list (hngh.data.model-probes:make-scorer-exact "yes")
                       (hngh.data.model-probes:make-scorer-exact "no"))
                 (list 0.25 0.75))))
    (is (= 0.25 (funcall scorer "yes")))))

(test mp-scorer-json-escape
  "JSON string escaping handles quotes, newlines, and backslashes."
  (let ((escaped (hngh.data.model-probes::%json-escape
                  (concatenate 'string "say " (string #\")
                                "hi" (string #\")
                                (string #\Newline)
                                "back" (string #\\) "slash"))))
    (is (search "say \\\"hi\\\"" escaped))
    (is (search "\\n" escaped))
    (is (search "back\\\\slash" escaped))))

(test mp-snapshot-writer
  "write-benchmark-snapshot emits a dated JSON snapshot with aggregate."
  (let* ((tmp (make-tmp-home))
         (results (list (list :id :elisp-setq-default
                              :name "Set default value" :category :elisp
                              :score 1.0
                              :perf (list :tokens-per-sec 50.0 :prefill-ms 100.0))
                        (list :id :bash-find-recent
                              :name "Find files" :category :bash
                              :score 0.0
                              :perf (list :error "HTTP 500")))))
    (unwind-protect
         (let ((path (hngh.data.model-probes:write-benchmark-snapshot
                      results :model "test-model" :provider "ollama"
                      :endpoint "http://127.0.0.1:11434" :out-dir tmp)))
           (is (probe-file path))
           (let ((body (with-open-file (in path :direction :input)
                         (with-output-to-string (s)
                           (loop for line = (read-line in nil nil)
                                 while line do (write-string line s))))))
             (is (search "\"model\": \"test-model\"" body))
             (is (search "\"provider\": \"ollama\"" body))
             ;; aggregate = (1.0*1.0 + 0.0*1.0) / 2 = 0.5
             (is (search "\"aggregate_score\": 0.500" body))
             (is (search "\"tokens_per_sec\":50.00" body))
             (is (search "\"error\":\"HTTP 500\"" body))))
      (cleanup-tmp-home tmp))))

(test mp-endpoint-kind
  "Endpoint detection routes :11434 to ollama native, everything else to OpenAI."
  (is (eq :ollama (hngh.data.model-probes::%endpoint-kind "http://127.0.0.1:11434")))
  (is (eq :openai (hngh.data.model-probes::%endpoint-kind "http://127.0.0.1:8888/v1")))
  (is (eq :openai (hngh.data.model-probes::%endpoint-kind "https://openrouter.ai/api/v1"))))

(test mp-chat-request-body
  "Request body embeds model/prompt and escapes content."
  (let ((oll (hngh.data.model-probes::%chat-request-body
              "gemma-4-12b-it-qat" "say \"hi\"" :ollama)))
    (is (search "\"model\":\"gemma-4-12b-it-qat\"" oll))
    (is (search "say \\\"hi\\\"" oll))
    (is (search "\"options\"" oll)))
  (let ((oa (hngh.data.model-probes::%chat-request-body
             "org/model" "hello" :openai :max-tokens 42)))
    (is (search "\"max_tokens\":42" oa))
    (is (not (search "\"options\"" oa)))))

(test mp-extract-content
  "Content extraction handles both ollama and OpenAI response shapes."
  (is (string= "hello"
               (hngh.data.model-probes::%extract-content
                "{\"message\":{\"content\":\"hello\"}}" :ollama)))
  (is (string= "world"
               (hngh.data.model-probes::%extract-content
                "{\"choices\":[{\"message\":{\"content\":\"world\"}}]}" :openai))))

(test mp-extract-perf
  "Perf extraction computes tokens/sec from ollama ns timing."
  (let ((p (hngh.data.model-probes::%extract-perf
            "{\"eval_count\":100,\"eval_duration\":2000000000,\"prompt_eval_duration\":500000000}"
            :ollama)))
    (is (= 100 (getf p :eval-count)))
    (is (= 50.0 (getf p :tokens-per-sec)))
    (is (= 500.0 (getf p :prefill-ms)))))
