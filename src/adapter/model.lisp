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
  "The fixed provider request envelope: the review prompt is embedded as an
escaped JSON string (via the review adapter's shared escape helper, its
only consumer) so the provider sees exactly one document. The provider
token never enters the body."
  (format nil "{\"model\":\"~A\",\"max_tokens\":~D,\"prompt\":~A}"
          model-name max-tokens
          (hngh.adapters.review:json-escape-string prompt)))

(defun make-model-transports (&key endpoint model-name max-tokens timeout
                                   provider-token)
  "Validate the closed provider configuration and return the COMPLETE
transport callback: (lambda (prompt) (values exit-code stdout stderr)).
The provider is contacted through the installed curl binary with the
envelope from MODEL-REQUEST-BODY on stdin; a failing, timed-out, or
oversized completion is reported as a nonzero exit-code so the caller's
closed mapping (an :unverifiable review fact) applies. The provider token
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
             :input body
             :output :string :error-output :string
             :ignore-error-status t)
          (cond
            ((and (integerp exit-code) (zerop exit-code)
                  (stringp stdout)
                  (> (length stdout)
                     +max-model-completion-response-length+))
             (values 75 nil stderr))
            (t (values exit-code stdout stderr))))))))