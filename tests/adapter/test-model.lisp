(in-package #:hngh.tests)

;;; Rung 10 model transport factory tests. MAKE-MODEL-TRANSPORTS validates
;;; the closed provider configuration and returns a COMPLETE callback of
;;; the transport shape; no test invokes the callback against a provider
;;; (no live endpoint, no network, no subprocess), so the provider call
;;; itself stays fixture-free, exactly as the review adapter's provider
;;; calls do.

(defun model-symbol (name)
  (let ((package (find-package :hngh.adapters.model)))
    (unless package
      (error "model adapter package is unavailable"))
    (multiple-value-bind (symbol status) (find-symbol name package)
      (unless (and symbol (eq status :external))
        (error "model symbol is unavailable: ~A" name))
      symbol)))

(defun model-function (name)
  (let ((symbol (model-symbol name)))
    (unless (fboundp symbol)
      (error "model function is unavailable: ~A" name))
    (symbol-function symbol)))

(defun model-call (name &rest arguments)
  (apply (model-function name) arguments))

(defparameter +model-config+
  '(:endpoint "https://model.example.invalid/v1" :model-name "reviewer-1"
    :max-tokens 2048 :timeout 30 :provider-token "token-abc"))

(check (not (null (find-symbol "MAKE-MODEL-TRANSPORTS" "HNGH.ADAPTERS.MODEL")))
       "make-model-transports resolves in the model adapter package")
(check (not (null (find-symbol "MODEL-REQUEST-BODY" "HNGH.ADAPTERS.MODEL")))
       "model-request-body resolves in the model adapter package")

;;; Construction validates the closed configuration and returns the shape ----

(let ((complete (apply #'model-call "MAKE-MODEL-TRANSPORTS" +model-config+)))
  (declare (ignore complete))
  (check (functionp complete)
         "make-model-transports returns a complete callback")
  (check (signals-error-p (lambda () (funcall complete :not-a-prompt)))
         "the callback refuses a malformed prompt before any provider call"))

(dolist (missing '((:model-name "m" :max-tokens 1 :timeout 1 :provider-token "t")
                   (:endpoint "e" :max-tokens 1 :timeout 1 :provider-token "t")
                   (:endpoint "e" :model-name "m" :timeout 1 :provider-token "t")
                   (:endpoint "e" :model-name "m" :max-tokens 1 :provider-token "t")
                   (:endpoint "e" :model-name "m" :max-tokens 1 :timeout 1)))
  (check (signals-error-p (lambda () (apply #'model-call "MAKE-MODEL-TRANSPORTS" missing)))
         "missing model provider config refuses"))

(dolist (case '((:endpoint "" :model-name "m" :max-tokens 1 :timeout 1 :provider-token "t")
                (:endpoint "e" :model-name "" :max-tokens 1 :timeout 1 :provider-token "t")
                (:endpoint "e" :model-name "m" :max-tokens 0 :timeout 1 :provider-token "t")
                (:endpoint "e" :model-name "m" :max-tokens -1 :timeout 1 :provider-token "t")
                (:endpoint "e" :model-name "m" :max-tokens 1 :timeout 0 :provider-token "t")
                (:endpoint "e" :model-name "m" :max-tokens 1 :timeout 1 :provider-token "")
                (:endpoint 42 :model-name "m" :max-tokens 1 :timeout 1 :provider-token "t")
                (:endpoint "e" :model-name :symbol :max-tokens 1 :timeout 1 :provider-token "t")))
  (check (signals-error-p
          (lambda () (apply #'model-call "MAKE-MODEL-TRANSPORTS" case)))
         "malformed provider config refuses"))

;;; The request envelope carries the prompt once, escaped, with no token -----

(let ((body (model-call "MODEL-REQUEST-BODY"
                        "{\"content-hash\":\"h\"}"
                        "llama-1" 512)))
  (check (search "{\"model\":\"llama-1\",\"max_tokens\":512,\"enable_thinking\":false,\"messages\":[{\"role\":\"user\",\"content\":" body)
         "request envelope names the model, token bound, and chat turn")
  (check (search "content-hash" body)
         "request envelope embeds the review prompt")
  (check (not (search "token-abc" body))
         "request envelope never carries the provider token"))

;;; The transport boundary refuses an oversized prompt before any call -------

(let ((complete (apply #'model-call "MAKE-MODEL-TRANSPORTS" +model-config+)))
  (declare (ignore complete))
  (check (signals-error-p
          (lambda ()
            (funcall complete (make-string 65537 :initial-element #\x))))
         "an over-bound prompt refuses before the provider call"))

;;; The transport never contacts a provider at construction ------------------

(let ((complete (apply #'model-call "MAKE-MODEL-TRANSPORTS" +model-config+)))
  (declare (ignore complete))
  (check (functionp complete)
         "construction performs no provider call and returns the callback"))

;;; model-response-content: provider envelope -> completion document ----------

(check (not (null (find-symbol "MODEL-RESPONSE-CONTENT" "HNGH.ADAPTERS.MODEL")))
       "model-response-content resolves in the model adapter package")

(check (equal "PONG."
              (model-call "MODEL-RESPONSE-CONTENT"
                          "{\"choices\":[{\"text\":\"PONG.\",\"index\":0}]}"))
       "completions-shape envelope extracts the first choice text")

(check (equal "hello findings"
              (model-call "MODEL-RESPONSE-CONTENT"
                          "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"hello findings\"}}]}"))
       "chat-shape envelope extracts the message content")

(check (equal "first"
              (model-call "MODEL-RESPONSE-CONTENT"
                          "{\"choices\":[{\"message\":{\"content\":\"first\"}},{\"text\":\"second-choice-text\"}]}"))
       "the FIRST choice wins even when a later choice carries text")

(dolist (bad (list ""
                   "not json"
                   "{}"
                   "{\"choices\":[]}"
                   "{\"choices\":[{}]}"
                   "{\"choices\":[{\"text\":42}]}"
                   "{\"choices\":[{\"message\":{\"content\":null}}]}"
                   "[{\"text\":\"root-is-array\"}]"
                   "{\"unexpected\":\"root\"}"))
  (check (null (model-call "MODEL-RESPONSE-CONTENT" bad))
         (format nil "malformed provider envelope yields no content: ~S"
                 (subseq bad 0 (min 40 (length bad))))))

(check (equal "escaped \"quoted\" text"
              (model-call "MODEL-RESPONSE-CONTENT"
                          "{\"choices\":[{\"text\":\"escaped \\\"quoted\\\" text\"}]}"))
       "escaped strings in the envelope unescape into the document")
