(in-package :hngh.tests)

;;;; Node-lattice admission rung: admit-peer — one explicit, recorded,
;;;; human-closable admission of a second node as a pinned federation peer.
;;;; Covers the pure domain evidence parser + staleness bound
;;;; (src/domain/attestation.lisp) and the CLI admit-peer flow
;;;; (src/main.lisp) against fixtures. This is a CLI command: there is no
;;;; watcher, no scheduler, and no background process anywhere in the
;;;; flow — each test drives one explicit dispatch-command call, and the
;;;; only store writes happen inside that call. The no-watcher invariant
;;;; is asserted structurally: one recorded ledger entry per admit-peer
;;;; invocation, and nothing runs between calls.

;;; Domain: admission evidence parsing ---------------------------------------

(defparameter *admit-fingerprint-256*
  (make-string 256 :initial-element #\a)
  "A fingerprint at the exact +max-attestation-fingerprint-length+ bound.")

(defparameter *admit-fingerprint-257*
  (make-string 257 :initial-element #\a)
  "One character over the fingerprint bound.")

(check (hngh.domain:admission-fingerprint-valid-p *admit-fingerprint-256*)
       "a fingerprint at the length bound is valid")
(check (not (hngh.domain:admission-fingerprint-valid-p *admit-fingerprint-257*))
       "a fingerprint over the length bound refuses")
(check (not (hngh.domain:admission-fingerprint-valid-p "has space"))
       "a fingerprint with whitespace refuses")
(check (not (hngh.domain:admission-fingerprint-valid-p ""))
       "an empty fingerprint refuses")

;; Pure UTC decode sanity: known epoch seconds.
(check (= 0 (hngh.domain:utc-string-seconds "1970-01-01T00:00:00Z"))
       "epoch decodes to zero")
(check (= 86400 (hngh.domain:utc-string-seconds "1970-01-02T00:00:00Z"))
       "one day after the epoch decodes to 86400")
(check (= 1784073600 (hngh.domain:utc-string-seconds "2026-07-15T00:00:00Z"))
       "a 2026 date decodes to its epoch seconds")
(check (null (hngh.domain:utc-string-seconds "2026-08-01T00:00:00"))
       "a non-UTC-shape string decodes to nil")

;; Staleness: the last-seen must be within one day of now.
(check (not (hngh.domain:stale-last-seen-p "2026-08-15T00:00:00Z"
                                           (hngh.domain:utc-string-seconds
                                            "2026-08-15T12:00:00Z")))
       "a twelve-hour-old last-seen is fresh")
(check (hngh.domain:stale-last-seen-p "2026-08-13T00:00:00Z"
                                      (hngh.domain:utc-string-seconds
                                       "2026-08-15T12:00:00Z"))
       "a last-seen over the one-day window is stale")
(check (hngh.domain:stale-last-seen-p "not-a-timestamp" 0)
       "an unparseable last-seen is stale (fails closed)")

(multiple-value-bind (fingerprint last-seen)
    (hngh.domain:parse-admission-evidence
     (format nil "~A~C2026-08-15T00:00:00Z~%"
             *admit-fingerprint-256* #\Newline))
  (check (and (string= *admit-fingerprint-256* fingerprint)
              (string= "2026-08-15T00:00:00Z" last-seen))
         "a two-line evidence file parses to fingerprint and last-seen"))

(check (signals-error-p
        (lambda ()
          (hngh.domain:parse-admission-evidence "one-line-only\n")))
       "a one-line evidence file refuses")
(check (signals-error-p
        (lambda ()
          (hngh.domain:parse-admission-evidence
           (format nil "~A~C2026-08-15 00:00:00~%"
                   *admit-fingerprint-256* #\Newline))))
       "a malformed last-seen line refuses")
(check (signals-error-p
        (lambda ()
          (hngh.domain:parse-admission-evidence
           (format nil "~A~C2026-08-15T00:00:00Z~%" "x y" #\Newline))))
       "a whitespace fingerprint line refuses")

;;; CLI: the admit-peer flow --------------------------------------------------
;;; Same fixture machinery as the federation dispatch tests: a scratch
;;; store root, a created run admitted for :federation, and an offline
;;; evidence file. The clock is injected, so nothing here consults the
;;; wall clock, spawns a process, or opens a socket.

(defparameter +admit-create-args+ +fed-fetch-create-args+)

(defun admit-write-file (contents)
  (fed-write-file contents))

(defun admit-evidence (fingerprint last-seen)
  (admit-write-file
   (format nil "~A~C~A~%" fingerprint #\Newline last-seen)))

(defun admit-setup ()
  "A fresh store root with run-1 created and admitted for :federation."
  (let ((root (fed-dispatch-root)))
    (fed-dispatch +admit-create-args+ :root root)
    (fed-dispatch '("admit-transport" "run-1" "federation" "repository")
                  :root root)
    root))

(defun admit-entry-count (root)
  "How many recorded entries the scratch store holds."
  (length (hngh.adapters.filesystem:store-entries
           (hngh.adapters.filesystem:make-filesystem-store
            :root root))))

;; Happy path: admitted run, fresh evidence, one recorded step.
(let ((root (admit-setup))
      (evidence (admit-evidence *admit-fingerprint-256*
                                "2026-08-15T00:00:00Z")))
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-1" evidence "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:00:00Z"))))
    (check (= 0 (fed-exit result))
           "admit-peer admits a peer for an admitted run with fresh evidence")
    (check (fed-has "status=admitted" result)
           "the admitted output renders")
    (check (fed-has "machine-b" result)
           "the admitted output names the peer")
    (check (= 3 (admit-entry-count root))
           "exactly one new ledger entry was recorded by admit-peer"))
  (uiop:delete-directory-tree root :validate t))

;; Stale evidence refuses (last-seen over the one-day window).
(let ((root (admit-setup))
      (evidence (admit-evidence *admit-fingerprint-256*
                                "2026-08-01T00:00:00Z")))
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-1" evidence "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:00:00Z"))))
    (check (= 1 (fed-exit result))
           "stale last-seen refuses admission")
    (check (fed-has "stale-admission-evidence" result)
           "the refusal names stale-admission-evidence"))
  (check (= 2 (admit-entry-count root))
         "a stale refusal records nothing")
  (uiop:delete-directory-tree root :validate t))

;; Malformed evidence refuses (missing last-seen line).
(let ((root (admit-setup))
      (evidence (admit-write-file
                 (format nil "~A~%" *admit-fingerprint-256*))))
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-1" evidence "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:00:00Z"))))
    (check (= 2 (fed-exit result))
           "malformed evidence is a malformed invocation")
    (check (fed-has "malformed-admission-evidence" result)
           "the refusal names malformed-admission-evidence"))
  (uiop:delete-directory-tree root :validate t))

;; Missing evidence file refuses.
(let ((root (admit-setup)))
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-1" "/tmp/hngh-missing-evidence.txt"
                       "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:00:00Z"))))
    (check (= 2 (fed-exit result))
           "a missing evidence file is malformed")
    (check (fed-has "malformed-admission-evidence" result)
           "the refusal names malformed-admission-evidence"))
  (uiop:delete-directory-tree root :validate t))

;; Oversized fingerprint refuses (evidence malformed at the bound).
(let ((root (admit-setup))
      (evidence (admit-evidence *admit-fingerprint-257*
                                "2026-08-15T00:00:00Z")))
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-1" evidence "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:00:00Z"))))
    (check (= 2 (fed-exit result))
           "an oversized fingerprint is malformed")
    (check (fed-has "malformed-admission-evidence" result)
           "the oversized-fingerprint refusal names malformed-admission-evidence"))
  (uiop:delete-directory-tree root :validate t))

;; Duplicate peer refuses on a second admission for the same peer.
(let ((root (admit-setup))
      (evidence (admit-evidence *admit-fingerprint-256*
                                "2026-08-15T00:00:00Z")))
  (fed-dispatch (list "admit-peer" "run-1" evidence "machine-b")
                :root root
                :clock (lambda () "2026-08-15T12:00:00Z"))
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-1" evidence "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:30:00Z"))))
    (check (= 1 (fed-exit result))
           "a duplicate peer admission refuses")
    (check (fed-has "duplicate peer" result)
           "the refusal names the duplicate peer"))
  (check (= 3 (admit-entry-count root))
         "the duplicate refusal added no ledger entry")
  (uiop:delete-directory-tree root :validate t))

;; Run without a :federation admission receipt refuses.
(let ((root (fed-dispatch-root))
      (evidence (admit-evidence *admit-fingerprint-256*
                                "2026-08-15T00:00:00Z")))
  (fed-dispatch +admit-create-args+ :root root)
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-1" evidence "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:00:00Z"))))
    (check (= 1 (fed-exit result))
           "admit-peer refuses a run not admitted for federation")
    (check (fed-has "not admitted for federation" result)
           "the refusal names the missing federation admission"))
  (uiop:delete-directory-tree root :validate t))

;; Unknown run refuses.
(let ((root (fed-dispatch-root))
      (evidence (admit-evidence *admit-fingerprint-256*
                                "2026-08-15T00:00:00Z")))
  (let ((result (fed-dispatch
                 (list "admit-peer" "run-x" evidence "machine-b")
                 :root root
                 :clock (lambda () "2026-08-15T12:00:00Z"))))
    (check (= 1 (fed-exit result))
           "an unknown run refuses closed"))
  (uiop:delete-directory-tree root :validate t))

;; Wrong arity and unknown options are malformed.
(let ((root (admit-setup))
      (evidence (admit-evidence *admit-fingerprint-256*
                                "2026-08-15T00:00:00Z")))
  (check (= 2 (fed-exit (fed-dispatch (list "admit-peer" "run-1" evidence)
                                      :root root)))
         "admit-peer with two positionals is malformed")
  (check (= 2 (fed-exit (fed-dispatch
                         (list "admit-peer" "run-1" evidence "machine-b" "extra")
                         :root root)))
         "admit-peer with four positionals is malformed")
  (check (= 2 (fed-exit (fed-dispatch
                         (list "admit-peer" "run-1" evidence "machine-b" "bogus=x")
                         :root root)))
         "admit-peer rejects unknown options")
  (uiop:delete-directory-tree root :validate t))

;; No-watcher invariant: admit-peer is a single explicit CLI step. The
;; tests above each drive exactly one dispatch-command call and assert
;; the exact ledger entry delta inside that call; nothing in the diff
;; starts a process, thread, timer, or scheduler. One request admits one
;; peer: the happy path records exactly one entry per invocation.
