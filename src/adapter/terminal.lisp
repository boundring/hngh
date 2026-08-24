(in-package #:hngh.adapters.terminal)

;;; Rung 10: bounded operator terminal input adapter. The adapter captures
;;; one operator statement through an injected READ-STATEMENT callback and
;;; maps it to an OPERATOR-RESULT: a :complete capture binds the statement
;;; to one :terminal evidence fact (kind :terminal, state :current,
;;; fingerprint \"sha256:<hex>\"), or a closed :refused refusal. The
;;; statement is bounded (64KiB), printable, and control-character-free;
;;; duplicates within one ports object and a cancel (EOF, a nil read) refuse
;;; closed. A statement NEVER enters a certificate, mutation input, or any
;;; other control surface: it is only ever bound as a :terminal evidence
;;; fact. The digest is computed in-process (pure SHA-256, no external
;;; binary), so capture never spawns a subprocess. The adapter never decides
;;; policy and never contacts the operator directly: every read sits behind
;;; the injected callback and no default input source exists.

(defparameter +max-operator-statement-length+ 65536
  "Bound on one captured operator statement, mirroring the review output
bound: anything larger refuses as statement-too-large.")

;;; Printable statement validation -------------------------------------------------

(defun printable-statement-p (statement)
  "True when STATEMENT is a nonempty printable string within the bound:
no control characters and no DEL."
  (and (stringp statement)
       (plusp (length statement))
       (<= (length statement) +max-operator-statement-length+)
       (notany (lambda (char)
                 (or (char< char #\Space) (char= char (code-char 127))))
               statement)))

;;; In-process SHA-256 -----------------------------------------------------------
;;; A compact standard SHA-256 for the evidence fingerprint. It is pure and
;;; deterministic, verified against the published test vectors in
;;; tests/adapter/test-terminal.lisp, so capture never depends on an
;;; external hashing binary.

(defparameter +sha256-initial-hash+
  #(#x6a09e667 #xbb67ae85 #x3c6ef372 #xa54ff53a
    #x510e527f #x9b05688c #x1f83d9ab #x5be0cd19))

(defparameter +sha256-round-constants+
  #(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5 #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
    #xd807aa98 #x12835b01 #x243185be #x550c7dc3 #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
    #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
    #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7 #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
    #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13 #x650a7354 #x766a0abb #x81c2c92e #x92722c85
    #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3 #xd192e819 #xd6990624 #xf40e3585 #x106aa070
    #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5 #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
    #x748f82ee #x78a5636f #x84c87814 #x8cc70208 #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))

(defun sha256-mask (value) (logand value #xFFFFFFFF))

(defun sha256-rotate-right (value count)
  (sha256-mask (logior (ash value (- count)) (ash value (- 32 count)))))

(defun sha256-shift-right (value count)
  (sha256-mask (ash value (- count))))

(defun sha256-pad (octets)
  "Append the SHA-256 padding: 0x80, zero bytes, and the 64-bit bit length,
to a buffer sized to a whole number of 64-byte blocks."
  (let* ((length (length octets))
         (padded-length (* 64 (ceiling (+ length 9) 64)))
         (bit-length (* 8 length))
         (padded (make-array padded-length :element-type '(unsigned-byte 8)
                                        :initial-element 0)))
    (loop for index below length
          do (setf (aref padded index) (aref octets index)))
    (setf (aref padded length) #x80)
    (loop for index below 8
          do (setf (aref padded (- (length padded) 1 index))
                   (ldb (byte 8 (* 8 index)) bit-length)))
    padded))

(defun sha256-words (block)
  "The 64-word message schedule for one 64-byte BLOCK."
  (let ((w (make-array 64 :initial-element 0)))
    (dotimes (index 16)
      (let ((offset (* index 4)))
        (setf (aref w index)
              (sha256-mask
               (logior (ash (aref block offset) 24)
                       (ash (aref block (1+ offset)) 16)
                       (ash (aref block (+ 2 offset)) 8)
                       (aref block (+ 3 offset)))))))
    (dotimes (index 48)
      (let ((i (+ index 16)))
        (setf (aref w i)
              (sha256-mask
               (+ (logxor (sha256-rotate-right (aref w (- i 2)) 17)
                          (sha256-rotate-right (aref w (- i 2)) 19)
                          (sha256-shift-right (aref w (- i 2)) 10))
                  (aref w (- i 7))
                  (logxor (sha256-rotate-right (aref w (- i 15)) 7)
                          (sha256-rotate-right (aref w (- i 15)) 18)
                          (sha256-shift-right (aref w (- i 15)) 3))
                  (aref w (- i 16)))))))
    w))

(defun sha256-compress (block state)
  "Compress one 64-byte BLOCK into the 8-word STATE in place."
  (let* ((w (sha256-words block))
         (a (aref state 0)) (b (aref state 1)) (c (aref state 2))
         (d (aref state 3)) (e (aref state 4)) (f (aref state 5))
         (g (aref state 6)) (h (aref state 7)))
    (dotimes (i 64)
      (let* ((sigma1 (logxor (sha256-rotate-right e 6)
                             (sha256-rotate-right e 11)
                             (sha256-rotate-right e 25)))
             (choose (logxor (logand e f)
                             (logand (sha256-mask (lognot e)) g)))
             (temp1 (sha256-mask
                     (+ h sigma1 choose (aref +sha256-round-constants+ i)
                        (aref w i))))
             (sigma0 (logxor (sha256-rotate-right a 2)
                             (sha256-rotate-right a 13)
                             (sha256-rotate-right a 22)))
             (majority (logxor (logand a b) (logand a c) (logand b c)))
             (temp2 (sha256-mask (+ sigma0 majority))))
        (setf h g)
        (setf g f)
        (setf f e)
        (setf e (sha256-mask (+ d temp1)))
        (setf d c)
        (setf c b)
        (setf b a)
        (setf a (sha256-mask (+ temp1 temp2)))))
    (setf (aref state 0) (sha256-mask (+ (aref state 0) a)))
    (setf (aref state 1) (sha256-mask (+ (aref state 1) b)))
    (setf (aref state 2) (sha256-mask (+ (aref state 2) c)))
    (setf (aref state 3) (sha256-mask (+ (aref state 3) d)))
    (setf (aref state 4) (sha256-mask (+ (aref state 4) e)))
    (setf (aref state 5) (sha256-mask (+ (aref state 5) f)))
    (setf (aref state 6) (sha256-mask (+ (aref state 6) g)))
    (setf (aref state 7) (sha256-mask (+ (aref state 7) h))))
  state)

(defun sha256-hex (text)
  "Return the lowercase hexadecimal SHA-256 digest of TEXT's UTF-8 bytes."
  (let ((state (copy-seq +sha256-initial-hash+))
        (padded (sha256-pad (sb-ext:string-to-octets text))))
    (loop for start from 0 below (length padded) by 64
          do (sha256-compress (subseq padded start (+ start 64)) state))
    (string-downcase (format nil "~{~8,'0x~}" (coerce state 'list)))))

;;; Operator ports ----------------------------------------------------------

(defstruct (operator-ports
            (:constructor %make-operator-ports (read-statement))
            (:conc-name %operator-ports-))
  (read-statement nil :read-only t)
  (seen nil))

(defun make-operator-ports (&key read-statement)
  (unless (functionp read-statement)
    (error "operator ports require a read-statement callback"))
  (%make-operator-ports read-statement))

;;; Result -------------------------------------------------------------------

(defstruct (operator-result
            (:constructor %make-operator-result
                (status statement fact refusal-labels))
            (:conc-name %operator-result-))
  (status nil :read-only t)
  (statement nil :read-only t)
  (fact nil :read-only t)
  (refusal-labels nil :read-only t))

(defun operator-result-status (result)
  (%operator-result-status result))

(defun operator-result-statement (result)
  (let ((statement (%operator-result-statement result)))
    (and statement (copy-seq statement))))

(defun operator-result-fact (result)
  (%operator-result-fact result))

(defun operator-result-refusal-labels (result)
  (mapcar #'copy-seq (%operator-result-refusal-labels result)))

(defun complete-operator (statement fact)
  (%make-operator-result :complete statement fact nil))

(defun refused-operator (labels)
  (%make-operator-result :refused nil nil labels))

;;; Capture ------------------------------------------------------------------

(defun terminal-statement-fact (statement)
  (hngh.domain:make-evidence-fact
   :kind :terminal
   :fingerprint (format nil "sha256:~A" (sha256-hex statement))
   :state :current))

(defun capture-operator-statement (ports)
  "Read one statement through PORTS' read-statement callback (a nil return
is the operator's cancel/EOF) and return a closed OPERATOR-RESULT. Thrown
read faults refuse as transport-fault; oversized, unprintable, empty,
duplicate, or cancelled reads refuse closed. The statement is bound only as
a :terminal evidence fact and never enters any other surface."
  (unless (operator-ports-p ports)
    (error "capture-operator-statement requires operator ports"))
  (handler-case
      (let ((statement (funcall (%operator-ports-read-statement ports))))
        (cond
          ((null statement)
           (refused-operator '("malformed-statement")))
          ((not (stringp statement))
           (refused-operator '("malformed-statement")))
          ((> (length statement) +max-operator-statement-length+)
           (refused-operator '("statement-too-large")))
          ((not (printable-statement-p statement))
           (refused-operator '("malformed-statement")))
          ((member statement (%operator-ports-seen ports) :test #'string=)
           (refused-operator '("malformed-statement")))
          (t
           (push statement (%operator-ports-seen ports))
           (complete-operator statement (terminal-statement-fact statement)))))
    (error () (refused-operator '("transport-fault")))))