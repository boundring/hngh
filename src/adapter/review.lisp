(in-package #:hngh.adapters.review)

;;; Rung 6: bounded model-review adapter. The adapter turns a closed review
;;; request into one fixed, deterministic prompt, sends it through the
;;; injected reviewer transport, and maps the model's structured output into
;;; immutable review findings plus one domain evidence fact. Reviews ADVISE
;;; only: findings feed certificate binding and the evidence ledger, and no
;;; reviewer can issue a certificate, advance a run, or execute a mutation.
;;; Unknown, malformed, duplicate, oversized, or unauthorized output fails
;;; closed to a typed refusal; a failed review call becomes an :unverifiable
;;; evidence fact. The adapter never contacts a provider itself: every call
;;; sits behind the injected invoke-reviewer callback and no default
;;; transport is supplied.

(defparameter +max-candidate-paths+ 64)
(defparameter +max-path-length+ 200)
(defparameter +max-context-labels+ 20)
(defparameter +max-finding-label-length+ 200)
(defparameter +max-finding-citation-length+ 200)
(defparameter +max-review-findings+ 32)
(defparameter +max-review-response-length+ 65536
  "Bounded model output: anything larger refuses as output-too-large.")
(defparameter +max-json-depth+ 16)

;;; Refusals ------------------------------------------------------------

(define-condition review-output-error (error)
  ((label :initarg :label :reader review-output-error-label))
  (:report (lambda (condition stream)
             (format stream "review output refused: ~A"
                     (review-output-error-label condition)))))

(defun output-refusal (label)
  (error 'review-output-error :label label))

(defun output-fail (label &optional message)
  (declare (ignore message))
  (output-refusal label))

;;; Paths --------------------------------------------------------------------

(defun path-components (path)
  (loop with components = '()
        for start = 0 then (1+ end)
        for end = (or (position #\/ path :start start) (length path))
        do (push (subseq path start end) components)
        while (< end (length path))
        finally (return (nreverse components))))

(defun safe-relative-path-p (path)
  (and (stringp path)
       (plusp (length path))
       (<= (length path) +max-path-length+)
       (not (find #\\ path))
       (let ((first-char (char path 0)))
         (not (or (char= first-char #\-)
                  (char= first-char #\/)
                  (char= first-char #\~))))
       (notany (lambda (char)
                 (or (char< char #\Space) (char= char (code-char 127))))
               path)
       (notany (lambda (component)
                 (member component '("" "." "..") :test #'string=))
               (path-components path))))

(defun ensure-path-list (value name)
  (unless (and (listp value)
               value
               (<= (length value) +max-candidate-paths+)
               (every #'safe-relative-path-p value)
               (= (length value)
                  (length (remove-duplicates value :test #'string=))))
    (error "~A must be a bounded duplicate-free list of safe relative paths"
           name))
  (mapcar #'copy-seq value))

(defun printable-string-p (value max-length)
  (and (stringp value)
       (plusp (length value))
       (<= (length value) max-length)
       (notany (lambda (char)
                 (or (char< char #\Space) (char= char (code-char 127))))
               value)))

(defun ensure-context-labels (value)
  (unless (and (listp value)
               value
               (<= (length value) +max-context-labels+)
               (every (lambda (label) (printable-string-p label 200)) value)
               (= (length value)
                  (length (remove-duplicates value :test #'string=))))
    (error "Policy context must be a nonempty bounded duplicate-free list of printable labels"))
  (mapcar #'copy-seq value))

(defun ensure-content-hash (value)
  (unless (printable-string-p value 256)
    (error "Content hash must be a nonempty printable string"))
  (copy-seq value))

;;; Review request ----------------------------------------------------------

(defstruct (review-request
            (:constructor %make-review-request
                (candidate-paths content-hash policy-context))
            (:conc-name %review-request-))
  (candidate-paths nil :read-only t)
  (content-hash nil :read-only t)
  (policy-context nil :read-only t))

(defun review-request-candidate-paths (request)
  (mapcar #'copy-seq (%review-request-candidate-paths request)))

(defun review-request-content-hash (request)
  (copy-seq (%review-request-content-hash request)))

(defun review-request-policy-context (request)
  (mapcar #'copy-seq (%review-request-policy-context request)))

(defun make-review-request (&key (candidate-paths nil candidate-paths-p)
                             (content-hash nil content-hash-p)
                             (policy-context nil policy-context-p))
  (unless (and candidate-paths-p content-hash-p policy-context-p)
    (error "Review request fields are required"))
  (when (null candidate-paths)
    (error "Review request requires at least one candidate path"))
  (%make-review-request
   (ensure-path-list candidate-paths "candidate paths")
   (ensure-content-hash content-hash)
   (ensure-context-labels policy-context)))

;;; Transport port ----------------------------------------------------------

(defstruct (review-ports
            (:constructor %make-review-ports (invoke-reviewer))
            (:conc-name %review-ports-))
  (invoke-reviewer nil :read-only t))

(defun make-review-ports (&key invoke-reviewer)
  (unless (functionp invoke-reviewer)
    (error "review ports require an invoke-reviewer callback"))
  (%make-review-ports invoke-reviewer))

(defun transport-response (ports prompt)
  "Invoke the injected reviewer callback. Returns (values t exit-code stdout
stderr) or (values nil nil nil nil) for a thrown error or a malformed return."
  (handler-case
      (multiple-value-bind (exit-code stdout stderr)
          (funcall (%review-ports-invoke-reviewer ports) prompt)
        (if (and (integerp exit-code)
                 (not (minusp exit-code))
                 (stringp stdout)
                 (stringp stderr))
            (values t exit-code stdout stderr)
            (values nil nil nil nil)))
    (error () (values nil nil nil nil))))

;;; Findings ---------------------------------------------------------------

(defstruct (review-finding
            (:constructor %make-review-finding (label citation))
            (:conc-name %review-finding-))
  (label nil :read-only t)
  (citation nil :read-only t))

(defun review-finding-label (finding)
  (copy-seq (%review-finding-label finding)))

(defun review-finding-citation (finding)
  (copy-seq (%review-finding-citation finding)))

;;; Result -------------------------------------------------------------------

(defstruct (review-result
            (:constructor %make-review-result
                (status findings fact refusal-labels))
            (:conc-name %review-result-))
  (status nil :read-only t)
  (findings nil :read-only t)
  (fact nil :read-only t)
  (refusal-labels nil :read-only t))

(defun review-result-status (result)
  (%review-result-status result))

(defun review-result-findings (result)
  (copy-list (%review-result-findings result)))

(defun review-result-fact (result)
  (%review-result-fact result))

(defun review-result-refusal-labels (result)
  (mapcar #'copy-seq (%review-result-refusal-labels result)))

(defun complete-review (findings fact)
  (%make-review-result :complete findings fact nil))

(defun refused-review (labels)
  (%make-review-result :refused nil nil labels))

;;; Prompt ------------------------------------------------------------------
;;; One fixed JSON template assembled from the closed request fields only.
;;; No caller-supplied free text is embedded into the prompt.

(defun json-escape-string (text)
  (with-output-to-string (out)
    (write-char #\" out)
    (loop for char across text
          do (case char
               (#\" (write-string "\\\"" out))
               (#\\ (write-string "\\\\" out))
               (#\Newline (write-string "\\n" out))
               (#\Tab (write-string "\\t" out))
               (#\Return (write-string "\\r" out))
               (otherwise
                (if (char< char #\Space)
                    (format out "\\u~4,'0x" (char-code char))
                    (write-char char out)))))
    (write-char #\" out)))

(defun build-review-prompt (request)
  (with-output-to-string (out)
    (write-string "{\"content-hash\":" out)
    (write-string (json-escape-string (%review-request-content-hash request)) out)
    (write-string ",\"candidate-paths\":[" out)
    (loop for (path . rest) on (%review-request-candidate-paths request)
          do (write-string (json-escape-string path) out)
          when rest do (write-char #\, out))
    (write-string "],\"policy-context\":[" out)
    (loop for (label . rest) on (%review-request-policy-context request)
          do (write-string (json-escape-string label) out)
          when rest do (write-char #\, out))
    (write-string "],\"output\":{\"findings\":[{\"label\":string," out)
    (write-string "\"citation\":string}]}}" out)))

;;; Structured output -------------------------------------------------------
;;; A strict, minimal JSON reader for the fixed output contract:
;;;   {"findings":[{"label": string, "citation": string}, ...]}
;;; Values are tagged: strings are plain strings; objects are
;;; (object . alist); arrays are (array . items). Unknown keys, duplicate
;;; keys, numbers, booleans, nulls, deep nesting, and trailing garbage all
;;; fail closed as malformed output.

(defun json-skip-ws (text index)
  (loop while (and (< index (length text))
                   (find (char text index) '(#\Space #\Tab #\Newline #\Return)))
        do (incf index))
  index)

(defun hex-digit-value (char)
  (cond ((and (char<= #\0 char) (char<= char #\9))
         (- (char-code char) (char-code #\0)))
        ((and (char<= #\a char) (char<= char #\f))
         (+ 10 (- (char-code char) (char-code #\a))))
        ((and (char<= #\A char) (char<= char #\F))
         (+ 10 (- (char-code char) (char-code #\A))))
        (t (output-fail "malformed-output" "invalid unicode escape"))))

(defun json-parse-string (text index)
  (unless (and (< index (length text)) (char= (char text index) #\"))
    (output-fail "malformed-output" "expected string"))
  (let ((out (make-string-output-stream))
        (i (1+ index)))
    (loop
      (when (>= i (length text))
        (output-fail "malformed-output" "unterminated string"))
      (let ((char (char text i)))
        (cond
          ((char= char #\")
           (return (values (get-output-stream-string out) (1+ i))))
          ((char= char #\\)
           (when (>= (1+ i) (length text))
             (output-fail "malformed-output" "unterminated escape"))
           (let ((esc (char text (1+ i))))
             (case esc
               ((#\" #\\ #\/) (write-char esc out) (incf i 2))
               (#\b (write-char #\Backspace out) (incf i 2))
               (#\f (write-char #\Page out) (incf i 2))
               (#\n (write-char #\Newline out) (incf i 2))
               (#\r (write-char #\Return out) (incf i 2))
               (#\t (write-char #\Tab out) (incf i 2))
               (#\u
                (when (< (length text) (+ i 6))
                  (output-fail "malformed-output" "short unicode escape"))
                (let ((value 0))
                  (dotimes (offset 4)
                    (setf value (+ (* value 16)
                                   (hex-digit-value (char text (+ i 2 offset))))))
                  (when (and (<= #x0000D800 value) (<= value #x0000DFFF))
                    (output-fail "malformed-output" "unicode surrogate escape"))
                  (let ((char (code-char value)))
                    (unless char
                      (output-fail "malformed-output" "invalid unicode codepoint"))
                    (write-char char out))
                  (incf i 6)))
               (t (output-fail "malformed-output" "unknown escape")))))
          (t (write-char char out) (incf i)))))))

(defun json-parse-value (text index depth)
  (setf index (json-skip-ws text index))
  (when (> depth +max-json-depth+)
    (output-fail "malformed-output" "output nested too deeply"))
  (when (>= index (length text))
    (output-fail "malformed-output" "unexpected end"))
  (let ((char (char text index)))
    (cond
      ((char= char #\{) (json-parse-object text index (1+ depth)))
      ((char= char #\[) (json-parse-array text index (1+ depth)))
      ((char= char #\") (json-parse-string text index))
      (t (output-fail "malformed-output" "unexpected value")))))

(defun json-parse-object (text index depth)
  "Parse an object whose opening brace sits at INDEX. Returns
(values (object . alist) next-index)."
  (let* ((index (json-skip-ws text (1+ index)))
         (closing (and (< index (length text))
                       (char= (char text index) #\}))))
    (if closing
        (values (cons :object nil) (1+ index))
        (let ((entries '()))
          (loop
            (setf index (json-skip-ws text index))
            (when (>= index (length text))
              (output-fail "malformed-output" "unterminated object"))
            (let ((char (char text index)))
              (when (char= char #\})
                (return (values (cons :object (nreverse entries)) (1+ index))))
              (unless (char= char #\")
                (output-fail "malformed-output" "expected string key"))
              (multiple-value-bind (key after-key)
                  (json-parse-string text index)
                (setf index (json-skip-ws text after-key))
                (when (or (>= index (length text))
                          (char/= (char text index) #\:))
                  (output-fail "malformed-output" "expected colon"))
                (multiple-value-bind (value after-value)
                    (json-parse-value text (1+ index) depth)
                  (when (member key entries :test #'string= :key #'car)
                    (output-fail "malformed-output" "duplicate key"))
                  (push (cons key value) entries)
                  (setf index (json-skip-ws text after-value))
                  (when (>= index (length text))
                    (output-fail "malformed-output" "unterminated object"))
                  (let ((char (char text index)))
                    (cond
                      ((char= char #\,) (setf index (1+ index)))
                      ((char= char #\})
                       (return (values (cons :object (nreverse entries))
                                       (1+ index))))
                      (t (output-fail "malformed-output"
                                      "expected comma or close brace"))))))))))))

(defun json-parse-array (text index depth)
  "Parse an array whose opening bracket sits at INDEX. Returns
(values (array . items) next-index)."
  (let ((index (json-skip-ws text (1+ index))))
    (if (and (< index (length text)) (char= (char text index) #\]))
        (values (cons :array nil) (1+ index))
        (let ((items '()))
          (loop
            (multiple-value-bind (value after-value)
                (json-parse-value text index depth)
              (push value items)
              (setf index (json-skip-ws text after-value)))
            (when (>= index (length text))
              (output-fail "malformed-output" "unterminated array"))
            (let ((char (char text index)))
              (when (char= char #\,)
                (incf index))
              (when (char= char #\])
                (return (values (cons :array (nreverse items)) (1+ index))))
              (unless (or (char= char #\,) (char= char #\]))
                (output-fail "malformed-output" "expected comma or close bracket"))))))))

(defun json-parse-envelope (text)
  "Parse the full output document. Refuses trailing garbage and non-object
roots. Returns (object . alist)."
  (multiple-value-bind (value next)
      (json-parse-value text 0 0)
    (let ((next (json-skip-ws text next)))
      (unless (= next (length text))
        (output-fail "malformed-output" "trailing characters"))
      (unless (and (consp value) (eq (car value) :object))
        (output-fail "malformed-output" "output root must be an object"))
      value)))

;;; Findings extraction ----------------------------------------------------

(defun envelope-findings (envelope)
  (let ((entries (cdr envelope)))
    (unless (= 1 (length entries))
      (output-fail "malformed-output" "output must contain exactly one top-level key"))
    (let ((pair (car entries)))
      (unless (string= "findings" (car pair))
        (output-fail "malformed-output" "unknown top-level key"))
      (let ((tagged (cdr pair)))
        (unless (and (consp tagged) (eq (car tagged) :array))
          (output-fail "malformed-output" "findings must be an array"))
        (cdr tagged)))))

(defun finding-label-and-citation (entry)
  (let ((entries (cdr entry)))
    (unless (= 2 (length entries))
      (output-fail "malformed-output" "each finding must have exactly label and citation"))
    (let ((label-entry (assoc "label" entries :test #'string=))
          (citation-entry (assoc "citation" entries :test #'string=)))
      (unless (and label-entry citation-entry)
        (output-fail "malformed-output" "finding must have exactly label and citation"))
      (values (cdr label-entry) (cdr citation-entry)))))

(defun string-value (tagged)
  (if (stringp tagged)
      tagged
      (output-fail "malformed-output" "finding fields must be strings")))

(defun extract-findings (envelope)
  "Return the bounded, duplicate-free list of sanitized review findings, or
refuse with a closed label."
  (let ((items (envelope-findings envelope)))
    (when (> (length items) +max-review-findings+)
      (output-fail "too-many-findings" "finding count exceeds the bound"))
    (let ((result '())
          (labels '()))
      (dolist (item items)
        (unless (and (consp item) (eq (car item) :object))
          (output-fail "malformed-output" "each finding must be an object"))
        (multiple-value-bind (label citation)
            (finding-label-and-citation item)
          (let ((label (string-value label))
                (citation (string-value citation)))
            (when (member label labels :test #'string=)
              (output-fail "duplicate-finding" "finding labels must be unique"))
            (push label labels)
            (push (sanitize-finding label citation) result))))
      (nreverse result))))

(defun sanitize-finding (label citation)
  (unless (printable-string-p label +max-finding-label-length+)
    (output-fail "unsafe-finding" "finding label is missing, too long, or unprintable"))
  (unless (printable-string-p citation +max-finding-citation-length+)
    (output-fail "unsafe-finding" "finding citation is missing, too long, or unprintable"))
  (%make-review-finding (copy-seq label) (copy-seq citation)))

;;; Review facts ------------------------------------------------------------

(defun review-fingerprint (request findings)
  (let ((labels (sort (mapcar #'review-finding-label findings) #'string<)))
    (format nil "~A|~{~A~^,~}" (%review-request-content-hash request) labels)))

(defun current-review-fact (request findings)
  (hngh.domain:make-evidence-fact
   :kind :review
   :fingerprint (review-fingerprint request findings)
   :state :current))

(defun review-unavailable-fact ()
  (hngh.domain:make-evidence-fact
   :kind :review
   :fingerprint "unavailable"
   :state :unverifiable))

;;; Entry point -------------------------------------------------------------

(defun request-review (request ports)
  "Send one closed REVIEW-REQUEST to the injected REVIEW-PORTS transport and
return a closed REVIEW-RESULT. Malformed or unauthorized model output refuses;
a failed review call yields an :unverifiable review fact; a transport fault
yields a transport-fault refusal. No provider call happens here: the prompt is
handed to the injected invoke-reviewer callback."
  (unless (review-request-p request)
    (error "request-review requires a review request"))
  (unless (review-ports-p ports)
    (error "request-review requires review ports"))
  (let ((prompt (build-review-prompt request)))
    (multiple-value-bind (ok exit-code stdout stderr)
        (transport-response ports prompt)
      (declare (ignore stderr))
      (cond
        ((not ok)
         (refused-review '("transport-fault")))
        ((not (zerop exit-code))
         (complete-review nil (review-unavailable-fact)))
        ((> (length stdout) +max-review-response-length+)
         (refused-review '("output-too-large")))
        (t
         (handler-case
             (let* ((envelope (json-parse-envelope stdout))
                    (findings (extract-findings envelope)))
               (complete-review findings
                                (current-review-fact request findings)))
           (review-output-error (error)
             (refused-review (list (review-output-error-label error))))))))))