(in-package #:hngh.main)

;;; Rung 7: composition root. MAIN is the only package that depends on
;;; presentation, the installed adapters, application, and domain together.
;;; It starts no background work and has zero side effects on load. The
;;; run harness composes the five application use cases over injected or
;;; default port adapters; the coordinator functions wire the installed
;;; evidence, review, and mutation adapters through injected transports;
;;; `display` renders any result through hngh.presentation. Default ports
;;; fail closed: no authority, verification, or manifest is invented here.

;;; In-memory record store (the operator-visible root) ---------------------

(defstruct (run-store (:constructor %make-run-store ()))
  (entries nil))

(defun make-run-store ()
  (%make-run-store))

(defun store-record-run (store run receipt)
  (push (cons run receipt) (run-store-entries store))
  :recorded)

(defun store-entries (store)
  (copy-list (run-store-entries store)))

;;; Default port adapters ---------------------------------------------------

(defun default-identifier-source ()
  "Per-harness monotone identifier source. No global counter, so separate
harnesses never collide or share mutable state."
  (let ((counter 0))
    (lambda ()
      (incf counter)
      (format nil "run-~D" counter))))

(defun format-utc-timestamp (universal-time)
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            year month day hour minute second)))

(defun default-clock-callback ()
  (lambda ()
    (format-utc-timestamp (get-universal-time))))

(defun default-record-callback ()
  (let ((store (make-run-store)))
    (values (lambda (run receipt)
              (store-record-run store run receipt))
            store)))

(defun default-admission-facts ()
  (hngh.application:make-admission-facts
   :authority :unknown :ledger :unknown :loadout :unknown
   :exclusive-write :unknown))

(defun default-admission-callback ()
  (lambda (run)
    (declare (ignore run))
    (default-admission-facts)))

(defun default-verification-callback ()
  (lambda (request)
    (declare (ignore request))
    (hngh.application:make-verification-result
     :status :unknown :labels '("no-verifier"))))

(defun default-manifest-callback ()
  (lambda (request)
    (declare (ignore request))
    (hngh.application:make-manifest-result
     :status :unknown :labels '("no-inspector"))))

;;; Run harness --------------------------------------------------------------

(defstruct (run-harness
            (:constructor %make-run-harness
                (create arm start checkpoint close records))
            (:conc-name %run-harness-))
  (create nil :read-only t)
  (arm nil :read-only t)
  (start nil :read-only t)
  (checkpoint nil :read-only t)
  (close nil :read-only t)
  (records nil :read-only t))

(defun make-run-harness (&key next-identifier clock-now record-run admission-facts
                              tool-executor repository-inspector)
  "Compose the complete run lifecycle. Every key is an injected port
callback; omitted ones default to fail-closed or environment-free ports.
RECORD-RUN may be a callback (the refusals and records then live outside the
harness) or omitted to keep an in-memory store reachable via
HARNESS-RECORDS."
  (multiple-value-bind (record records)
      (if record-run
          (values record-run nil)
          (default-record-callback))
    (let ((identifier-source (or next-identifier (default-identifier-source)))
          (clock (or clock-now (default-clock-callback)))
          (facts (or admission-facts (default-admission-callback)))
          (verifier (or tool-executor (default-verification-callback)))
          (inspector (or repository-inspector (default-manifest-callback))))
      (%make-run-harness
       (lambda (mission role loadout)
         (hngh.application:create-run
          (hngh.application:make-run-creation-ports
           :next-identifier identifier-source
           :clock-now clock
           :record-run record)
          mission role loadout))
       (lambda (run)
         (hngh.application:arm-run
          (hngh.application:make-run-admission-ports
           :admission-facts facts
           :record-run record)
          run))
       (lambda (run)
         (hngh.application:start-run
          (hngh.application:make-run-start-ports :record-run record)
          run))
       (lambda (run)
         (hngh.application:checkpoint
          (hngh.application:make-run-checkpoint-ports
           :tool-executor verifier
           :repository-inspector inspector
           :record-run record)
          run))
       (lambda (run target proposal)
         (hngh.application:close-run
          (hngh.application:make-run-close-ports :record-run record)
          (hngh.application:make-close-request
           :run run :target target :proposal proposal)))
       records))))

(defun harness-create-run (harness mission role loadout)
  (funcall (%run-harness-create harness) mission role loadout))

(defun harness-arm-run (harness run)
  (funcall (%run-harness-arm harness) run))

(defun harness-start-run (harness run)
  (funcall (%run-harness-start harness) run))

(defun harness-checkpoint (harness run)
  (funcall (%run-harness-checkpoint harness) run))

(defun harness-close-run (harness run target proposal)
  (funcall (%run-harness-close harness) run target proposal))

(defun harness-records (harness)
  "The recorded run-and-receipt pairs of the harness's in-memory store, or
NIL when a record callback was injected."
  (let ((store (%run-harness-records harness)))
    (and store (store-entries store))))

;;; Installed adapter wiring ------------------------------------------------

(defun default-evidence-ports ()
  "Evidence adapter over the installed read-only process transport."
  (hngh.adapters.evidence:make-evidence-ports
   :run-process #'hngh.adapters.evidence:process-run))

(defun default-mutation-ports ()
  "Mutation adapter over the installed read-only process transport. No
gather-evidence callback is supplied, so execute-run-mutation requires an
explicit fresh-evidence bundle and fails closed otherwise."
  (hngh.adapters.mutation:make-mutation-ports
   :run-process #'hngh.adapters.evidence:process-run))

(defun gather-run-evidence (ports command &key targets source-role)
  "Build the closed evidence request for COMMAND and gather it through PORTS."
  (hngh.adapters.evidence:gather-evidence
   (hngh.adapters.evidence:make-evidence-request
    :command command :targets targets :source-role source-role)
   ports))

(defun request-run-review (ports &key content-hash candidate-paths policy-context)
  "Build the closed review request and send it through PORTS."
  (hngh.adapters.review:request-review
   (hngh.adapters.review:make-review-request
    :content-hash content-hash
    :candidate-paths candidate-paths
    :policy-context policy-context)
   ports))

(defun execute-run-mutation (certificate fresh-evidence ports &key action)
  "Recheck CERTIFICATE against FRESH-EVIDENCE and execute through PORTS.
See hngh.adapters.mutation:execute-mutation for the closed contract."
  (hngh.adapters.mutation:execute-mutation
   certificate fresh-evidence ports :action action))

;;; Operator-visible root ----------------------------------------------------

(defun display (value)
  "Render VALUE to a plain factual string for an operator."
  (hngh.presentation:render value))
