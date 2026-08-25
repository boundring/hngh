(in-package :hngh.tests)

;;;; Federation & distributed attestation: Rung 11 tests.
;;;; Covers the pure kernel value + shape checker (src/domain/attestation.lisp),
;;;; the federation adapter's gather and verify paths
;;;; (src/adapter/federation.lisp), :federation transport admission
;;;; (src/application/admit-transport.lisp), and the operator surface
;;;; (fetch-evidence / verify-attestation in hngh.main). Everything is
;;;; fixture-backed; no subprocess and no wire anywhere in this file.

;;; Fixture bundle documents ------------------------------------------------

(defparameter *fed-valid-bundle*
  "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"payload-bytes\",\"signature\":\"sig-abc\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[{\"kind\":\"content-hash\",\"fingerprint\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"},{\"kind\":\"repository-revision\",\"fingerprint\":\"0123456789abcdef0123456789abcdef01234567\"},{\"kind\":\"working-tree-status\",\"fingerprint\":\"clean\"}]}"
  "A shape-valid carrier bundle: one of each closed claim kind.")

(defparameter *fed-content-hash-64*
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")

(defparameter *fed-revision-40*
  "0123456789abcdef0123456789abcdef01234567")

(defparameter *fed-bundle-with-unknown-kind*
  (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[{\"kind\":\"mystery\",\"fingerprint\":\"x\"}]}")
  "A bundle whose claim kind is outside the closed vocabulary.")

(defparameter *fed-bundle-malformed-json*
  "{ not json at all ! }")

(defparameter *fed-bundle-unknown-top-key*
  (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[],\"extra\":1}")
  "A bundle carrying an unknown top-level field.")

(defparameter *fed-bundle-missing-field*
  (format nil "{\"peer\":\"machine-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[]}")
  "A bundle missing the key-identifier field.")

(defparameter *fed-bundle-bad-expiry*
  (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[]}")
  "A bundle whose expiry window is not a fixed-width UTC string.")

(defparameter *fed-bundle-duplicate-claims*
  (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[{\"kind\":\"content-hash\",\"fingerprint\":\"~A\"},{\"kind\":\"content-hash\",\"fingerprint\":\"~A\"}]}"
          *fed-content-hash-64* *fed-content-hash-64*)
  "A bundle carrying the same claim twice.")

(defparameter *fed-bundle-missing-fingerprint*
  (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[{\"kind\":\"content-hash\"}]}")
  "A bundle whose claim is missing its fingerprint field.")

(defparameter *fed-bundle-negative-skew*
  (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":-5,\"claims\":[]}")
  "A bundle with a negative skew window.")

;;; Helpers ------------------------------------------------------------------

(defun fed-gather (bundle &key (exit-code 0) (fault nil) (peer "machine-b")
                          (method :carrier-bundle) time-window max-facts)
  "Run gather-federated-evidence with a fixture transport returning BUNDLE."
  (let ((ports (hngh.adapters.federation:make-federation-ports
                :fetch-remote
                (lambda (request)
                  (declare (ignore request))
                  (when fault (error "transport fault"))
                  (values exit-code bundle "")))))
    (hngh.adapters.federation:gather-federated-evidence
     (hngh.adapters.federation:make-federation-request
      :peer peer :method method :time-window time-window :max-facts max-facts)
     ports)))

(defun fed-status (result)
  (hngh.adapters.federation:federation-result-status result))
(defun fed-labels (result)
  (hngh.adapters.federation:federation-result-refusal-labels result))
(defun fed-facts (result)
  (hngh.adapters.federation:federation-result-facts result))
(defun fed-fact-states (result)
  (mapcar #'hngh.domain:evidence-fact-state (fed-facts result)))

(defun att-verify (attestation now &key pinned signature-fault
                               (exit-code 0))
  "Run verify-remote-attestation with fixture attestation ports. PINNED
is NIL to simulate an unknown/empty pin list; SIGNATURE-FAULT signals a
thrown verifier; EXIT-CODE drives the bad-signature path."
  (let ((ports (hngh.adapters.federation:make-attestation-ports
                :resolve-pinned-key
                (lambda (key-id)
                  (declare (ignore key-id))
                  (and pinned "pub-key"))
                :verify-signature
                (lambda (payload signature key-id)
                  (declare (ignore payload signature key-id))
                  (when signature-fault (error "verifier fault"))
                  (values exit-code "ok" "")))))
    (hngh.adapters.federation:verify-remote-attestation
     attestation now ports)))

(defun att-status (result)
  (hngh.adapters.federation:attestation-result-status result))
(defun att-labels (result)
  (hngh.adapters.federation:attestation-result-refusal-labels result))

(defun make-fixture-attestation (&key (peer "machine-b") (key-identifier "key-b")
                                     (payload "payload-bytes") (signature "sig-abc")
                                     (not-before "2026-08-01T00:00:00Z")
                                     (not-after "2026-08-31T00:00:00Z")
                                     (skew 60) claims)
  (hngh.domain:make-remote-attestation
   :peer peer :key-identifier key-identifier :payload payload
   :signature signature :claims claims :not-before not-before
   :not-after not-after :skew skew))

;;; Domain: the remote-attestation value -------------------------------------

(check (hngh.domain:remote-attestation-p
        (make-fixture-attestation))
       "make-remote-attestation builds a remote attestation value")
(check (equal "payload-bytes"
              (hngh.domain:remote-attestation-payload
               (make-fixture-attestation)))
       "remote attestation accessor returns the payload")
(check (eql 60 (hngh.domain:remote-attestation-skew
                (make-fixture-attestation)))
       "remote attestation accessor returns the skew")

(let* ((payload (copy-seq "copy-me"))
       (attestation (make-fixture-attestation :payload payload)))
  (setf (char payload 0) #\X)
  (check (equal "copy-me"
                (hngh.domain:remote-attestation-payload attestation))
         "remote attestation isolates its payload from caller mutation"))

(dolist (arguments
         (list '()
               (list :peer "machine-b" :key-identifier "key-b"
                     :payload "p" :signature "s" :claims '()
                     :not-before "2026-08-01T00:00:00Z")
               (list :peer "machine-b" :key-identifier "key-b"
                     :payload "p" :signature "s" :claims '()
                     :not-before "2026-08-01T00:00:00Z"
                     :not-after "2026-08-31T00:00:00Z")))
  (check (signals-error-p
          (lambda ()
            (apply #'hngh.domain:make-remote-attestation arguments)))
         (format nil "remote attestation requires its required fields: ~S"
                 arguments)))

(dolist (peer '("" "http://host" "has space" "path/file" "a@b"))
  (check (signals-error-p
          (lambda () (make-fixture-attestation :peer peer)))
         (format nil "remote attestation refususes a plain-bad peer: ~S" peer)))

;;; Domain: verify-attestation-shape -----------------------------------------

(multiple-value-bind (valid labels)
    (hngh.domain:verify-attestation-shape (make-fixture-attestation))
  (check (and valid (null labels))
         "a well-formed attestation passes the shape checker"))

(multiple-value-bind (valid labels)
    (hngh.domain:verify-attestation-shape
     (make-fixture-attestation :not-before "2026-08-31T00:00:00Z"
                               :not-after "2026-08-01T00:00:00Z"))
  (check (and (not valid)
              (member "malformed-expiry" labels :test #'string=))
         "a reversed expiry window is malformed-expiry"))

(multiple-value-bind (valid labels)
    (hngh.domain:verify-attestation-shape
     (make-fixture-attestation :not-before "2026-08-01"))
  (check (and (not valid)
              (member "malformed-expiry" labels :test #'string=))
         "a non-UTC not-before is malformed-expiry"))

(multiple-value-bind (valid labels)
    (hngh.domain:verify-attestation-shape
     (make-fixture-attestation :claims (list
                                        (hngh.domain:make-remote-claim
                                         :kind :content-hash
                                         :fingerprint "a")
                                        (hngh.domain:make-remote-claim
                                         :kind :content-hash
                                         :fingerprint "a"))))
  (check (and (not valid)
              (member "duplicate-claim" labels :test #'string=))
         "duplicate claims are duplicate-claim"))

(multiple-value-bind (valid labels)
    (hngh.domain:verify-attestation-shape
     (make-fixture-attestation :skew -1))
  (check (not valid)
         "a negative skew fails shape (closed refusal label set)"))

;;; The domain checker is pure: no clock dependency ---------------------------
(check (hngh.domain:utc-string-p "2026-08-01T00:00:00Z")
       "utc-string-p admits a fixed-width UTC timestamp")
(check (not (hngh.domain:utc-string-p "2026-08-01T00:00:00"))
       "utc-string-p refuses a timestamp without the trailing Z")
(check (not (hngh.domain:utc-string-p "2026-13-01T00:00:00Z"))
       "utc-string-p refuses month 13")
(check (not (hngh.domain:utc-string-p "not-a-timestamp"))
       "utc-string-p refuses a non-timestamp")

;;; Gather: valid bundle ------------------------------------------------------

(let ((result (fed-gather *fed-valid-bundle*)))
  (check (eq :complete (fed-status result))
         "a valid bundle gathers as complete")
  (check (null (fed-labels result))
         "a complete gather carries no refusal labels")
  (check (= 3 (length (fed-facts result)))
         "a three-claim bundle yields three facts")
  (check (equal '(:current :current :unverifiable)
                (fed-fact-states result))
         "hash-shaped claims are :current; a non-hash status claim is :unverifiable")
  (check (eql :content-hash
              (hngh.domain:evidence-fact-kind (first (fed-facts result))))
         "the first fact carries its claim kind"))

;;; Gather: claim mapping edge cases ------------------------------------------

(let* ((unverifiable-bundle
         (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2026-08-01T00:00:00Z\",\"not-after\":\"2026-08-31T00:00:00Z\",\"skew-seconds\":60,\"claims\":[{\"kind\":\"content-hash\",\"fingerprint\":\"not-a-hash\"},{\"kind\":\"working-tree-status\",\"fingerprint\":\"clean\"}]}"))
       (result (fed-gather unverifiable-bundle)))
  (check (eq :complete (fed-status result))
         "an un-hashable but closed-kind claim still gathers")
  (check (equal '(:unverifiable :unverifiable) (fed-fact-states result))
         "claims that are not locally re-hashable are :unverifiable"))

;;; Gather: transport and document failures -----------------------------------

(let ((result (fed-gather nil :fault t)))
  (check (eq :refused (fed-status result))
         "a thrown fetch is a transport-fault refusal")
  (check (member "transport-fault" (fed-labels result) :test #'string=)
         "a thrown fetch names transport-fault"))

(let ((result (fed-gather "" :exit-code 1)))
  (check (eq :complete (fed-status result))
         "a nonzero exit still completes the bundle")
  (check (equal '(:unverifiable) (fed-fact-states result))
         "a nonzero exit yields an :unverifiable unavailable fact")
  (check (equal "unavailable"
                (hngh.domain:evidence-fact-fingerprint
                 (first (fed-facts result))))
         "the nonzero-exit fact carries the unavailable fingerprint"))

(let ((result (fed-gather *fed-bundle-malformed-json*)))
  (check (eq :refused (fed-status result))
         "malformed JSON refuses as malformed-attestation")
  (check (member "malformed-attestation" (fed-labels result) :test #'string=)
         "malformed JSON names malformed-attestation"))

(let ((result (fed-gather *fed-bundle-unknown-top-key*)))
  (check (eq :refused (fed-status result))
         "an unknown top-level field refuses")
  (check (member "malformed-attestation" (fed-labels result) :test #'string=)
         "an unknown top-level field names malformed-attestation"))

(let ((result (fed-gather *fed-bundle-missing-field*)))
  (check (eq :refused (fed-status result))
         "a missing required field refuses"))

(let ((result (fed-gather *fed-bundle-bad-expiry*)))
  (check (eq :refused (fed-status result))
         "a malformed expiry window refuses"))

(let ((result (fed-gather *fed-bundle-negative-skew*)))
  (check (eq :refused (fed-status result))
         "a negative skew bundle refuses"))

(let ((result (fed-gather *fed-bundle-with-unknown-kind*)))
  (check (eq :complete (fed-status result))
         "a claim outside the closed vocabulary still gathers")
  (check (equal '(:malformed) (fed-fact-states result))
         "a claim outside the closed vocabulary is a :malformed fact"))

(let ((result (fed-gather *fed-bundle-duplicate-claims*)))
  (check (eq :complete (fed-status result))
         "duplicate claims still gather")
  (check (equal '(:current :conflicting) (fed-fact-states result))
         "a duplicated well-formed claim is demoted to :conflicting"))

(let ((result (fed-gather *fed-bundle-missing-fingerprint*)))
  (check (eq :complete (fed-status result))
         "a claim missing its fingerprint still gathers")
  (check (equal '(:missing) (fed-fact-states result))
         "a claim missing its fingerprint is a :missing fact"))

(check (signals-error-p
        (lambda () (fed-gather *fed-valid-bundle* :method :http-claim)))
       "an unadmitted method refuses closed at request construction")

(check (signals-error-p
        (lambda () (fed-gather *fed-valid-bundle* :peer "http://host")))
       "a URL-like peer refuses request construction")

(let ((result (fed-gather *fed-valid-bundle*
                          :time-window '("2026-09-01T00:00:00Z"
                                         "2026-09-30T00:00:00Z"))))
  (check (eq :refused (fed-status result))
         "a request window that excludes the bundle window refuses")
  (check (member "time-window-mismatch" (fed-labels result) :test #'string=)
         "an out-of-window bundle names time-window-mismatch"))

(let ((result (fed-gather *fed-valid-bundle*
                          :time-window '("2026-07-01T00:00:00Z"
                                         "2026-09-30T00:00:00Z"))))
  (check (eq :complete (fed-status result))
         "a request window containing the bundle window gathers"))

;;;; Verify: every closed path -----------------------------------------------

(let ((attestation (make-fixture-attestation)))
  (let ((result (att-verify attestation "2026-08-15T00:00:00Z"
                            :pinned t)))
    (check (eq :verified (att-status result))
           "a pinned, well-signed, in-window attestation verifies")
    (check (hngh.adapters.federation:attestation-result-verified result)
           "a verified result marks verified")
    (check (equal "key-b"
                  (hngh.adapters.federation:attestation-result-key-identifier result))
           "a verified result records the verified key")
    (let ((fact (hngh.adapters.federation:attestation-result-fact result)))
      (check (eql :remote-attestation (hngh.domain:evidence-fact-kind fact))
             "a verified result binds a :remote-attestation fact")
      (check (eql :current (hngh.domain:evidence-fact-state fact))
             "the bound fact is :current after full verification")
      (check (search "machine-b" (hngh.domain:evidence-fact-fingerprint fact))
             "the bound fact's fingerprint names the peer"))))

(let ((result (att-verify (make-fixture-attestation)
                          "2026-08-15T00:00:00Z")))
  (check (eq :refused (att-status result))
         "an unpinned key is refused")
  (check (member "unknown-peer-key" (att-labels result) :test #'string=)
         "an unpinned key names unknown-peer-key"))

(let ((result (att-verify (make-fixture-attestation)
                          "2026-08-15T00:00:00Z"
                          :pinned t :exit-code 1)))
  (check (eq :refused (att-status result))
         "a bad signature is refused")
  (check (member "bad-signature" (att-labels result) :test #'string=)
         "a bad signature names bad-signature"))

(let ((result (att-verify (make-fixture-attestation)
                          "2026-08-15T00:00:00Z"
                          :pinned t :signature-fault t)))
  (check (eq :fault (att-status result))
         "a thrown verifier faults the result")
  (check (member "signature-fault" (att-labels result) :test #'string=)
         "a thrown verifier names signature-fault"))

(let ((result (att-verify (make-fixture-attestation)
                          "2027-02-01T00:00:00Z" :pinned t)))
  (check (eq :refused (att-status result))
         "a now past not-after+skew is expired")
  (check (member "expired-attestation" (att-labels result) :test #'string=)
         "the expired case names expired-attestation"))

(let ((result (att-verify (make-fixture-attestation)
                          "2026-01-01T00:00:00Z" :pinned t)))
  (check (eq :refused (att-status result))
         "a now before not-before-skew is a clock skew")
  (check (member "attestation-clock-skew"
                 (att-labels result) :test #'string=)
         "the far-future case names attestation-clock-skew"))

(let ((result (att-verify (make-fixture-attestation)
                          "2026-08-15T00:00:00Z" :pinned t
                          :signature-fault t)))
  (check (eq :fault (att-status result))
         "a signature callback fault closes any authority"))

(let ((result (att-verify (make-fixture-attestation
                           :not-before "2026-08-31T00:00:00Z"
                           :not-after "2026-08-01T00:00:00Z")
                          "2026-08-15T00:00:00Z" :pinned t)))
  (check (eq :refused (att-status result))
         "a shape-invalid attestation never reaches the verifier")
  (check (member "malformed-expiry" (att-labels result) :test #'string=)
         "a reversed window names malformed-expiry at the shape gate"))

;;;; Admission: :federation needs a label -------------------------------------

(defun make-federation-run (&key (tool-labels nil) (network-labels nil))
  (hngh.domain:make-run
   :identifier "run-federation-test"
   :mission (make-application-mission)
   :role (make-application-role)
   :loadout (hngh.domain:make-loadout
             :route-label :local
             :context-limit 1 :token-limit 2 :cost-limit 3 :time-limit 4
             :tool-labels tool-labels
             :network-labels (or network-labels '("none"))
             :writable-scopes '("repository"))))

(multiple-value-bind (ports reporter) (make-admit-fake)
  (let ((result (admit-with ports
                            (make-federation-run
                             :network-labels '("remote-evidence"))
                            :federation "repository")))
    (check (eq :accepted (admit-result-status result))
           "federation is admitted with the remote-evidence network label")
    (let ((state (funcall reporter)))
      (check (= 1 (getf state :record-calls))
             "federation admission records exactly one pair"))))

(multiple-value-bind (ports reporter) (make-admit-fake)
  (let ((result (admit-with ports
                            (make-federation-run
                             :tool-labels '("carrier-bundle"))
                            :federation "repository")))
    (check (eq :accepted (admit-result-status result))
           "federation is admitted with the carrier-bundle tool label")
    (let ((state (funcall reporter)))
      (check (= 1 (getf state :record-calls))
             "carrier-bundle admission records exactly one pair"))))

(multiple-value-bind (ports reporter) (make-admit-fake)
  (let ((result (admit-with ports (make-federation-run)
                            :federation "repository")))
    (check (eq :refused (admit-result-status result))
           "federation without a required label is refused")
    (check (member "loadout-refuses-transport" (admit-result-labels result)
                   :test #'string=)
           "the loadout gate names loadout-refuses-transport")
    (let ((state (funcall reporter)))
      (check (zerop (getf state :record-calls))
             "an unlabeled federation admission records nothing"))))

(check (signals-error-p
        (lambda () (admit-with :not-ports (make-federation-run)
                               :federation "repository")))
       "federation admission rejects missing ports")

;;;; Operator surface: fetch-evidence / verify-attestation --------------------

(defun fed-dispatch-root ()
  "A fresh scratch store root."
  (let ((path (uiop:with-temporary-file (:pathname path :keep t)
                (delete-file path)
                (ensure-directories-exist (uiop:ensure-directory-pathname path)))))
    path))

(defun fed-dispatch (argv &key root federation-ports attestation-ports clock)
  (let ((*error-output* (make-string-output-stream)))
    (multiple-value-list
     (hngh.main:dispatch-command
      (if root (cons (format nil "--store=~A" root) argv) argv)
      :clock-now (or clock (lambda () "2026-08-15T00:00:00Z"))
      :federation-ports federation-ports
      :attestation-ports attestation-ports))))

(defun fed-exit (result) (second result))
(defun fed-has (needle result) (search needle (first result)))

(defparameter +fed-fetch-create-args+
  '("create-run" "Create a valid run" "builder"
    "loadout-route-label=local" "loadout-context-limit=1" "loadout-token-limit=2"
    "loadout-cost-limit=3" "loadout-time-limit=4"
    "loadout-tool-labels=carrier-bundle"
    "loadout-network-labels=none" "loadout-writable-scopes=repository"))

(defun fed-federation-ports ()
  "A fixture fed ports object; the reporter is discarded."
  (hngh.adapters.federation:make-federation-ports
   :fetch-remote (lambda (request)
                   (declare (ignore request))
                   (values 0 *fed-valid-bundle* ""))))

(defun fed-attestation-ports ()
  "A fixture attestation ports object with a pinned machine-b key."
  (hngh.adapters.federation:make-attestation-ports
   :resolve-pinned-key (lambda (key-id) (declare (ignore key-id)) "pub-key")
   :verify-signature (lambda (p s k) (declare (ignore p s k))
                       (values 0 "ok" ""))))

;; fetch-evidence lifecycle: admitted + injected ports
(let ((root (fed-dispatch-root)))
  (fed-dispatch +fed-fetch-create-args+ :root root)
  (fed-dispatch '("admit-transport" "run-1" "federation" "repository")
                :root root)
  (let ((result (fed-dispatch '("fetch-evidence" "run-1" "peer=machine-b")
                              :root root
                              :federation-ports (fed-federation-ports))))
    (check (= 0 (fed-exit result))
           "fetch-evidence gathers through injected ports")
    (check (fed-has "federation status=complete" result)
           "the complete gather renders"))
  (uiop:delete-directory-tree root :validate t))

;; fetch-evidence refuses without ports
(let ((root (fed-dispatch-root)))
  (fed-dispatch +fed-fetch-create-args+ :root root)
  (fed-dispatch '("admit-transport" "run-1" "federation" "repository")
                :root root)
  (let ((result (fed-dispatch '("fetch-evidence" "run-1" "peer=machine-b")
                              :root root)))
    (check (= 1 (fed-exit result))
           "fetch-evidence without ports refuses")
    (check (fed-has "no-federation-transport" result)
           "the refusal names no-federation-transport"))
  (uiop:delete-directory-tree root :validate t))

;; fetch-evidence refuses an unadmitted run
(let ((root (fed-dispatch-root)))
  (fed-dispatch +fed-fetch-create-args+ :root root)
  (let ((result (fed-dispatch '("fetch-evidence" "run-1" "peer=machine-b")
                              :root root
                              :federation-ports (fed-federation-ports))))
    (check (= 1 (fed-exit result))
           "fetch-evidence serves only an admitted run")
    (check (fed-has "not admitted for federation" result)
           "the refusal names the missing admission"))
  (uiop:delete-directory-tree root :validate t))

;; fetch-evidence: a malformed invocation exits 2
(let ((root (fed-dispatch-root)))
  (fed-dispatch +fed-fetch-create-args+ :root root)
  (fed-dispatch '("admit-transport" "run-1" "federation" "repository")
                :root root)
  (let ((result (fed-dispatch '("fetch-evidence")
                              :root root)))
    (check (= 2 (fed-exit result))
           "fetch-evidence with no operands is malformed"))
  (let ((result (fed-dispatch '("fetch-evidence" "run-1")
                              :root root
                              :federation-ports (fed-federation-ports))))
    (check (= 2 (fed-exit result))
           "fetch-evidence without a peer is malformed"))
  (uiop:delete-directory-tree root :validate t))

;; verify-attestation: verified through injected ports + envelope file
(let ((root (fed-dispatch-root)))
  (fed-dispatch +fed-fetch-create-args+ :root root)
  (fed-dispatch '("admit-transport" "run-1" "federation" "repository")
                :root root)
  (let* ((envelope-path
           (uiop:with-temporary-file (:pathname path :keep t)
             (with-open-file (stream path :direction :output
                                    :if-exists :supersede)
               (write-string *fed-valid-bundle* stream))
             (namestring path)))
         (result (fed-dispatch (list "verify-attestation" "run-1"
                                     envelope-path)
                               :root root
                               :attestation-ports (fed-attestation-ports))))
    (check (= 0 (fed-exit result))
           "verify-attestation verifies a pinned, signed, in-window envelope")
    (check (fed-has "attestation status=verified key=key-b" result)
           "the verified attestation renders with its key"))
  (uiop:delete-directory-tree root :validate t))

;; verify-attestation refuses without ports
(let ((root (fed-dispatch-root)))
  (fed-dispatch +fed-fetch-create-args+ :root root)
  (fed-dispatch '("admit-transport" "run-1" "federation" "repository")
                :root root)
  (let* ((envelope-path
           (uiop:with-temporary-file (:pathname path :keep t)
             (with-open-file (stream path :direction :output
                                    :if-exists :supersede)
               (write-string *fed-valid-bundle* stream))
             (namestring path)))
         (result (fed-dispatch (list "verify-attestation" "run-1"
                                     envelope-path)
                               :root root)))
    (check (= 1 (fed-exit result))
           "verify-attestation without ports refuses")
    (check (fed-has "no-attestation-transport" result)
           "the refusal names no-attestation-transport"))
  (uiop:delete-directory-tree root :validate t))

;; verify-attestation: expired envelope refuses closed
(let ((root (fed-dispatch-root)))
  (fed-dispatch +fed-fetch-create-args+ :root root)
  (fed-dispatch '("admit-transport" "run-1" "federation" "repository")
                :root root)
  (let* ((expired-envelope
           (format nil "{\"peer\":\"machine-b\",\"key-identifier\":\"key-b\",\"payload\":\"p\",\"signature\":\"s\",\"not-before\":\"2020-01-01T00:00:00Z\",\"not-after\":\"2021-01-01T00:00:00Z\",\"skew-seconds\":60,\"claims\":[]}"))
         (envelope-path
           (uiop:with-temporary-file (:pathname path :keep t)
             (with-open-file (stream path :direction :output
                                    :if-exists :supersede)
               (write-string expired-envelope stream))
             (namestring path)))
         (result (fed-dispatch (list "verify-attestation" "run-1"
                                     envelope-path)
                               :root root
                               :attestation-ports (fed-attestation-ports))))
    (check (= 1 (fed-exit result))
           "verify-attestation refuses an expired envelope")
    (check (fed-has "expired-attestation" result)
           "the refusal names expired-attestation"))
  (uiop:delete-directory-tree root :validate t))

;;; Adapter: pinned-key parsing and the signature transport -----------------

(let ((registry (hngh.adapters.federation:parse-pinned-keys
                 (concatenate 'string
                              "# operator pins" '(#\Newline)
                              "key-b" '(#\Tab)
                              "/etc/hngh/keys/key-b.pub" '(#\Newline)
                              '(#\Newline)
                              "key-c" '(#\Tab)
                              "/etc/hngh/keys/key-c.pub" '(#\Newline)))))
  (check (and (hngh.domain:key-pin-registry-p registry)
              (equal "/etc/hngh/keys/key-b.pub"
                     (hngh.domain:key-pin-key-path
                      (hngh.domain:lookup-key-pin registry "key-b")))
              (equal "/etc/hngh/keys/key-c.pub"
                     (hngh.domain:key-pin-key-path
                      (hngh.domain:lookup-key-pin registry "key-c")))
              (null (hngh.domain:lookup-key-pin registry "key-d")))
         "parse-pinned-keys builds a registry skipping comments and blanks"))

(dolist (bad-line (list "key-b /etc/hngh/keys/key-b.pub"
                        "key-b\trelative/key.pub"
                        "key-b\t/etc/-option-like.pub"
                        "\t/etc/hngh/keys/key-b.pub"
                        "key-b\t/etc/hngh/keys/key-b.pub\textra"))
  (check (signals-error-p
          (lambda ()
            (hngh.adapters.federation:parse-pinned-keys bad-line)))
         (format nil "malformed pins line refuses: ~S" bad-line)))

(check (signals-error-p
        (lambda ()
          (hngh.adapters.federation:parse-pinned-keys
           (concatenate 'string
                        "key-b" '(#\Tab) "/etc/hngh/keys/b.pub" '(#\Newline)
                        "key-b" '(#\Tab) "/etc/hngh/keys/b2.pub"))))
       "duplicate pins refuse")

(check (equalp #(222 173 190 239)
               (hngh.adapters.federation:hex-decode "deadbeef"))
       "hex-decode decodes lowercase hex to bytes")
(check (equalp #() (hngh.adapters.federation:hex-decode ""))
       "hex-decode accepts the empty signature")
(dolist (bad-hex (list "abc" "zz" "deadbee" 42))
  (check (signals-error-p
          (lambda ()
            (hngh.adapters.federation:hex-decode bad-hex)))
         (format nil "malformed hex refuses: ~S" bad-hex)))

;;; Rung 14: pins file algorithm column and the signature transport --------

(let ((registry (hngh.adapters.federation:parse-pinned-keys
                 (concatenate 'string
                              "key-b" '(#\Tab) "/etc/hngh/keys/key-b.pub"
                              '(#\Tab) "ed25519" '(#\Newline)
                              "key-c" '(#\Tab) "/etc/hngh/keys/key-c.pub"))))
  (check (and (eql :ed25519
                   (hngh.domain:key-pin-algorithm
                    (hngh.domain:lookup-key-pin registry "key-b")))
              (eql :rsa-sha256
                   (hngh.domain:key-pin-algorithm
                    (hngh.domain:lookup-key-pin registry "key-c"))))
         "the pins parser reads an explicit algorithm and defaults the rest"))

(dolist (bad-line (list "key-b\t/etc/hngh/keys/key-b.pub\tbogus"
                        "key-b\t/etc/hngh/keys/key-b.pub\ted25519\textra"
                        "key-b\t/etc/hngh/keys/key-b.pub\t"))
  (check (signals-error-p
          (lambda ()
            (hngh.adapters.federation:parse-pinned-keys bad-line)))
         (format nil "an unknown, extra, or empty algorithm column refuses: ~S"
                 bad-line)))

(defun fed-pinned-argv (&key (algorithm "rsa-sha256") (exit-code 0))
  "Run one verify through pinned ports whose fake transport records the
exact openssl argv; returns (values result argv)."
  (let ((captured nil))
    (let* ((registry (hngh.adapters.federation:parse-pinned-keys
                      (concatenate 'string "key-b" '(#\Tab)
                                   "/etc/hngh/keys/key-b.pub" '(#\Tab)
                                   algorithm)))
           (ports (hngh.adapters.federation:make-pinned-attestation-ports
                   registry
                   (lambda (argv)
                     (setf captured argv)
                     (values exit-code "Verified OK" "")))))
      (values
       (hngh.adapters.federation:verify-remote-attestation
        (make-fixture-attestation :signature "deadbeef")
        "2026-08-15T00:00:00Z" ports)
       captured))))

(multiple-value-bind (result captured)
    (fed-pinned-argv :algorithm "rsa-sha256")
  (check (eq :verified (att-status result))
         "an rsa-sha256 pin still verifies through the dgst path")
  (check (and (equal "openssl" (first captured))
              (member "-sha256" captured :test #'string=)
              (member "-verify" captured :test #'string=)
              (member "-signature" captured :test #'string=))
         "an rsa-sha256 pin verifies through dgst -sha256 -verify"))

(multiple-value-bind (result captured)
    (fed-pinned-argv :algorithm "ed25519")
  (check (eq :verified (att-status result))
         "an ed25519 pin verifies through the pkeyutl path")
  (check (and (equal "openssl" (first captured))
              (member "pkeyutl" captured :test #'string=)
              (member "-verify" captured :test #'string=)
              (member "-rawin" captured :test #'string=)
              (member "-sigfile" captured :test #'string=))
         "an ed25519 pin verifies through pkeyutl -verify -rawin -sigfile"))

(defparameter *fed-pinned-registry*
  (hngh.adapters.federation:parse-pinned-keys
   (concatenate 'string "key-b" '(#\Tab) "/etc/hngh/keys/key-b.pub")))

(defun fed-pinned-result (&key (key-identifier "key-b") (signature "deadbeef")
                             (exit-code 0) (fault nil))
  "Run verify-remote-attestation through PINNED ports over a fake process
transport; returns (values result call-count)."
  (let ((calls 0))
    (let ((ports (hngh.adapters.federation:make-pinned-attestation-ports
                  *fed-pinned-registry*
                  (lambda (argv)
                    (declare (ignore argv))
                    (incf calls)
                    (when fault (error "transport fault"))
                    (values exit-code "Verified OK" "")))))
      (values
       (hngh.adapters.federation:verify-remote-attestation
        (make-fixture-attestation :key-identifier key-identifier
                                  :signature signature)
        "2026-08-15T00:00:00Z" ports)
       calls))))

(multiple-value-bind (result calls)
    (fed-pinned-result)
  (check (and (eq :verified (att-status result))
              (equal "key-b"
                     (hngh.adapters.federation:attestation-result-key-identifier
                      result)))
         "pinned ports verify a good signature end to end")
  (check (= 1 calls)
         "the verified path runs exactly one transport call"))

(multiple-value-bind (result calls)
    (fed-pinned-result :exit-code 1)
  (check (and (eq :refused (att-status result))
              (equal '("bad-signature") (att-labels result)))
         "an openssl verification failure maps to bad-signature")
  (check (= 1 calls)
         "the bad-signature path ran the transport once"))

(multiple-value-bind (result calls)
    (fed-pinned-result :key-identifier "key-z")
  (check (and (eq :refused (att-status result))
              (equal '("unknown-peer-key") (att-labels result)))
         "an unpinned key refuses before any transport call")
  (check (zerop calls)
         "the unknown-peer-key path never reached the transport"))

(multiple-value-bind (result calls)
    (fed-pinned-result :signature "not-hex!")
  (check (and (eq :refused (att-status result))
              (equal '("bad-signature") (att-labels result)))
         "a malformed hex signature refuses closed")
  (check (zerop calls)
         "the malformed-signature path never reached the transport"))

(multiple-value-bind (result calls)
    (fed-pinned-result :fault t)
  (check (and (eq :fault (att-status result))
              (equal '("signature-fault") (att-labels result)))
         "a thrown transport maps to the signature fault")
  (check (= 1 calls)
         "the fault path attempted the transport once"))

(check (signals-error-p
        (lambda ()
          (hngh.adapters.federation:make-pinned-attestation-ports
           *fed-pinned-registry* "not-a-function")))
       "pinned ports refuse a non-function transport")

(let ((calls 0)
      (registry *fed-pinned-registry*))
  (let ((ports (hngh.adapters.federation:make-pinned-attestation-ports
                registry
                (lambda (argv)
                  (incf calls)
                  (values 0 "Verified OK" "")))))
    (dolist (attempt '(1 2))
      (let ((result (hngh.adapters.federation:verify-remote-attestation
                     (make-fixture-attestation :signature "deadbeef")
                     "2026-08-15T00:00:00Z" ports)))
        (check (eq :verified (att-status result))
               (format nil "verification ~A through shared ports still verifies"
                       attempt))))
    (check (= 2 calls)
           "each verification issues its own transport call")))

;;; Operator surface: pins file on verify-attestation + list-pins ----------

(defun fed-write-file (contents)
  "Write CONTENTS to a kept temp file; returns its namestring."
  (uiop:with-temporary-file (:pathname path :keep t)
    (with-open-file (stream path :direction :output :if-exists :supersede)
      (write-string contents stream))
    (namestring path)))

;; verify-attestation: the pins file is validated before anything else
(let ((root (fed-dispatch-root)))
  (let ((result (fed-dispatch
                 (list "verify-attestation" "run-1" "/tmp/hngh-missing-pins.txt"
                       "pins=/tmp/hngh-missing-pins.txt")
                 :root root)))
    (check (= 2 (fed-exit result))
           "a missing pins file is a malformed invocation")
    (check (fed-has "cannot read pins file" result)
           "the refusal names the unreadable pins file"))
  (let* ((path (fed-write-file "key-b /no-tab-here\n"))
         (result (fed-dispatch
                  (list "verify-attestation" "run-1" "/tmp/no-envelope.json"
                        (format nil "pins=~A" path))
                  :root root)))
    (check (= 2 (fed-exit result))
           "a malformed pins file is a malformed invocation")
    (check (fed-has "malformed pins file" result)
           "the refusal names the malformed pins file"))
  (let ((result (fed-dispatch
                 (list "verify-attestation" "run-1" "envelope.json"
                       "bogus=x")
                 :root root)))
    (check (= 2 (fed-exit result))
           "an unknown verify-attestation option is malformed"))
  (uiop:delete-directory-tree root :validate t))

;; list-pins: pure operator utility over the strict parser
(let* ((path (fed-write-file
              (concatenate 'string
                           "# operator pins" '(#\Newline)
                           "key-b" '(#\Tab) "/etc/hngh/keys/key-b.pub" '(#\Newline)
                           '(#\Newline)
                           "key-c" '(#\Tab) "/etc/hngh/keys/key-c.pub" '(#\Newline))))
       (result (fed-dispatch (list "list-pins" path))))
  (check (= 0 (fed-exit result))
         "list-pins renders a valid pins file")
  (check (and (fed-has (concatenate 'string
                                    "key-b" '(#\Tab)
                                    "/etc/hngh/keys/key-b.pub")
                       result)
              (fed-has (concatenate 'string
                                    "key-c" '(#\Tab)
                                    "/etc/hngh/keys/key-c.pub")
                       result)
              (not (fed-has "operator pins" result)))
         "list-pins prints one tab-joined line per pin and no comments"))

(let ((result (fed-dispatch (list "list-pins" "/tmp/hngh-missing-pins.txt"))))
  (check (= 2 (fed-exit result))
         "list-pins on a missing file is malformed")
  (check (fed-has "cannot read pins file" result)
         "list-pins names the unreadable file"))

(let* ((path (fed-write-file "key-b relative-key.pub\n"))
       (result (fed-dispatch (list "list-pins" path))))
  (check (= 2 (fed-exit result))
         "list-pins on a malformed file is malformed")
  (check (fed-has "malformed pins file" result)
         "list-pins names the malformed file"))

(let ((result (fed-dispatch (list "list-pins"))))
  (check (= 2 (fed-exit result))
         "list-pins without a path is malformed"))

(let ((result (fed-dispatch (list "list-pins" "/tmp/a" "/tmp/b"))))
  (check (= 2 (fed-exit result))
         "list-pins with two paths is malformed"))

(let* ((path (fed-write-file "# only comments\n"))
       (result (fed-dispatch (list "list-pins" path))))
  (check (and (= 0 (fed-exit result))
              (string= "" (first result)))
         "list-pins renders an empty registry as no lines"))

(let* ((path (fed-write-file
              (concatenate 'string
                           "key-b" '(#\Tab) "/etc/hngh/keys/key-b.pub"
                           '(#\Tab) "ed25519" '(#\Newline)
                           "key-c" '(#\Tab) "/etc/hngh/keys/key-c.pub")))
       (result (fed-dispatch (list "list-pins" path))))
  (check (= 0 (fed-exit result))
         "list-pins renders pins carrying explicit algorithms")
  (check (and (fed-has (concatenate 'string "key-b" '(#\Tab)
                                    "/etc/hngh/keys/key-b.pub" '(#\Tab)
                                    "ed25519")
                       result)
              (fed-has (concatenate 'string "key-c" '(#\Tab)
                                    "/etc/hngh/keys/key-c.pub" '(#\Tab)
                                    "rsa-sha256")
                       result))
         "list-pins prints the resolved algorithm per pin"))
