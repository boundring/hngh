(in-package #:hngh.adapters.model)

;;; Rung 10: bounded model transport factory. The review adapter already
;;; defines the closed request/response contract (one fixed prompt, bounded
;;; structured output, sanitized findings, one review evidence fact); this
;;; adapter only supplies the transport shape for a real provider.
;;; MAKE-MODEL-TRANSPORTS captures a closed provider configuration and
;;; returns the COMPLETE callback every transport uses — (lambda (prompt)
;;; (values exit-code stdout stderr)), the same shape as the evidence
;;; process-run and the review invoke-reviewer consumers — ready to wrap as
;;; MAKE-REVIEW-PORTS :INVOKE-REVIEWER and drive through
;;; hngh.main:request-run-review. The provider is reached only through the
;;; installed curl binary (the same subprocess transport style as the
;;; evidence adapter's git and sha256sum); there is no default provider, no
;;; live endpoint, and no provider call at load or import time. A provider
;;; failure returns a nonzero exit-code, which the review adapter maps to an
;;; :unverifiable "unavailable" evidence fact, so this adapter introduces no
;;; refusal vocabulary of its own and never decides policy. The route gate —
;;; a non-local route-label plus the model-review network label on the run
;;; loadout — is enforced by the application admission layer, not here.

(defparameter +max-model-prompt-length+ 65536
  "Bound on one review prompt this transport accepts: anything larger
refuses before any provider is contacted.")

(defparameter +max-model-completion-response-length+ 65536
  "Bound on the provider completion body on stdout: anything larger is
reported as a nonzero exit-code so the closed review mapping applies.")

(defun ensure-model-config-string (value name)
  (unless (and (stringp value) (plusp (length value)))
    (error "~A must be a nonempty string" name))
  (copy-seq value))

(defun ensure-model-positive-integer (value name)
  (unless (and (integerp value) (plusp value))
    (error "~A must be a positive integer" name))
  value)

(defun model-request-body (prompt model-name max-tokens)
  "The fixed provider request envelope: a chat-completions message carrying
the review prompt as the sole user turn, with thinking disabled so the
completion document is the answer rather than a reasoning trace. The
prompt is embedded as an escaped JSON string (via the review adapter's
shared escape helper). The provider token never enters the body."
  (format nil "{\"model\":\"~A\",\"max_tokens\":~D,\"enable_thinking\":false,\"messages\":[{\"role\":\"user\",\"content\":~A}]}"
          model-name max-tokens
          (hngh.adapters.review:json-escape-string prompt)))

;;; Provider envelope reading ------------------------------------------------
;;; The review adapter's JSON reader is deliberately closed to strings,
;;; objects, and arrays (numbers, booleans, and nulls refuse — that is the
;;; rung-6 output contract). A provider response envelope carries numbers
;;; everywhere (indices, timestamps, usage), so the model adapter reads it
;;; with its own minimal scanner: strings with escapes, objects, arrays,
;;; and every other literal consumed opaquely as :OPAQUE (the extraction
;;; only ever looks at strings). Any deviation signals; callers map a
;;; signal to a closed refusal.

(defun %model-json-skip-ws (text index)
  (loop while (and (< index (length text))
                   (find (char text index) " \t\n\r"))
        do (incf index))
  index)

(defun %model-json-string (text index)
  "Parse the JSON string starting at INDEX (its opening quote); returns
(values string index-after-closing-quote)."
  (let ((out (make-string-output-stream))
        (i (1+ index))
        (n (length text)))
    (loop
      (when (>= i n) (error "unterminated string"))
      (let ((ch (char text i)))
        (cond
          ((char= ch #\")
           (return (values (get-output-stream-string out) (1+ i))))
          ((char= ch #\\)
           (incf i)
           (when (>= i n) (error "unterminated escape"))
           (let ((esc (char text i)))
             (case esc
               ((#\" #\\ #\/) (write-char esc out))
               ((#\b) (write-char #\Backspace out))
               ((#\f) (write-char (code-char 12) out))
               ((#\n) (write-char #\Newline out))
               ((#\r) (write-char #\Return out))
               ((#\t) (write-char #\Tab out))
               ((#\u)
                (when (> (+ i 4) (1- n)) (error "truncated unicode escape"))
                (write-char (code-char
                             (parse-integer text :start (1+ i) :end (+ i 5)
                                            :radix 16))
                            out)
                (incf i 4))
               (t (error "unknown escape"))))
           (incf i))
          (t (write-char ch out) (incf i)))))))

(defun %model-json-value (text index)
  "Parse one JSON value at INDEX. Returns (values value index-after). The
tagged shape matches the review reader's: (:OBJECT . alist), (:ARRAY .
items), plain strings; every other literal is consumed as :OPAQUE."
  (let ((index (%model-json-skip-ws text index)))
    (when (>= index (length text)) (error "empty value"))
    (let ((ch (char text index)))
      (cond
        ((char= ch #\") (%model-json-string text index))
        ((char= ch #\{)
         (let ((alist '())
               (i (%model-json-skip-ws text (1+ index))))
           (when (and (< i (length text)) (char= (char text i) #\}))
             (return-from %model-json-value
               (values (cons :object alist) (1+ i))))
           (loop
             (setq i (%model-json-skip-ws text i))
             (when (or (>= i (length text)) (char/= (char text i) #\"))
               (error "object key expected"))
             (multiple-value-bind (key after-key) (%model-json-string text i)
               (setq i (%model-json-skip-ws text after-key))
               (when (or (>= i (length text)) (char/= (char text i) #\:))
                 (error "colon expected"))
               (multiple-value-bind (value after-value)
                   (%model-json-value text (1+ i))
                 (push (cons key value) alist)
                 (setq i (%model-json-skip-ws text after-value))
                 (cond
                   ((and (< i (length text)) (char= (char text i) #\,))
                    (incf i))
                   ((and (< i (length text)) (char= (char text i) #\}))
                    (return (values (cons :object (nreverse alist)) (1+ i))))
                   (t (error "comma or close-brace expected"))))))))
        ((char= ch #\[)
         (let ((items '())
               (i (%model-json-skip-ws text (1+ index))))
           (when (and (< i (length text)) (char= (char text i) #\]))
             (return-from %model-json-value
               (values (cons :array items) (1+ i))))
           (loop
             (multiple-value-bind (value after-value)
                 (%model-json-value text i)
               (push value items)
               (setq i (%model-json-skip-ws text after-value))
               (cond
                 ((and (< i (length text)) (char= (char text i) #\,))
                  (incf i))
                 ((and (< i (length text)) (char= (char text i) #\]))
                  (return (values (cons :array (nreverse items)) (1+ i))))
                 (t (error "comma or close-bracket expected")))))))
        (t
         (let ((start index))
           (loop while (and (< index (length text))
                            (not (find (char text index) " \t\n\r,]}")))
                 do (incf index))
           (when (= index start) (error "unrecognized value"))
           (values :opaque index)))))))

(defun %model-json-document (text)
  "Parse exactly one JSON document spanning all of TEXT."
  (multiple-value-bind (value index) (%model-json-value text 0)
    (let ((index (%model-json-skip-ws text index)))
      (unless (= index (length text)) (error "trailing characters"))
      value)))

(defun model-response-content (response-text)
  "The completion document from one provider response envelope: the first
choice's `text` (completions shape) or its `message.content` (chat
shape), read with the model adapter's own envelope scanner (numbers,
booleans, and nulls are consumed opaquely). Any deviation — malformed
JSON, a non-object root, no choices, a first choice without text or
message content, non-string fields — returns NIL, which the transport
maps to a closed nonzero exit-code. Pure: no I/O."
  (labels ((object-alist (tagged)
             (and (consp tagged) (eq :object (car tagged)) (cdr tagged)))
           (array-items (tagged)
             (and (consp tagged) (eq :array (car tagged)) (cdr tagged))))
    (handler-case
        (let* ((root (object-alist (%model-json-document response-text)))
               (choices (and root
                             (array-items
                              (cdr (assoc "choices" root :test #'string=)))))
               (first-choice (and choices (object-alist (first choices))))
               (text (and first-choice
                          (cdr (assoc "text" first-choice :test #'string=))))
               (message (and first-choice
                             (object-alist
                              (cdr (assoc "message" first-choice
                                          :test #'string=)))))
               (content (and message
                             (cdr (assoc "content" message :test #'string=)))))
          (cond ((stringp text) text)
                ((stringp content) content)
                (t nil)))
      (error () nil))))

(defun make-model-transports (&key endpoint model-name max-tokens timeout
                                   provider-token)
  "Validate the closed provider configuration and return the COMPLETE
transport callback: (lambda (prompt) (values exit-code stdout stderr)).
The provider is contacted through the installed curl binary with the
envelope from MODEL-REQUEST-BODY on stdin; a successful call returns the
model's completion document (extracted from the provider response
envelope by MODEL-RESPONSE-CONTENT) as stdout. A failing, timed-out,
unparseable, or oversized completion is reported as a nonzero exit-code
with the raw response as stderr-side diagnostics so the caller's closed
mapping (an :unverifiable review fact) applies. The provider token
travels only in the Authorization header of that one subprocess call and
never enters the prompt, the request envelope, or any result."
  (let ((endpoint (ensure-model-config-string endpoint "endpoint"))
        (timeout (ensure-model-positive-integer timeout "timeout"))
        (model-name (ensure-model-config-string model-name "model name"))
        (max-tokens (ensure-model-positive-integer max-tokens "max tokens"))
        (provider-token (ensure-model-config-string provider-token
                                                    "provider token")))
    (lambda (prompt)
      (unless (and (stringp prompt)
                   (<= (length prompt) +max-model-prompt-length+))
        (error "model prompt exceeds the ~D byte bound"
               +max-model-prompt-length+))
      (let ((body (model-request-body prompt model-name max-tokens)))
        (multiple-value-bind (stdout stderr exit-code)
            (uiop:run-program
             (list "curl" "--silent" "--show-error" "--fail"
                   "--max-time" (princ-to-string timeout)
                   "--request" "POST" endpoint
                   "--header" "Content-Type: application/json"
                   "--header" (format nil "Authorization: Bearer ~A"
                                      provider-token)
                   "--data-binary" "@-")
             :input (make-string-input-stream body)
             :output :string :error-output :string
             :ignore-error-status t)
          (cond
            ((not (and (integerp exit-code) (zerop exit-code)))
             (values exit-code stdout stderr))
            ((> (length stdout)
                +max-model-completion-response-length+)
             (values 75 stdout stderr))
            (t (let ((content (model-response-content stdout)))
                 (if content
                     (values 0 content stderr)
                     (values 75 stdout stderr))))))))))