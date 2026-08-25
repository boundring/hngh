(in-package #:hngh.adapters.federation)

;;; Rung 11: bounded federation adapter. The adapter gathers remote
;;; evidence facts from an operator-carried bundle and verifies a remote
;;; attestation envelope, all through injected callbacks — never a wire,
;;; never a default peer, never a mutation. The gather side reads the
;;; carrier bundle through the injected FETCH-REMOTE transport, parses it
;;; with its own strict JSON reader, and maps the claims into domain
;;; evidence facts with the closed evidence-state vocabulary. The verify
;;; side runs the pure kernel verify-attestation-shape gate, resolves the
;;; signing key against the operator-pinned list, checks the signature
;;; through the injected callback, and checks the expiry window against the
;;; injected 'now'. Everything not explicitly pinned, signed, and in-window
;;; refuses closed. The adapter never decides policy, never reads a
;;; requirement ledger, and never uses a clock of its own.

(defparameter +federation-methods+ '(:carrier-bundle)
  "The closed method set. v1 admits carrier-bundle-only pull (bundles move
between machines by operator action); network claim methods may be added
later behind the same port without kernel change.")

(defparameter +max-bundle-length+ 65536
  "Bound on one fetched bundle document; larger output refuses closed.")

;;; Refusals ------------------------------------------------------------

(define-condition federation-output-error (error)
  ((label :initarg :label :reader federation-output-error-label))
  (:report (lambda (condition stream)
             (format stream "federation output refused: ~A"
                     (federation-output-error-label condition)))))

(defun output-refusal (label)
  (error 'federation-output-error :label label))

;;; Request -----------------------------------------------------------

(defun validate-request-peer (peer)
  (unless (and (stringp peer)
               (plusp (length peer))
               (<= (length peer) 64)
               (every (lambda (char)
                        (and (graphic-char-p char)
                             (not (find char ":/\\@\"<> "))))
                      peer))
    (error "federation peer must be a plain bounded identifier"))
  (copy-seq peer))

(defun validate-time-window (time-window)
  "A request time-window is (values start end) of UTC strings, both valid
and ordered, or NIL. The whole request is refused on a malformed window."
  (when time-window
    (let ((start (first time-window))
          (end (second time-window)))
      (unless (and (stringp start) (hngh.domain:utc-string-p start)
                   (stringp end) (hngh.domain:utc-string-p end)
                   (string<= start end))
        (error "federation time-window must be an ordered UTC pair"))
      (list (copy-seq start) (copy-seq end)))))

(defstruct (federation-request
            (:constructor %make-federation-request
                (peer method time-window max-facts))
            (:conc-name %federation-request-))
  (peer nil :read-only t)         ;; plain bounded identifier
  (method nil :read-only t)       ;; member of +federation-methods+
  (time-window nil :read-only t)  ;; (values start end) UTC strings or NIL
  (max-facts nil :read-only t))   ;; bound on the returned claim set

(defun federation-request-peer (request)
  (copy-seq (%federation-request-peer request)))
(defun federation-request-method (request)
  (%federation-request-method request))
(defun federation-request-time-window (request)
  (let ((window (%federation-request-time-window request)))
    (and window (list (copy-seq (first window))
                      (copy-seq (second window))))))
(defun federation-request-max-facts (request)
  (%federation-request-max-facts request))

(defun make-federation-request (&key peer method time-window max-facts)
  (unless (member method +federation-methods+)
    (error "federation method must be a closed member: ~S" method))
  (unless (or (null max-facts)
              (and (integerp max-facts) (plusp max-facts)))
    (error "federation max-facts must be nil or a positive integer"))
  (%make-federation-request
   (validate-request-peer peer)
   method
   (validate-time-window time-window)
   max-facts))

;;; Transport port ---------------------------------------------------

(defstruct (federation-ports
            (:constructor %make-federation-ports (fetch-remote))
            (:conc-name %federation-ports-))
  (fetch-remote nil :read-only t))

(defun make-federation-ports (&key fetch-remote)
  (unless (functionp fetch-remote)
    (error "federation ports require a fetch-remote callback"))
  (%make-federation-ports fetch-remote))

(defun transport-response (ports request)
  "Invoke the injected fetch-remote callback. Returns
(values t exit-code stdout stderr) or (values nil nil nil nil) for a
thrown error or a malformed return."
  (handler-case
      (multiple-value-bind (exit-code stdout stderr)
          (funcall (%federation-ports-fetch-remote ports) request)
        (if (and (integerp exit-code)
                 (not (minusp exit-code))
                 (stringp stdout)
                 (stringp stderr))
            (values t exit-code stdout stderr)
            (values nil nil nil nil)))
    (error () (values nil nil nil nil))))

;;; Result -----------------------------------------------------------

(defstruct (federation-result
            (:constructor %make-federation-result
                (status facts manifest refusal-labels))
            (:conc-name %federation-result-))
  (status nil :read-only t)      ;; :complete | :refused
  (facts nil :read-only t)       ;; domain evidence-facts
  (manifest nil :read-only t)    ;; domain source-manifest-entry (NIL allowed)
  (refusal-labels nil :read-only t))

(defun federation-result-status (result)
  (%federation-result-status result))
(defun federation-result-facts (result)
  (copy-list (%federation-result-facts result)))
(defun federation-result-manifest (result)
  (copy-list (%federation-result-manifest result)))
(defun federation-result-refusal-labels (result)
  (mapcar #'copy-seq (%federation-result-refusal-labels result)))

(defun complete-federation (facts manifest)
  (%make-federation-result :complete facts manifest nil))
(defun refused-federation (labels)
  (%make-federation-result :refused nil nil labels))

;;; Strict JSON reader -----------------------------------------------------
;;; A minimal, closed reader for the fixed carrier-bundle document. Values
;;; are tagged: strings stay plain strings; objects are
;;; (object . alist); arrays are (array . items); integers are
;;; (integer . n). Unknown keys, duplicate keys, numbers-in-strings,
;;; booleans, nulls, deep nesting, and trailing garbage all fail closed as
;;; malformed output. The reader understands only the exact bundle shape.

(defparameter +max-json-depth+ 16)

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
        (t (output-refusal "malformed-attestation"))))

(defun json-parse-string (text index)
  (unless (and (< index (length text)) (char= (char text index) #\"))
    (output-refusal "malformed-attestation"))
  (let ((out (make-string-output-stream))
        (i (1+ index)))
    (loop
      (when (>= i (length text))
        (output-refusal "malformed-attestation"))
      (let ((char (char text i)))
        (cond
          ((char= char #\")
           (return (values (get-output-stream-string out) (1+ i))))
          ((char= char #\\)
           (when (>= (1+ i) (length text))
             (output-refusal "malformed-attestation"))
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
                  (output-refusal "malformed-attestation"))
                (let ((value 0))
                  (dotimes (offset 4)
                    (setf value (+ (* value 16)
                                   (hex-digit-value (char text (+ i 2 offset))))))
                  (when (and (<= #xD800 value) (<= value #xDFFF))
                    (output-refusal "malformed-attestation"))
                  (let ((char (code-char value)))
                    (unless char
                      (output-refusal "malformed-attestation"))
                    (write-char char out))
                  (incf i 6)))
               (t (output-refusal "malformed-attestation")))))
          (t (write-char char out) (incf i)))))))

(defun json-parse-integer (text index)
  "Parse a non-negative integer literal at INDEX (no sign, no exponent,
no leading zeros, no fraction). Marvels at anything else."
  (let ((start index))
    (when (and (< index (length text))
               (char= (char text index) #\0)
               (< (1+ index) (length text))
               (digit-char-p (char text (1+ index))))
      (output-refusal "malformed-attestation"))
    (loop while (and (< index (length text))
                     (digit-char-p (char text index)))
          do (incf index))
    (when (= index start)
      (output-refusal "malformed-attestation"))
    (values (parse-integer text :start start :end index) index)))

(defun json-parse-value (text index depth)
  (setf index (json-skip-ws text index))
  (when (> depth +max-json-depth+)
    (output-refusal "malformed-attestation"))
  (when (>= index (length text))
    (output-refusal "malformed-attestation"))
  (let ((char (char text index)))
    (cond
      ((char= char #\{) (json-parse-object text index (1+ depth)))
      ((char= char #\[) (json-parse-array text index (1+ depth)))
      ((char= char #\") (json-parse-string text index))
      ((digit-char-p char) (json-parse-integer text index))
      (t (output-refusal "malformed-attestation")))))

(defun json-parse-object (text index depth)
  (let* ((index (json-skip-ws text (1+ index)))
         (closing (and (< index (length text))
                       (char= (char text index) #\}))))
    (if closing
        (values (cons :object nil) (1+ index))
        (let ((entries '()))
          (loop
            (setf index (json-skip-ws text index))
            (when (>= index (length text))
              (output-refusal "malformed-attestation"))
            (let ((char (char text index)))
              (when (char= char #\})
                (return (values (cons :object (nreverse entries)) (1+ index))))
              (unless (char= char #\")
                (output-refusal "malformed-attestation"))
              (multiple-value-bind (key after-key)
                  (json-parse-string text index)
                (setf index (json-skip-ws text after-key))
                (when (or (>= index (length text))
                          (char/= (char text index) #\:))
                  (output-refusal "malformed-attestation"))
                (multiple-value-bind (value after-value)
                    (json-parse-value text (1+ index) depth)
                  (when (member key entries :test #'string= :key #'car)
                    (output-refusal "malformed-attestation"))
                  (push (cons key value) entries)
                  (setf index (json-skip-ws text after-value))
                  (when (>= index (length text))
                    (output-refusal "malformed-attestation"))
                  (let ((char (char text index)))
                    (cond
                      ((char= char #\,) (setf index (1+ index)))
                      ((char= char #\})
                       (return (values (cons :object (nreverse entries))
                                       (1+ index))))
                      (t (output-refusal "malformed-attestation"))))))))))))

(defun json-parse-array (text index depth)
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
              (output-refusal "malformed-attestation"))
            (let ((char (char text index)))
              (when (char= char #\,)
                (incf index))
              (when (char= char #\])
                (return (values (cons :array (nreverse items)) (1+ index))))
              (unless (or (char= char #\,) (char= char #\]))
                (output-refusal "malformed-attestation"))))))))

(defun json-parse-envelope (text)
  (multiple-value-bind (value next)
      (json-parse-value text 0 0)
    (let ((next (json-skip-ws text next)))
      (unless (= next (length text))
        (output-refusal "malformed-attestation"))
      (unless (and (consp value) (eq (car value) :object))
        (output-refusal "malformed-attestation"))
      value)))

;;; Bundle document -----------------------------------------------------
;;; The fixed carrier-bundle v1 document:
;;;   { "peer": string, "key-identifier": string,
;;;     "payload": string, "signature": string,
;;;     "not-before": string, "not-after": string, "skew-seconds": integer,
;;;     "claims": [ { "kind": string, "fingerprint": string }, ... ] }
;;; The envelope level is strict: unknown fields, missing fields, wrong
;;; types, and negative skew all refuse as malformed-attestation. The
;;; claim level is tolerant in the evidence-state vocabulary: a claim
;;; whose kind is outside the closed set, or whose fields are broken,
;;; becomes a :malformed fact; a claim missing its fingerprint is
;;; :missing; a duplicate claim is :conflicting; a well-formed claim is
;;; :current (locally re-hashable) or :unverifiable. No good claim is
;;; thrown away because a sibling claim is bad.

(defun envelope-string (entries key)
  (let ((pair (assoc key entries :test #'string=)))
    (unless (and pair (stringp (cdr pair)))
      (output-refusal "malformed-attestation"))
    (cdr pair)))

(defun envelope-integer (entries key)
  "The non-negative integer value for KEY (a bare tagged integer)."
  (let ((pair (assoc key entries :test #'string=)))
    (unless (and pair (integerp (cdr pair)) (not (minusp (cdr pair))))
      (output-refusal "malformed-attestation"))
    (cdr pair)))

(defun envelope-claims (entries)
  (let ((pair (assoc "claims" entries :test #'string=)))
    (unless (and pair (consp (cdr pair)) (eq :array (car (cdr pair))))
      (output-refusal "malformed-attestation"))
    (cdr (cdr pair))))

(defun parse-bundle-envelope (text)
  "Strict-parse TEXT's envelope level and return the seven structural
values: (values peer key-identifier payload signature not-before
not-after skew raw-claims). Any envelope-level deviation signals
FEDERATION-OUTPUT-ERROR."
  (let* ((envelope (json-parse-envelope text))
         (entries (cdr envelope))
         (expected '("peer" "key-identifier" "payload" "signature"
                     "not-before" "not-after" "skew-seconds" "claims")))
    (dolist (name expected)
      (unless (assoc name entries :test #'string=)
        (output-refusal "malformed-attestation")))
    (dolist (pair entries)
      (unless (member (car pair) expected :test #'string=)
        (output-refusal "malformed-attestation")))
    (values (envelope-string entries "peer")
            (envelope-string entries "key-identifier")
            (envelope-string entries "payload")
            (envelope-string entries "signature")
            (envelope-string entries "not-before")
            (envelope-string entries "not-after")
            (envelope-integer entries "skew-seconds")
            (envelope-claims entries))))

(defun parse-attestation-envelope (text)
  "Parse TEXT into a domain REMOTE-ATTESTATION value. Used by the
verify path, where the whole envelope (including every claim) must be
structurally valid: strict field parsing, closed claim kinds, bounded
sizes, UTC expiry, and duplicate-free claims. Callers treat a throw as
a malformed-attestation refusal."
  (multiple-value-bind (peer key-identifier payload signature
                        not-before not-after skew raw-claims)
      (parse-bundle-envelope text)
    (when (minusp skew)
      (output-refusal "malformed-attestation"))
    (hngh.domain:make-remote-attestation
     :peer peer
     :key-identifier key-identifier
     :payload payload
     :signature signature
     :claims (mapcar (lambda (entry)
                       (let ((entries (cdr entry)))
                         (hngh.domain:make-remote-claim
                          :kind (intern (string-upcase
                                         (envelope-string entries "kind"))
                                        :keyword)
                          :fingerprint
                          (envelope-string entries "fingerprint"))))
                     raw-claims)
     :not-before not-before
     :not-after not-after
     :skew skew)))

;;; UTC seconds -----------------------------------------------------------
;;; Fixed-width UTC strings to universal-time seconds, for the expiry
;;; window check. Deterministic; no clock of the adapter's own.

(defun utc-seconds (text)
  "Universal-time seconds for a fixed-width UTC timestamp string, or NIL
for a malformed string (callers treat NIL as a clock/expiry fault)."
  (when (hngh.domain:utc-string-p text)
    (encode-universal-time
     (parse-integer text :start 17 :end 19)
     (parse-integer text :start 14 :end 16)
     (parse-integer text :start 11 :end 13)
     (parse-integer text :start 8 :end 10)
     (parse-integer text :start 5 :end 7)
     (parse-integer text :start 0 :end 4)
     0)))

;;; Gather ------------------------------------------------------------

(defun claim-fingerprint-wellformed-p (kind fingerprint)
  "True when the claim's fingerprint is locally re-hashable: a 64-hex
content hash for :content-hash or a 40-hex revision for
:repository-revision. Other kinds are not locally re-derivable hashes,
so they are never :current here (fail-closed; pinned-signature
verification happens in VERIFY-REMOTE-ATTESTATION)."
  (case kind
    (:content-hash
     (and (= 64 (length fingerprint))
          (every (lambda (char) (find char "0123456789abcdef"))
                 fingerprint)))
    (:repository-revision
     (and (= 40 (length fingerprint))
          (every (lambda (char) (find char "0123456789abcdef"))
                 fingerprint)))
    (t nil)))

(defun parse-claim-entry (entry)
  "Map one raw claim entry to a domain evidence fact with the closed
evidence-state vocabulary. A well-formed locally re-hashable claim is
:current; a well-formed non-hash claim is :unverifiable; a claim outside
the closed vocabulary or with broken fields is :malformed; a claim
missing its fingerprint is :missing."
  (unless (and (consp entry) (eq (car entry) :object))
    (return-from parse-claim-entry
      (hngh.domain:make-evidence-fact
       :kind :federated-claim :fingerprint "malformed" :state :malformed)))
  (let* ((entries (cdr entry))
         (kind-pair (assoc "kind" entries :test #'string=))
         (fingerprint-pair (assoc "fingerprint" entries :test #'string=))
         (kind (and kind-pair (stringp (cdr kind-pair))
                     (intern (string-upcase (cdr kind-pair)) :keyword)))
         (fingerprint (and fingerprint-pair (cdr fingerprint-pair))))
    (dolist (pair entries)
      (unless (member (car pair) '("kind" "fingerprint") :test #'string=)
        (return-from parse-claim-entry
          (hngh.domain:make-evidence-fact
           :kind :federated-claim :fingerprint "malformed"
           :state :malformed))))
    (cond
      ((null (cdr fingerprint-pair))
       (hngh.domain:make-evidence-fact
        :kind :federated-claim :fingerprint "missing" :state :missing))
      ((not (member kind hngh.domain:+remote-claim-kinds+))
       (hngh.domain:make-evidence-fact
        :kind :federated-claim :fingerprint "malformed" :state :malformed))
      (t
       (hngh.domain:make-evidence-fact
        :kind kind
        :fingerprint fingerprint
        :state (if (claim-fingerprint-wellformed-p kind fingerprint)
                   :current :unverifiable))))))

(defun bundle-facts (raw-claims)
  "The evidence facts for a carrier bundle's claim set, one fact per
claim with a closed state. A duplicate well-formed claim is demoted to
:conflicting; no good claim is thrown away because a sibling is bad."
  (let ((result '())
        (seen '()))
    (dolist (entry raw-claims)
      (let* ((fact (parse-claim-entry entry))
             (identity (list (hngh.domain:evidence-fact-kind fact)
                             (hngh.domain:evidence-fact-fingerprint fact)))
             (duplicate-p (member identity seen :test #'equal))
             (current-p (eql :current (hngh.domain:evidence-fact-state fact))))
        (when duplicate-p
          (setf seen (remove identity seen :test #'equal)))
        (if (and duplicate-p current-p)
            (push (hngh.domain:make-evidence-fact
                   :kind (hngh.domain:evidence-fact-kind fact)
                   :fingerprint (hngh.domain:evidence-fact-fingerprint fact)
                   :state :conflicting)
                  result)
            (progn
              (pushnew identity seen :test #'equal)
              (push fact result)))))
    (nreverse result)))

(defun gather-federated-evidence (request ports)
  "Send one closed FEDERATION-REQUEST through the injected FETCH-REMOTE
transport, strict-parse the returned carrier bundle, and map its claims
to domain evidence facts with closed states. A transport throw or
malformed return is a transport-fault refusal; a nonzero exit yields an
:unverifiable 'unavailable' fact; a malformed envelope refuses closed;
a malformed, missing, conflicting, or unverifiable claim becomes a fact
with the matching closed state and never a refusal."
  (unless (federation-request-p request)
    (error "gather-federated-evidence requires a federation request"))
  (unless (federation-ports-p ports)
    (error "gather-federated-evidence requires federation ports"))
  (let ((method (federation-request-method request)))
    (unless (member method +federation-methods+)
      (return-from gather-federated-evidence
        (refused-federation '("unknown-transport")))))
  (multiple-value-bind (ok exit-code stdout stderr)
      (transport-response ports request)
    (declare (ignore stderr))
    (cond
      ((not ok)
       (refused-federation '("transport-fault")))
      ((not (zerop exit-code))
       (complete-federation
        (list (hngh.domain:make-evidence-fact
               :kind :federated-claim :fingerprint "unavailable"
               :state :unverifiable))
        nil))
      ((> (length stdout) +max-bundle-length+)
       (refused-federation '("output-too-large")))
      (t
       (handler-case
           (multiple-value-bind (peer key-identifier payload signature
                                 not-before not-after skew raw-claims)
               (parse-bundle-envelope stdout)
             ;; the envelope window must be valid UTC and sanely ordered
             ;; (the verify path re-checks expiry against the clock)
             (unless (and (hngh.domain:utc-string-p not-before)
                          (hngh.domain:utc-string-p not-after)
                          (string<= not-before not-after))
               (return-from gather-federated-evidence
                 (refused-federation '("malformed-expiry"))))
             ;; the request time-window must contain the claimed window
             (let ((window (federation-request-time-window request)))
               (when window
                 (when (or (string< not-before (first window))
                           (string> not-after (second window)))
                   (return-from gather-federated-evidence
                     (refused-federation '("time-window-mismatch"))))))
             (let ((facts (bundle-facts raw-claims)))
               (declare (ignore peer key-identifier payload signature skew))
               (complete-federation facts nil)))
         (hngh.adapters.federation::federation-output-error (error)
           (refused-federation
            (list (federation-output-error-label error)))))))))

;;; Attestation ports ---------------------------------------------------

(defstruct (attestation-ports
            (:constructor %make-attestation-ports
                (resolve-pinned-key verify-signature))
            (:conc-name %attestation-ports-))
  (resolve-pinned-key nil :read-only t)  ; (lambda (key-id) => key-or-nil)
  (verify-signature nil :read-only t))   ; (lambda (payload sig key-id) => (values exit stdout stderr))

(defun make-attestation-ports (&key resolve-pinned-key verify-signature)
  (unless (and (functionp resolve-pinned-key) (functionp verify-signature))
    (error "attestation ports require resolve-pinned-key and verify-signature"))
  (%make-attestation-ports resolve-pinned-key verify-signature))

;;; Attestation result ---------------------------------------------------
;;; The result is evidence, never authority: a verified envelope binds a
;;; :remote-attestation domain fact (state :current) into the evidence
;;; ledger, exactly like a review result binds its fact. Any refusal or
;;; fault binds no current fact.

(defstruct (attestation-result
            (:constructor %make-attestation-result
                (status verified key-identifier fact refusal-labels))
            (:conc-name %attestation-result-))
  (status nil :read-only t)       ;; :verified | :refused | :fault
  (verified nil :read-only t)     ;; payload+sig verified against a pinned key
  (key-identifier nil :read-only t) ;; which pinned key, when verified
  (fact nil :read-only t)         ;; :remote-attestation evidence fact when verified
  (refusal-labels nil :read-only t))

(defun attestation-result-status (result)
  (%attestation-result-status result))
(defun attestation-result-verified (result)
  (%attestation-result-verified result))
(defun attestation-result-key-identifier (result)
  (let ((key (%attestation-result-key-identifier result)))
    (and key (copy-seq key))))
(defun attestation-result-fact (result)
  (%attestation-result-fact result))
(defun attestation-result-refusal-labels (result)
  (mapcar #'copy-seq (%attestation-result-refusal-labels result)))

(defun remote-attestation-fact (attestation key-identifier)
  "The :remote-attestation evidence fact bound by a verified envelope.
The fingerprint is deterministic over the issuer and the exact signed
payload bytes (the hash is the value, per the hash-binding trust model):
state is :current only after the full verify path holds."
  (hngh.domain:make-evidence-fact
   :kind :remote-attestation
   :fingerprint (format nil "~A|~A|~A"
                        (hngh.domain:remote-attestation-peer attestation)
                        key-identifier
                        (hngh.adapters.terminal:sha256-hex
                         (hngh.domain:remote-attestation-payload attestation)))
   :state :current))

(defun verified-attestation (attestation key-identifier)
  (%make-attestation-result
   :verified t key-identifier
   (remote-attestation-fact attestation key-identifier)
   nil))
(defun refused-attestation (labels)
  (%make-attestation-result :refused nil nil nil labels))
(defun faulted-attestation (labels)
  (%make-attestation-result :fault nil nil nil labels))

;;; Verify -------------------------------------------------------------

(defun verify-remote-attestation (attestation now ports)
  "Verify one domain REMOTE-ATTESTATION envelope against the injected
ATTESTATION-PORTS: the kernel shape gate, the operator-pinned key list,
the signature callback, and the expiry window vs the injected NOW. A
:verified result binds the envelope to its pinned key; every failure is
a closed refusal (:refused) or fault (:fault). The result is evidence,
never authority: it never admits a mutation."
  (unless (hngh.domain:remote-attestation-p attestation)
    (error "verify-remote-attestation requires a remote attestation"))
  (unless (attestation-ports-p ports)
    (error "verify-remote-attestation requires attestation ports"))
  ;; 1. shape gate (pure kernel)
  (multiple-value-bind (valid labels)
      (hngh.domain:verify-attestation-shape attestation)
    (unless valid
      (return-from verify-remote-attestation
        (refused-attestation labels))))
  ;; 2. resolve the pinned key (unknown/empty/absent pin closes factory)
  (let ((key-identifier (hngh.domain:remote-attestation-key-identifier
                         attestation)))
    (multiple-value-bind (resolved-p)
        (handler-case (funcall (%attestation-ports-resolve-pinned-key ports)
                               key-identifier)
          (error () (values nil)))
      (unless resolved-p
        (return-from verify-remote-attestation
          (refused-attestation '("unknown-peer-key")))))
    ;; 3. signature through the injected callback
    (multiple-value-bind (exit-code stdout stderr)
        (handler-case
            (funcall (%attestation-ports-verify-signature ports)
                     (hngh.domain:remote-attestation-payload attestation)
                     (hngh.domain:remote-attestation-signature attestation)
                     key-identifier)
          (error () (values nil nil nil)))
      (declare (ignore stdout stderr))
      (unless (integerp exit-code)
        (return-from verify-remote-attestation
          (faulted-attestation '("signature-fault"))))
      (unless (zerop exit-code)
        (return-from verify-remote-attestation
          (refused-attestation '("bad-signature")))))
    ;; 4. expiry window vs the injected now
    (let ((now-seconds (utc-seconds now))
          (not-before (utc-seconds
                       (hngh.domain:remote-attestation-not-before
                        attestation)))
          (not-after (utc-seconds
                      (hngh.domain:remote-attestation-not-after
                       attestation)))
          (skew (hngh.domain:remote-attestation-skew attestation)))
      (unless (and now-seconds not-before not-after)
        (return-from verify-remote-attestation
          (refused-attestation '("malformed-expiry"))))
      (when (< now-seconds (- not-before skew))
        (return-from verify-remote-attestation
          (refused-attestation '("attestation-clock-skew"))))
      (when (> now-seconds (+ not-after skew))
        (return-from verify-remote-attestation
          (refused-attestation '("expired-attestation")))))
    (verified-attestation attestation key-identifier)))

;;; Pinned-key parsing and the signature transport -------------------------
;;; Rung 12: the operator's pins file and the real signature verifier.
;;; PARSE-PINNED-KEYS is a strict line parser over operator-supplied text
;;; (IDENTIFIER<TAB>ABSOLUTE-KEY-PATH, `#` comments, blank lines skipped;
;;; every other deviation refuses); HEX-DECODE is the pure envelope
;;; signature codec; MAKE-PINNED-ATTESTATION-PORTS builds the
;;; ATTESTATION-PORTS pair the verify path already consumes — keys resolve
;;; from the registry, signatures verify through one bounded openssl
;;; invocation (dgst -sha256 -verify) run on the injected process
;;; transport. No default transport exists: nothing here runs a process
;;; unless the caller injects one.

(defun parse-pinned-keys (data)
  "Strict-parse operator pins text into a KEY-PIN-REGISTRY. One pin per
line: KEY-IDENTIFIER<TAB>ABSOLUTE-KEY-PATH[<TAB>ALGORITHM], where
ALGORITHM is a closed key-algorithm token (default rsa-sha256 when
omitted). `#`-prefixed comment lines and blank lines are skipped; any
malformed line, wrong field count, empty identifier, unknown algorithm,
relative path, or option-like path refuses."
  (unless (stringp data)
    (error "pinned keys must be text"))
  (let ((pins '()))
    (dolist (line (uiop:split-string data :separator '(#\Newline)))
      (let ((line (string-right-trim '(#\Return) line)))
        (unless (or (uiop:emptyp line) (char= (char line 0) #\#))
          (let ((tab (position #\Tab line)))
            (unless tab
              (error "malformed pins line: ~S" line))
            (let* ((algorithm-tab (position #\Tab line :start (1+ tab)))
                   (identifier (subseq line 0 tab))
                   (key-path (subseq line (1+ tab)
                                     (or algorithm-tab (length line))))
                   (algorithm (if algorithm-tab
                                  (subseq line (1+ algorithm-tab))
                                  "rsa-sha256")))
              (when (position #\Tab algorithm)
                (error "malformed pins line: ~S" line))
              (push (hngh.domain:make-key-pin
                     :key-identifier identifier
                     :key-path key-path
                     :algorithm (intern (string-upcase algorithm)
                                        :keyword))
                    pins))))))
    (hngh.domain:make-key-pin-registry (nreverse pins))))

(defun hex-decode (hex)
  "Decode HEX (lowercase hex string) into a fresh unsigned-byte vector.
Odd length or any non-hex character refuses."
  (unless (and (stringp hex) (evenp (length hex)))
    (error "malformed-signature"))
  (let ((bytes (make-array (floor (length hex) 2)
                           :element-type '(unsigned-byte 8))))
    (loop for index below (length bytes)
          for high = (hex-digit-value (char hex (* 2 index)))
          for low = (hex-digit-value (char hex (1+ (* 2 index))))
          do (unless (and high low)
               (error "malformed-signature"))
             (setf (aref bytes index) (+ (* 16 high) low)))
    bytes))

(defun write-verification-inputs (unique payload signature-bytes)
  "Write the exact payload string and signature bytes to two temp files
under the temporary directory; returns their namestrings."
  (let* ((directory (uiop:temporary-directory))
         (payload-path
           (uiop:native-namestring
            (merge-pathnames
             (make-pathname :name (format nil "~A-payload" unique)
                            :type "tmp")
             directory)))
         (signature-path
           (uiop:native-namestring
            (merge-pathnames
             (make-pathname :name (format nil "~A-signature" unique)
                            :type "tmp")
             directory))))
    (with-open-file (stream payload-path :direction :output
                             :if-exists :supersede
                             :external-format :utf-8)
      (write-string payload stream))
    (with-open-file (stream signature-path :direction :output
                             :element-type '(unsigned-byte 8)
                             :if-exists :supersede)
      (write-sequence signature-bytes stream))
    (values payload-path signature-path)))

(defun signature-verification-argv (algorithm key-path signature-path
                                    payload-path)
  "The bounded openssl argv for one verification, closed on ALGORITHM.
:rsa-sha256 verifies a digest signature via dgst -sha256 -verify;
:ed25519 verifies a raw Ed25519 signature via pkeyutl -verify -rawin
(Ed25519 signs the message itself, so no digest is involved)."
  (case algorithm
    (:rsa-sha256
     (list "openssl" "dgst" "-sha256" "-verify" key-path
           "-signature" signature-path payload-path))
    (:ed25519
     (list "openssl" "pkeyutl" "-verify" "-pubin" "-inkey" key-path
           "-rawin" "-sigfile" signature-path "-in" payload-path))
    (t (error "unknown key algorithm: ~S" algorithm))))

(defun verify-signature-via-openssl (process-transport payload
                                      signature-bytes key-path algorithm)
  "One bounded openssl invocation through PROCESS-TRANSPORT for the pin's
ALGORITHM (see SIGNATURE-VERIFICATION-ARGV). Returns the transport's
(values exit-code stdout stderr); the temp files are always removed."
  (let ((payload-path nil)
        (signature-path nil))
    (unwind-protect
        (multiple-value-bind (payload-file signature-file)
            (write-verification-inputs (gensym "hngh-sig")
                                       payload signature-bytes)
          (setf payload-path payload-file
                signature-path signature-file)
          (funcall process-transport
                   (signature-verification-argv
                    algorithm key-path signature-path payload-path)))
      (when signature-path (ignore-errors (delete-file signature-path)))
      (when payload-path (ignore-errors (delete-file payload-path))))))

(defun make-pinned-attestation-ports (registry process-transport)
  "ATTESTATION-PORTS over an operator KEY-PIN-REGISTRY and one injected
PROCESS-TRANSPORT (a function of one argv returning the adapter-wide
(values exit-code stdout stderr) shape). The pinned key resolves from
the registry; the signature is hex-decoded and verified by one bounded
openssl call. Nothing here reads a clock or runs a process by default."
  (unless (functionp process-transport)
    (error "pinned attestation ports require a process transport"))
  (make-attestation-ports
   :resolve-pinned-key
   (lambda (key-id)
     (let ((pin (hngh.domain:lookup-key-pin registry key-id)))
       (and pin (hngh.domain:key-pin-key-path pin))))
   :verify-signature
   (lambda (payload signature key-id)
     (let ((signature-bytes (handler-case (hex-decode signature)
                               (error () nil))))
       (if (null signature-bytes)
           (values 1 "" "malformed-signature")
           (let ((pin (handler-case
                          (hngh.domain:lookup-key-pin registry key-id)
                        (error () nil))))
             (if (null pin)
                 (values 1 "" "unknown-peer-key")
                 (verify-signature-via-openssl
                  process-transport payload signature-bytes
                 (hngh.domain:key-pin-key-path pin)
                 (hngh.domain:key-pin-algorithm pin)))))))))
