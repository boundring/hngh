(in-package #:hngh.domain)

;;; Distributed attestation: the two pure kernel pieces the federation
;;; design admits. The kernel owns the REMOTE-ATTESTATION value (an
;;; operator-pinned envelope: issuer peer, signing key identifier, exact
;;; signed payload bytes, signature, a bounded duplicate-free claim set,
;;; the issuer-supplied expiry window, and the bounded skew) and the closed
;;; structural checker VERIFY-ATTESTATION-SHAPE plus UTC string validation.
;;;
;;; Split of duties, per the design paper: the *constructors* enforce only
;;; type-level invariants so a parsed (possibly hostile) envelope is
;;; representable; VERIFY-ATTESTATION-SHAPE is the single semantic gate —
;;; closed fields, bounded sizes, valid UTC strings, duplicate-free
;;; claims — and returns (values valid labels) without raising. The
;;; adapter runs the checker and maps any invalid result to a closed
;;; refusal. Nothing here reads a clock, a key store, or a socket.

(defparameter +remote-claim-kinds+
  '(:content-hash :repository-revision :working-tree-status)
  "The closed claim kinds a carrier bundle may carry. Each maps to the
same-named evidence fact kind; the shape checker refuses anything outside
this set.")

;;; Bounds, all enforced by the shape checker; the adapter maps an
;;; oversized envelope to the closed output-too-large refusal.
(defparameter +max-attestation-peer-length+ 64
  "Bound on one plain peer identifier (no URL, no path).")
(defparameter +max-attestation-key-identifier-length+ 128
  "Bound on one signing key identifier.")
(defparameter +max-attestation-payload-length+ 65536
  "Bound on the exact signed payload bytes.")
(defparameter +max-attestation-signature-length+ 8192
  "Bound on one issuer signature.")
(defparameter +max-attestation-claims+ 32
  "Bound on one envelope's claim set.")
(defparameter +max-attestation-fingerprint-length+ 256
  "Bound on one claim fingerprint.")
(defparameter +max-attestation-skew-seconds+ 86400
  "Bound on the issuer-supplied clock skew window (one day).")

(defun ensure-plain-identifier (value name)
  "A peer or key identifier is a bounded, printable, plain string: no URL
scheme, no path separators, no whitespace or control characters."
  (unless (and (stringp value)
               (plusp (length value))
               (<= (length value) +max-attestation-key-identifier-length+)
               (every (lambda (char)
                        (and (graphic-char-p char)
                             (not (find char ":/\\@\"<> "))))
                      value))
    (error "~A must be a plain bounded identifier: ~S" name value))
  (copy-seq value))

;;; Claim -------------------------------------------------------------------
;;; One immutable claim inside an envelope: a KIND (a keyword the checker
;;; must admit) plus a bounded fingerprint string. The constructor is
;;; type-level so hostile parsed kinds are representable for the checker.

(defstruct (remote-claim
            (:constructor %make-remote-claim (kind fingerprint))
            (:conc-name %remote-claim-))
  (kind nil :read-only t)
  (fingerprint nil :read-only t))

(defun remote-claim-kind (claim)
  (%remote-claim-kind claim))

(defun remote-claim-fingerprint (claim)
  (copy-seq (%remote-claim-fingerprint claim)))

(defun make-remote-claim (&key kind fingerprint)
  (unless (and (stringp fingerprint)
               (plusp (length fingerprint)))
    (error "Remote claim fingerprint must be a nonempty string"))
  (%make-remote-claim
   (ensure-keyword kind "remote claim kind")
   (copy-seq fingerprint)))

(defun remote-claim-identity (claim)
  "Deterministic identity of one claim: used for duplicate detection."
  (list (remote-claim-kind claim) (remote-claim-fingerprint claim)))

(defun ensure-attestation-claims (value)
  (unless (and (listp value)
               (every #'remote-claim-p value))
    (error "Remote attestation claims must be a list of claims"))
  (copy-list value))

;;; The envelope ------------------------------------------------------------
;;; REMOTE-ATTESTATION is the value the adapter hands back for a parsed
;;; carrier bundle. It carries raw-at-rest fields; the pure shape checker
;;; decides validity and the adapter decides trust. It never carries a
;;; callback, clock, or network handle.

(defstruct (remote-attestation
            (:constructor %make-remote-attestation
                (peer key-identifier payload signature claims
                 not-before not-after skew))
            (:conc-name %remote-attestation-))
  (peer nil :read-only t)           ;; validated plain peer identifier
  (key-identifier nil :read-only t) ;; signing key id
  (payload nil :read-only t)        ;; exact signed payload bytes
  (signature nil :read-only t)      ;; issuer signature
  (claims nil :read-only t)         ;; bounded duplicate-free claims
  (not-before nil :read-only t)     ;; UTC string
  (not-after nil :read-only t)      ;; UTC string
  (skew nil :read-only t))          ;; nonnegative integer seconds

(defun remote-attestation-peer (attestation)
  (copy-seq (%remote-attestation-peer attestation)))
(defun remote-attestation-key-identifier (attestation)
  (copy-seq (%remote-attestation-key-identifier attestation)))
(defun remote-attestation-payload (attestation)
  (copy-seq (%remote-attestation-payload attestation)))
(defun remote-attestation-signature (attestation)
  (copy-seq (%remote-attestation-signature attestation)))
(defun remote-attestation-claims (attestation)
  (copy-list (%remote-attestation-claims attestation)))
(defun remote-attestation-not-before (attestation)
  (copy-seq (%remote-attestation-not-before attestation)))
(defun remote-attestation-not-after (attestation)
  (copy-seq (%remote-attestation-not-after attestation)))
(defun remote-attestation-skew (attestation)
  (%remote-attestation-skew attestation))

(defun make-remote-attestation
    (&key peer key-identifier payload signature claims
       (not-before nil not-before-p)
       (not-after nil not-after-p)
       (skew nil skew-p))
  (unless (and not-before-p not-after-p skew-p)
    (error "Remote attestation fields are required"))
  (unless (and (stringp payload) (plusp (length payload)))
    (error "Remote attestation payload must be a nonempty string"))
  (unless (and (stringp signature) (plusp (length signature)))
    (error "Remote attestation signature must be a nonempty string"))
  (unless (integerp skew)
    (error "Remote attestation skew must be an integer"))
  (unless (and (stringp not-before) (stringp not-after))
    (error "Remote attestation expiry fields must be strings"))
  (%make-remote-attestation
   (ensure-plain-identifier peer "peer identifier")
   (ensure-plain-identifier key-identifier "key identifier")
   (copy-seq payload)
   (copy-seq signature)
   (ensure-attestation-claims claims)
   (copy-seq not-before)
   (copy-seq not-after)
   skew))

;;; UTC string validation ---------------------------------------------------
;;; The checker needs UTC validity with no clock: a strict, fixed-width
;;; `YYYY-MM-DDTHH:MM:SSZ` shape with range-checked fields. Everything the
;;; harness clock emits (`format-utc-timestamp`) matches this shape.

(defun utc-string-p (text)
  "True when TEXT is a valid, fixed-width UTC timestamp of the form
`YYYY-MM-DDTHH:MM:SSZ` with range-checked month, day, hour, minute, and
second fields. Pure string shape: no clock, no timezone arithmetic."
  (when (and (stringp text) (= (length text) 20))
    (let ((month (parse-integer text :start 5 :end 7))
          (day (parse-integer text :start 8 :end 10)))
      (and (char= (char text 4) #\-)
           (char= (char text 7) #\-)
           (char= (char text 10) #\T)
           (char= (char text 13) #\:)
           (char= (char text 16) #\:)
           (char= (char text 19) #\Z)
           (every #'digit-char-p (subseq text 0 4))
           (every #'digit-char-p (subseq text 5 7))
           (every #'digit-char-p (subseq text 8 10))
           (every #'digit-char-p (subseq text 11 13))
           (every #'digit-char-p (subseq text 14 16))
           (every #'digit-char-p (subseq text 17 19))
           (<= 1 month 12)
           (<= 1 day 31)
           (<= 0 (parse-integer text :start 11 :end 13) 23)
           (<= 0 (parse-integer text :start 14 :end 16) 59)
           (<= 0 (parse-integer text :start 17 :end 19) 59)))))

;;; Shape checker -----------------------------------------------------------
;;; Pure structural validation over a REMOTE-ATTESTATION value. It never
;;; consults the outside world and returns (values valid-p refusal-labels).
;;; The adapter turns any invalid result into the closed malformed-
;;; attestation (or sharper) refusal, so the kernel's word is the single
;;; source of shape truth.

(defun verify-attestation-shape (attestation)
  "Return (values valid-p refusal-labels) for one REMOTE-ATTESTATION value.
Checks: plain bounded identifier fields; bounded sizes; a bounded claim
list in the closed vocabulary; valid UTC expiry strings with sane window
ordering; bounded nonnegative skew; and a duplicate-free claim set."
  (flet ((bad-at (label) (return-from verify-attestation-shape
                           (values nil (list label)))))
    (let* ((peer (remote-attestation-peer attestation))
           (key-identifier (remote-attestation-key-identifier attestation))
           (payload (remote-attestation-payload attestation))
           (signature (remote-attestation-signature attestation))
           (claims (remote-attestation-claims attestation))
           (not-before (remote-attestation-not-before attestation))
           (not-after (remote-attestation-not-after attestation))
           (skew (remote-attestation-skew attestation)))
      ;; identifier fields
      (unless (and (stringp peer)
                   (plusp (length peer))
                   (<= (length peer) +max-attestation-peer-length+)
                   (every (lambda (char)
                            (and (graphic-char-p char)
                                 (not (find char ":/\\@\"<> "))))
                          peer))
        (bad-at "malformed-attestation"))
      (unless (and (stringp key-identifier)
                   (plusp (length key-identifier))
                   (<= (length key-identifier)
                       +max-attestation-key-identifier-length+)
                   (every (lambda (char)
                            (and (graphic-char-p char)
                                 (not (find char ":/\\@\"<> "))))
                          key-identifier))
        (bad-at "malformed-attestation"))
      ;; bounded sizes
      (when (or (> (length payload) +max-attestation-payload-length+)
                (> (length signature) +max-attestation-signature-length+))
        (bad-at "output-too-large"))
      (unless (and (listp claims)
                   (<= (length claims) +max-attestation-claims+)
                   (every #'remote-claim-p claims))
        (bad-at "malformed-attestation"))
      ;; closed claim vocabulary + duplicate-free claims
      (dolist (claim claims)
        (unless (member (remote-claim-kind claim) +remote-claim-kinds+
                        :test #'eq)
          (bad-at "malformed-attestation")))
      (unless (= (length claims)
                 (length (remove-duplicates
                          (mapcar #'remote-claim-identity claims)
                          :test #'equal)))
        (bad-at "duplicate-claim"))
      ;; UTC expiry fields, window ordering, bounded nonnegative skew
      (unless (and (utc-string-p not-before)
                   (utc-string-p not-after))
        (bad-at "malformed-expiry"))
      ;; fixed-width UTC strings compare correctly as strings
      (when (string< not-after not-before)
        (bad-at "malformed-expiry"))
      (unless (and (integerp skew) (not (minusp skew))
                   (<= skew +max-attestation-skew-seconds+))
        (bad-at "malformed-attestation"))
      (values t nil))))

;;; Operator-pinned keys -----------------------------------------------------
;;; The pinned-key registry is the trust anchor for cross-machine
;;; attestation (design record 2026-08-24): a closed list of named
;;; public-key paths the operator explicitly admitted. Pure values only —
;;; reading key bytes, running openssl, or consulting a clock stays in the
;;; federation adapter behind injected ports. Anything absent from the
;;; registry lands on the adapter's unknown-peer-key refusal.

(defun key-path-components (text)
  "The nonempty components of an absolute POSIX path string, filename
included (unlike PATHNAME-DIRECTORY, which excludes it)."
  (remove ""
          (loop for start = 1 then (1+ end)
                for end = (position #\/ text :start start)
                collect (subseq text start (or end (length text)))
                while end)
          :test #'string=))

(defun ensure-absolute-key-path (value name)
  "A pinned key path is an absolute POSIX path: a pathname or namestring
naming one, with no option-like path component (none starting with `-`)."
  (let ((text (cond ((pathnamep value) (namestring value))
                    ((stringp value) value)
                    (t nil))))
    (unless (and text (plusp (length text)) (char= (char text 0) #\/))
      (error "~A must be an absolute key path: ~S" name value))
    (dolist (component (key-path-components text))
      (when (char= (char component 0) #\-)
        (error "~A must not contain option-like path components: ~S"
               name value)))
    (copy-seq text)))

(defstruct (key-pin
            (:constructor %make-key-pin (key-identifier key-path))
            (:conc-name %key-pin-))
  (key-identifier nil :read-only t)
  (key-path nil :read-only t))

(defun key-pin-key-identifier (pin)
  (copy-seq (%key-pin-key-identifier pin)))

(defun key-pin-key-path (pin)
  (copy-seq (%key-pin-key-path pin)))

(defun make-key-pin (&key key-identifier key-path)
  (%make-key-pin
   (ensure-plain-identifier key-identifier "key pin identifier")
   (ensure-absolute-key-path key-path "key pin path")))

(defstruct (key-pin-registry
            (:constructor %make-key-pin-registry (pins))
            (:conc-name %key-pin-registry-))
  (pins nil :read-only t))

(defun key-pin-registry-pins (registry)
  (copy-list (%key-pin-registry-pins registry)))

(defun make-key-pin-registry (pins)
  "An immutable registry over a list of key pins; duplicate key
identifiers refuse. The registry copies the caller-owned list."
  (unless (and (listp pins) (every #'key-pin-p pins))
    (error "Key pin registry requires a list of key pins"))
  (let ((seen '()))
    (dolist (pin pins)
      (let ((identifier (key-pin-key-identifier pin)))
        (when (member identifier seen :test #'string=)
          (error "duplicate pin: ~A" identifier))
        (push identifier seen))))
  (%make-key-pin-registry (copy-list pins)))

(defun lookup-key-pin (registry key-identifier)
  "The pinned key for KEY-IDENTIFIER, or NIL when nothing is pinned
under that identifier."
  (find key-identifier (%key-pin-registry-pins registry)
        :test #'string=
        :key #'%key-pin-key-identifier))
