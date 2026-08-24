(in-package #:hngh.tests)

;;; Rung 10 bounded terminal input adapter tests. Every capture runs through
;;; the injected fake ports; no test reads a real terminal, spawns a
;;; subprocess, or contacts any external tool. The SHA-256 fingerprint is
;;; verified against the published standard test vectors.

(defun terminal-symbol (name)
  (let ((package (find-package :hngh.adapters.terminal)))
    (unless package
      (error "terminal adapter package is unavailable"))
    (multiple-value-bind (symbol status) (find-symbol name package)
      (unless (and symbol (eq status :external))
        (error "terminal symbol is unavailable: ~A" name))
      symbol)))

(defun terminal-function (name)
  (let ((symbol (terminal-symbol name)))
    (unless (fboundp symbol)
      (error "terminal function is unavailable: ~A" name))
    (symbol-function symbol)))

(defun terminal-call (name &rest arguments)
  (apply (terminal-function name) arguments))

(defun make-operator-ports (&rest arguments)
  (apply #'terminal-call "MAKE-OPERATOR-PORTS" arguments))

(defun capture-statement (ports)
  (terminal-call "CAPTURE-OPERATOR-STATEMENT" ports))

(defun result-status (result)
  (terminal-call "OPERATOR-RESULT-STATUS" result))

(defun result-statement (result)
  (terminal-call "OPERATOR-RESULT-STATEMENT" result))

(defun result-fact (result)
  (terminal-call "OPERATOR-RESULT-FACT" result))

(defun result-refusals (result)
  (terminal-call "OPERATOR-RESULT-REFUSAL-LABELS" result))

(defun fact-kind (fact)
  (hngh.domain:evidence-fact-kind fact))

(defun fact-state (fact)
  (hngh.domain:evidence-fact-state fact))

(defun fact-fingerprint (fact)
  (hngh.domain:evidence-fact-fingerprint fact))

(defun sha256-hex (text)
  (terminal-call "SHA256-HEX" text))

;;; SHA-256 known-answer vectors (FIPS 180-4 and the standard examples) ------

(let ((vectors '(("" . "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
                 ("a" . "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb")
                 ("abc" . "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
                 ("The quick brown fox jumps over the lazy dog"
                  . "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592")
                 ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
                  . "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"))))
  (dolist (pair vectors)
    (check (string= (cdr pair) (sha256-hex (car pair)))
           (format nil "sha256 known-answer vector matches for ~S" (car pair)))))

;;; Ports construction --------------------------------------------------------

(check (signals-error-p (lambda () (make-operator-ports)))
       "operator ports require a read-statement callback")
(check (signals-error-p (lambda () (make-operator-ports :read-statement nil)))
       "operator ports reject a missing read callback")
(check (signals-error-p (lambda () (capture-statement :not-ports)))
       "capture requires an operator ports object")

;;; Complete capture ----------------------------------------------------------

(multiple-value-bind (ports reporter)
    (make-operator-ports-fake
     :responses (list (list :return "operator statement")))
  (let ((result (capture-statement ports)))
    (check (eq :complete (result-status result))
           "a printable in-bound statement completes")
    (check (string= "operator statement" (result-statement result))
           "captured statement round-trips")
    (check (null (result-refusals result))
           "complete capture carries no refusal labels")
    (let ((fact (result-fact result)))
      (check (eql :terminal (fact-kind fact))
             "capture fact is a :terminal evidence fact")
      (check (eql :current (fact-state fact))
             "capture fact is current")
      (check (string= (format nil "sha256:~A" (sha256-hex "operator statement"))
                      (fact-fingerprint fact))
             "capture fingerprint binds sha256 to the exact statement")))
  (let ((state (funcall reporter)))
    (check (= 1 (getf state :calls))
           "capture reads exactly one statement")
    (check (zerop (getf state :remaining))
           "capture consumes the scripted answer")))

;;; Fingerprint binding is deterministic and statement-specific ---------------

(let ((first-result (capture-statement
                     (make-operator-ports :read-statement
                                          (lambda () "same words"))))
      (second-result (capture-statement
                      (make-operator-ports :read-statement
                                           (lambda () "same words")))))
  (check (string= (fact-fingerprint (result-fact first-result))
                  (fact-fingerprint (result-fact second-result)))
         "identical statements produce identical fingerprints")
  (let ((different (capture-statement
                    (make-operator-ports :read-statement
                                         (lambda () "other words")))))
    (check (not (string= (fact-fingerprint (result-fact first-result))
                         (fact-fingerprint (result-fact different))))
           "different statements produce different fingerprints")))

;;; Oversized statements refuse ----------------------------------------------

(multiple-value-bind (ports reporter)
    (make-operator-ports-fake
     :responses (list (list :return (make-string 65537 :initial-element #\x))))
  (let ((result (capture-statement ports)))
    (check (eq :refused (result-status result))
           "statement beyond 64KiB refuses")
    (check (member "statement-too-large" (result-refusals result)
                   :test #'string=)
           "oversized statement names statement-too-large")
    (check (null (result-fact result))
           "oversized statement carries no fact")
    (check (null (result-statement result))
           "oversized statement carries no statement"))
  (let ((state (funcall reporter)))
    (check (= 1 (getf state :calls))
           "oversized refusal still reads exactly once")))

;;; Unprintable and malformed statements refuse -------------------------------

(dolist (statement (list ""
                        (format nil "legit~Cline" #\Newline)
                        (format nil "tab~Chere" #\Tab)
                        (format nil "bell~C" (code-char 7))
                        (format nil "del~C" (code-char 127))
                        42
                        :not-a-statement))
  (multiple-value-bind (ports reporter)
      (make-operator-ports-fake :responses (list (list :return statement)))
    (let ((result (capture-statement ports)))
      (check (eq :refused (result-status result))
             (format nil "unprintable statement ~S refuses" statement))
      (check (member "malformed-statement" (result-refusals result)
                     :test #'string=)
             (format nil "unprintable statement ~S names malformed-statement" statement))
      (check (null (result-fact result))
             "unprintable statement carries no fact"))))

;;; Cancel (EOF) refuses ------------------------------------------------------

(multiple-value-bind (ports reporter)
    (make-operator-ports-fake :responses (list (list :cancel)))
  (let ((result (capture-statement ports)))
    (check (eq :refused (result-status result))
           "a cancelled read (EOF) refuses")
    (check (member "malformed-statement" (result-refusals result)
                   :test #'string=)
           "a cancelled read names malformed-statement")
    (check (null (result-fact result))
           "a cancelled read carries no fact")))

;;; Thrown read faults refuse as transport-fault ------------------------------

(multiple-value-bind (ports reporter)
    (make-operator-ports-fake :responses (list (list :error "input broke")))
  (let ((result (capture-statement ports)))
    (check (eq :refused (result-status result))
           "a thrown read fault refuses")
    (check (equal '("transport-fault") (result-refusals result))
           "a thrown read fault names transport-fault")
    (check (null (result-fact result))
           "a thrown read fault carries no fact")))

;;; Duplicates refuse within one ports object ---------------------------------

(multiple-value-bind (ports reporter)
    (make-operator-ports-fake
     :responses (list (list :return "captured once")
                      (list :return "captured once")
                      (list :return "fresh statement")))
  (let ((first (capture-statement ports)))
    (check (eq :complete (result-status first))
           "first capture of a statement completes")
    (check (string= "captured once" (result-statement first))
           "first capture binds the statement"))
  (let ((duplicate (capture-statement ports)))
    (check (eq :refused (result-status duplicate))
           "a duplicate statement refuses")
    (check (member "malformed-statement" (result-refusals duplicate)
                   :test #'string=)
           "a duplicate statement names malformed-statement")
    (check (null (result-fact duplicate))
           "a duplicate statement carries no fact"))
  (let ((fresh (capture-statement ports)))
    (check (eq :complete (result-status fresh))
           "a fresh statement still completes after a duplicate refusal")
    (check (string= "fresh statement" (result-statement fresh))
           "the fresh statement binds its own text"))
  (let ((state (funcall reporter)))
    (check (= 3 (getf state :calls))
           "duplicate refusals still consume the scripted reads")))