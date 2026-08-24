(in-package #:hngh.main)

;;; Rung 7: composition root. MAIN is the only package that depends on
;;; presentation, the installed adapters, application, and domain together.
;;; It starts no background work and has zero side effects on load. The
;;; run harness composes the five application use cases over injected or
;;; default port adapters; the coordinator functions wire the installed
;;; evidence, review, and mutation adapters through injected transports;
;;; `display` renders any result through hngh.presentation. Default ports
;;; fail closed: no authority, verification, or manifest is invented here.
;;;
;;; Rung 8: operator command surface. DISPATCH-COMMAND is the closed,
;;; process-local entry point for scripts/hngh: it parses an argv list
;;; into one of the seven commands, routes --store=PATH to the installed
;;; filesystem adapter, and returns (values output exit-code). Exit codes:
;;; 0 accepted, 1 refused/conflict, 2 malformed (unknown command, arity,
;;; unknown option/transport/verb), 3 transport fault. The default
;;; admission facts consult the operator store's recorded receipts, so a
;;; run admits through the store and arms only on a matching :admission
;;; receipt; without a receipt arming fails closed.

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

(defun store-entries-of (store)
  "Entries of STORE regardless of backing: in-memory run stores keep
(cons run receipt) entries, filesystem stores keep plist lines."
  (if (typep store 'hngh.adapters.filesystem:filesystem-store)
      (hngh.adapters.filesystem:store-entries store)
      (store-entries store)))

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

(defun confirmed-admission-facts ()
  (hngh.application:make-admission-facts
   :authority :confirmed :ledger :confirmed :loadout :confirmed
   :exclusive-write :confirmed))

;;; list-valued vocabularies use DEFPARAMETER: DEFCONSTANT identity-checks
;;; values across loads and redefinitions even when textually identical
;;; (SB-EXT:DEFCONSTANT-UNEQL on SBCL). Closure is enforced by closed
;;; vocabularies in tests, not by the constant mechanism — see
;;; docs/records/2026-08-17-task-c2-failure-disposition.md.
(defparameter +state-chain+
  '(:created :armed :running :checkpointed :evacuated)
  "The run states in lifecycle order. Used to pick the newest recorded
line for a run and to rebuild a stored run's state.")

(defun default-admission-facts ()
  (hngh.application:make-admission-facts
   :authority :unknown :ledger :unknown :loadout :unknown
   :exclusive-write :unknown))

(defun entry-receipt (entry)
  "The receipt of a store entry: an in-memory (run . receipt) cons or a
filesystem plist line."
  (if (and (consp entry) (typep (cdr entry) 'hngh.domain:receipt))
      (cdr entry)
      (getf entry :receipt)))

(defun entry-receipt-kind (entry)
  (let ((receipt (entry-receipt entry)))
    (if (typep receipt 'hngh.domain:receipt)
        (hngh.domain:receipt-kind receipt)
        (getf receipt :kind))))

(defun entry-receipt-facts (entry)
  (let ((receipt (entry-receipt entry)))
    (if (typep receipt 'hngh.domain:receipt)
        (hngh.domain:receipt-facts receipt)
        (getf receipt :facts))))

(defun store-has-admission-receipt-p (store identifier)
  "True when STORE holds an :admission receipt naming IDENTIFIER. The
receipt carries the run fact from the admission use case, so a call to
admit-transport is what turns a run into an admitted run."
  (and store
       (let ((needle (format nil "run: ~A" identifier)))
         (and (find-if (lambda (entry)
                         (and (eq :admission (entry-receipt-kind entry))
                              (member needle (entry-receipt-facts entry)
                                      :test #'string=)))
                      (store-entries-of store))
              t))))

(defun default-admission-callback (&optional store)
  "Admission facts consult STORE's recorded receipts: a run with a
recorded :admission receipt naming it is :confirmed on all four axes;
anything else stays :unknown and arming refuses. STORE may be a
filesystem store or an in-memory run store."
  (lambda (run)
    (if (store-has-admission-receipt-p store (hngh.domain:run-identifier run))
        (confirmed-admission-facts)
        (default-admission-facts))))

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
                (create arm start checkpoint close admit records))
            (:conc-name %run-harness-))
  (create nil :read-only t)
  (arm nil :read-only t)
  (start nil :read-only t)
  (checkpoint nil :read-only t)
  (close nil :read-only t)
  (admit nil :read-only t)
  (records nil :read-only t))

(defun make-run-harness (&key next-identifier clock-now record-run admission-facts
                              tool-executor repository-inspector)
  "Compose the complete run lifecycle. Every key is an injected port
callback; omitted ones default to fail-closed or environment-free ports.
RECORD-RUN may be a callback (the refusals and records then live outside the
harness) or omitted to keep an in-memory store reachable via
HARNESS-RECORDS. ADMISSION-FACTS defaults to a store-consulting callback
over the harness's in-memory store."
  (multiple-value-bind (record records)
      (if record-run
          (values record-run nil)
          (default-record-callback))
    (let ((identifier-source (or next-identifier (default-identifier-source)))
          (clock (or clock-now (default-clock-callback)))
          (facts (or admission-facts (default-admission-callback records)))
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
       (lambda (run transport scope)
         (hngh.application:admit-transport
          (hngh.application:make-run-admission-ports
           :admission-facts facts
           :clock-now clock
           :record-run record)
          run transport scope))
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

(defun harness-admit-transport (harness run transport scope)
  (funcall (%run-harness-admit harness) run transport scope))

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

;;; Record serialization ----------------------------------------------------
;;; Domain structs have no print/read round-trip, so the operator store
;;; keeps canonical plist lines. MAIN owns the struct <-> plist mapping;
;;; the filesystem adapter validates only the line envelope.

(defun serialize-mission (mission)
  (list :objective (hngh.domain::%mission-objective mission)
        :non-objectives (copy-list (hngh.domain::%mission-non-objectives mission))
        :source-references (copy-list (hngh.domain::%mission-source-references mission))
        :acceptance-criteria (copy-list (hngh.domain::%mission-acceptance-criteria mission))
        :writable-scopes (copy-list (hngh.domain::%mission-writable-scopes mission))
        :verification (hngh.domain::%mission-verification mission)
        :evacuation-condition (hngh.domain::%mission-evacuation-condition mission)))

(defun serialize-role (role)
  (list :name (hngh.domain::%role-template-name role)
        :capabilities (copy-list (hngh.domain::%role-template-capabilities role))
        :required-review-role (hngh.domain::%role-template-required-review-role role)
        :permitted-loadout-classes
        (copy-list (hngh.domain::%role-template-permitted-loadout-classes role))))

(defun serialize-loadout (loadout)
  (list :route-label (hngh.domain::%loadout-route-label loadout)
        :context-limit (hngh.domain::%loadout-context-limit loadout)
        :token-limit (hngh.domain::%loadout-token-limit loadout)
        :cost-limit (hngh.domain::%loadout-cost-limit loadout)
        :time-limit (hngh.domain::%loadout-time-limit loadout)
        :tool-labels (copy-list (hngh.domain::%loadout-tool-labels loadout))
        :network-labels (copy-list (hngh.domain::%loadout-network-labels loadout))
        :writable-scopes (copy-list (hngh.domain::%loadout-writable-scopes loadout))))

(defun serialize-run (run)
  (list :identifier (hngh.domain:run-identifier run)
        :mission (serialize-mission (hngh.domain:run-mission run))
        :role (serialize-role (hngh.domain:run-role run))
        :loadout (serialize-loadout (hngh.domain:run-loadout run))
        :state (hngh.domain:run-state run)))

(defun serialize-receipt (receipt)
  (list :kind (hngh.domain:receipt-kind receipt)
        :facts (copy-list (hngh.domain:receipt-facts receipt))))

(defun rebuild-mission (plist)
  (hngh.domain:make-mission
   :objective (getf plist :objective)
   :non-objectives (getf plist :non-objectives)
   :source-references (getf plist :source-references)
   :acceptance-criteria (getf plist :acceptance-criteria)
   :writable-scopes (getf plist :writable-scopes)
   :verification (getf plist :verification)
   :evacuation-condition (getf plist :evacuation-condition)))

(defun rebuild-role (plist)
  (hngh.domain:make-role-template
   :name (getf plist :name)
   :capabilities (getf plist :capabilities)
   :required-review-role (getf plist :required-review-role)
   :permitted-loadout-classes (getf plist :permitted-loadout-classes)))

(defun rebuild-loadout (plist)
  (hngh.domain:make-loadout
   :route-label (getf plist :route-label)
   :context-limit (getf plist :context-limit)
   :token-limit (getf plist :token-limit)
   :cost-limit (getf plist :cost-limit)
   :time-limit (getf plist :time-limit)
   :tool-labels (getf plist :tool-labels)
   :network-labels (getf plist :network-labels)
   :writable-scopes (getf plist :writable-scopes)))

(defun rebuild-run (plist)
  "Reconstruct the run recorded in PLIST, at its recorded state."
  (let ((run (hngh.domain:make-run
              :identifier (getf plist :identifier)
              :mission (rebuild-mission (getf plist :mission))
              :role (rebuild-role (getf plist :role))
              :loadout (rebuild-loadout (getf plist :loadout)))))
    (if (eq :created (getf plist :state))
        run
        (dolist (step (cdr +state-chain+) run)
          (setf run (hngh.domain:advance-run run step))
          (when (eq step (getf plist :state))
            (return run))))))

(defun record-line-for (run receipt &key transport scope)
  "The canonical store line for recording RUN with RECEIPT."
  (let ((line (list :identifier (hngh.domain:run-identifier run)
                    :kind (hngh.domain:receipt-kind receipt)
                    :state (hngh.domain:run-state run)
                    :run (serialize-run run)
                    :receipt (serialize-receipt receipt))))
    (if transport
        (append line (list :transport transport :scope (or scope "repository")))
        line)))

;;; Operator command surface -------------------------------------------------

(defun command-usage ()
  (format nil "usage: hngh [--store=PATH] COMMAND [ARGS...]~%~
commands:~%~
  create-run OBJECTIVE ROLE [key=value...]  admit-transport RUN TRANSPORT [SCOPE]~%~
  arm-run RUN   start-run RUN~%~
  checkpoint RUN VERIFICATION MANIFEST   close-run RUN DISPOSITION~%~
  present [RUN]~%~
options: --store=PATH record the run ledger under PATH"))

(defun parse-option (argument)
  "Split ARGUMENT at the first = into (values KEYWORD VALUE); an argument
without = is (values NIL ARGUMENT). A leading -- is dropped so
--store=PATH names the :store option."
  (let ((eq (position #\= argument)))
    (if eq
        (let* ((raw (subseq argument 0 eq))
               (name (if (eql 0 (search "--" raw)) (subseq raw 2) raw)))
          (values (intern (string-upcase name) :keyword)
                  (subseq argument (1+ eq))))
        (values nil argument))))

(defun split-argv (args)
  "Separate operator ARGS into (values positionals store-path bad-option).
Only --prefixed arguments are global options: --store=PATH is consumed
here; any other -- argument is returned as BAD-OPTION. Command
key=value options pass through as positionals for the command parser."
  (let ((positionals '()) (store nil) (bad nil))
    (dolist (arg args)
      (if (eql 0 (search "--" arg))
          (multiple-value-bind (key value) (parse-option arg)
            (if (eq key :store)
                (setf store value)
                (setf bad (or bad arg))))
          (push arg positionals)))
    (values (nreverse positionals) store bad)))

(defun make-record-run (store)
  (lambda (run receipt)
    (hngh.adapters.filesystem:store-record-run
     store (record-line-for run receipt))))

(defun make-admission-record-run (store transport scope)
  (lambda (run receipt)
    (hngh.adapters.filesystem:store-record-run
     store (record-line-for run receipt
                            :transport transport :scope scope))))

(defun admission-facts-callback (store)
  (if store
      (default-admission-callback store)
      (default-admission-callback)))

(defun run-from-store (store identifier)
  "The newest recorded run for IDENTIFIER, rebuilt from STORE's lines."
  (when store
    (let ((best nil) (best-rank -1))
      (dolist (line (hngh.adapters.filesystem:store-entries store))
        (when (string= identifier (getf line :identifier))
          (let ((rank (position (getf line :state) +state-chain+)))
            (when (> rank best-rank)
              (setf best line best-rank rank)))))
      (and best (rebuild-run (getf best :run))))))

(defun result-output (result)
  "Map an application result to (values output exit-code): 0 accepted,
1 conflict or refusal, 2 malformed (unknown transport)."
  (case (hngh.application:application-result-status result)
    (:accepted (values (display result) 0))
    (:conflict (values (display result) 1))
    (:refused
     (values (display result)
             (if (member "unknown-transport"
                         (hngh.application:application-result-labels result)
                         :test #'string=)
                 2 1)))))

(defun missing-run-output (identifier)
  (values (format nil "no such run: ~A" identifier) 1))

(defun split-label-value (value)
  (let ((parts (uiop:split-string value :separator "/")))
    (if (some #'uiop:emptyp parts) nil parts)))

(defun parse-label-option (options key)
  (let ((value (getf options key)))
    (and value (split-label-value value))))

(defun parse-limit-option (options key)
  (let ((value (getf options key)))
    (and value (parse-integer value :junk-allowed nil))))

(defun parse-keyword-option (options key)
  (let ((value (getf options key)))
    (and value (intern (string-upcase value) :keyword))))

(defun mission-from-options (objective options)
  (hngh.domain:make-mission
   :objective (or (getf options :mission-objective) objective)
   :non-objectives (or (parse-label-option options :mission-non-objectives)
                       '("none"))
   :source-references (or (parse-label-option options :mission-source-references)
                          '("none"))
   :acceptance-criteria (or (parse-label-option options :mission-acceptance-criteria)
                            '("none"))
   :writable-scopes (or (parse-label-option options :mission-writable-scopes)
                        '("repository"))
   :verification (or (getf options :mission-verification) "verified")
   :evacuation-condition (or (getf options :mission-evacuation-condition)
                             "evacuated")))

(defun role-from-options (name options)
  (hngh.domain:make-role-template
   :name (or (getf options :role-name) name)
   :capabilities (or (parse-label-option options :role-capabilities) '("none"))
   :required-review-role (or (getf options :role-required-review-role) name)
   :permitted-loadout-classes
   (or (parse-label-option options :role-permitted-loadout-classes) '("none"))))

(defparameter +loadout-option-keys+
  '(:loadout-route-label :loadout-context-limit :loadout-token-limit
    :loadout-cost-limit :loadout-time-limit :loadout-tool-labels
    :loadout-network-labels :loadout-writable-scopes))

(defparameter +create-option-keys+
  (append '(:mission-objective :mission-non-objectives
            :mission-source-references :mission-acceptance-criteria
            :mission-writable-scopes :mission-verification
            :mission-evacuation-condition :role-name :role-capabilities
            :role-required-review-role :role-permitted-loadout-classes)
          +loadout-option-keys+))

(defun loadout-from-options (options)
  (hngh.domain:make-loadout
   :route-label (parse-keyword-option options :loadout-route-label)
   :context-limit (parse-limit-option options :loadout-context-limit)
   :token-limit (parse-limit-option options :loadout-token-limit)
   :cost-limit (parse-limit-option options :loadout-cost-limit)
   :time-limit (parse-limit-option options :loadout-time-limit)
   :tool-labels (or (parse-label-option options :loadout-tool-labels)
                    '("none"))
   :network-labels (or (parse-label-option options :loadout-network-labels)
                       '("none"))
   :writable-scopes (or (parse-label-option options :loadout-writable-scopes)
                        '("repository"))))

(defun collect-options (args)
  "ARGS after the command's positionals: (values positionals options-alist).
A key=value argument is an option; anything else is a positional."
  (let ((positionals '()) (options '()))
    (dolist (arg args)
      (if (find #\= arg)
          (multiple-value-bind (key value) (parse-option arg)
            (push (cons key value) options))
          (push arg positionals)))
    (values (nreverse positionals) (nreverse options))))

(defun options-plist (options)
  (apply #'append (mapcar (lambda (pair)
                            (list (car pair) (cdr pair)))
                          options)))

(defun dispatch-create-run (args store clock)
  (multiple-value-bind (positionals options) (collect-options args)
    (unless (= 2 (length positionals))
      (return-from dispatch-create-run
        (values (format nil "create-run needs an objective and a role~%~A"
                        (command-usage))
                2)))
    (when (find-if (lambda (pair)
                     (not (member (car pair) +create-option-keys+)))
                   options)
      (return-from dispatch-create-run
        (values (format nil "unknown create-run key~%~A" (command-usage)) 2)))
    (handler-case
        (let* ((mission (mission-from-options (first positionals)
                                              (options-plist options)))
               (role (role-from-options (second positionals)
                                        (options-plist options)))
               (loadout (loadout-from-options (options-plist options)))
               (harness (if store
                            (make-run-harness :clock-now clock
                                              :record-run (make-record-run store))
                            (make-run-harness :clock-now clock)))
               (result (harness-create-run harness mission role loadout)))
          (result-output result))
      (error (condition)
        (values (format nil "malformed create-run: ~A" condition) 2)))))

(defun dispatch-admit-transport (args store clock)
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (< (length positionals) 2) (> (length positionals) 3))
      (return-from dispatch-admit-transport
        (values (if options
                    (format nil "unknown option: ~A~%~A"
                            (cdar options) (command-usage))
                    (command-usage))
                2)))
    (let* ((identifier (first positionals))
           (transport (intern (string-upcase (second positionals)) :keyword))
           (scope (third positionals))
           (run (run-from-store store identifier)))
      (unless run
        (return-from dispatch-admit-transport
          (missing-run-output identifier)))
      (let* ((harness (make-run-harness
                       :clock-now clock
                       :record-run (if store
                                       (make-admission-record-run
                                        store (second positionals) scope)
                                       nil)))
             (result (harness-admit-transport harness run transport scope)))
        (result-output result)))))

(defun dispatch-arm-run (args store clock)
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (not (= 1 (length positionals))))
      (return-from dispatch-arm-run (values (command-usage) 2)))
    (let* ((identifier (first positionals))
           (run (run-from-store store identifier)))
      (unless run
        (return-from dispatch-arm-run (missing-run-output identifier)))
      (let* ((harness (make-run-harness
                       :clock-now clock
                       :record-run (and store (make-record-run store))
                       :admission-facts (admission-facts-callback store)))
             (result (harness-arm-run harness run)))
        (result-output result)))))

(defun dispatch-start-run (args store clock)
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (not (= 1 (length positionals))))
      (return-from dispatch-start-run (values (command-usage) 2)))
    (let* ((identifier (first positionals))
           (run (run-from-store store identifier)))
      (unless run
        (return-from dispatch-start-run (missing-run-output identifier)))
      (let* ((harness (make-run-harness
                       :clock-now clock
                       :record-run (and store (make-record-run store))))
             (result (harness-start-run harness run)))
        (result-output result)))))

(defun verification-result-for (verb)
  (cond
    ((string= verb "passed")
     (hngh.application:make-verification-result
      :status :passed :labels '("verification-passed")))
    ((string= verb "failed")
     (hngh.application:make-verification-result
      :status :failed :labels '("verification-failed")))
    (t nil)))

(defun manifest-result-for (verb)
  (cond
    ((string= verb "complete")
     (hngh.application:make-manifest-result
      :status :complete :labels '("manifest-complete")))
    ((string= verb "incomplete")
     (hngh.application:make-manifest-result
      :status :incomplete :labels '("manifest-incomplete")))
    (t nil)))

(defun dispatch-checkpoint (args store clock)
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (not (= 3 (length positionals))))
      (return-from dispatch-checkpoint (values (command-usage) 2)))
    (let ((verification (verification-result-for (second positionals)))
          (manifest (manifest-result-for (third positionals))))
      (unless (and verification manifest)
        (return-from dispatch-checkpoint
          (values (format nil "checkpoint verbs: VERIFICATION passed|failed, MANIFEST complete|incomplete~%~A"
                          (command-usage))
                  2)))
      (let* ((identifier (first positionals))
             (run (run-from-store store identifier)))
        (unless run
          (return-from dispatch-checkpoint (missing-run-output identifier)))
        (let* ((harness (make-run-harness
                         :clock-now clock
                         :record-run (and store (make-record-run store))
                         :tool-executor (lambda (request)
                                          (declare (ignore request))
                                          verification)
                         :repository-inspector (lambda (request)
                                                 (declare (ignore request))
                                                 manifest)))
               (result (harness-checkpoint harness run)))
          (result-output result))))))

(defun close-proposal ()
  "The deterministic policy proposal behind the close-run surface: every
matrix principle carries one current fixture-tagged evidence requirement,
so the verdict is :admitted and the close advances."
  (hngh.domain:make-policy-proposal
   :class :feature
   :problem "operator close" :outcome "terminal state"
   :purpose "close the run" :caller "operator"
   :input-contract "run" :output-contract "state"
   :failure-contract "refusal" :declared-capabilities '("close-run")
   :capability-diff "none"
   :source-manifest (list (hngh.domain:make-source-manifest-entry
                           :relative-path "operator-close.md"
                           :content-hash "operator-close"
                           :source-role "surface"))
   :risk-note "none" :dependency "domain" :evidence-trigger "operator"
   :evidence-requirements
   (mapcar (lambda (principle)
             (hngh.domain:make-evidence-requirement
              :principle principle
              :kind (if (member principle '(:purpose :caller))
                        :purpose :claim-proof)
              :required-fingerprints '("operator-close")
              :evidence-facts
              (list (hngh.domain:make-evidence-fact
                     :kind :fixture :fingerprint "operator-close"
                     :state :current))))
           hngh.domain::+matrix-principles+)))

(defun close-target-for (disposition)
  (cond
    ((string= disposition "cancelled") :cancelled)
    ((string= disposition "evacuated") :evacuated)
    ((string= disposition "dead") :dead)
    (t nil)))

(defun dispatch-close-run (args store clock)
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (not (= 2 (length positionals))))
      (return-from dispatch-close-run (values (command-usage) 2)))
    (let ((target (close-target-for (second positionals))))
      (unless target
        (return-from dispatch-close-run
          (values (format nil "close-run disposition: cancelled|evacuated|dead~%~A"
                          (command-usage))
                  2)))
      (let* ((identifier (first positionals))
             (run (run-from-store store identifier)))
        (unless run
          (return-from dispatch-close-run (missing-run-output identifier)))
        (let* ((harness (make-run-harness
                         :clock-now clock
                         :record-run (and store (make-record-run store))))
               (result (harness-close-run harness run target
                                          (close-proposal))))
          (result-output result))))))

(defun dispatch-present (args store clock)
  (declare (ignore clock))
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (> (length positionals) 1))
      (return-from dispatch-present (values (command-usage) 2)))
    (cond
      ((null store) (values "no store: create the run ledger with --store=PATH" 1))
      ((null positionals)
       (let ((identifiers
               (remove-duplicates
                (mapcar (lambda (line) (getf line :identifier))
                        (hngh.adapters.filesystem:store-entries store))
                :test #'string=)))
         (values (format nil "recorded runs: ~{~A~^, ~}" identifiers) 0)))
      (t (let ((run (run-from-store store (first positionals))))
           (if run
               (values (display run) 0)
               (missing-run-output (first positionals))))))))

(defun dispatch-command* (positionals store clock)
  (let ((command (first positionals))
        (args (rest positionals)))
    (cond
      ((null command) (values (command-usage) 2))
      ((string= command "create-run") (dispatch-create-run args store clock))
      ((string= command "admit-transport")
       (dispatch-admit-transport args store clock))
      ((string= command "arm-run") (dispatch-arm-run args store clock))
      ((string= command "start-run") (dispatch-start-run args store clock))
      ((string= command "checkpoint") (dispatch-checkpoint args store clock))
      ((string= command "close-run") (dispatch-close-run args store clock))
      ((string= command "present") (dispatch-present args store clock))
      (t (values (format nil "unknown command: ~A~%~A" command (command-usage))
                 2)))))

(defun dispatch-command (argv &key clock-now)
  "Parse the operator ARGV list, execute the named command, and return
(values output-string exit-code). Exit codes: 0 accepted; 1 refused or
conflict; 2 malformed invocation (unknown command, wrong arity, unknown
option, transport, or verb); 3 transport fault. CLOCK-NOW may inject a
timestamp callback for deterministic tests."
  (multiple-value-bind (positionals store bad-option)
      (split-argv argv)
    (when bad-option
      (return-from dispatch-command
        (values (format nil "unknown option: ~A~%~A" bad-option (command-usage))
                2)))
    (let ((clock (or clock-now (default-clock-callback))))
      (if store
          (handler-case
              (dispatch-command* positionals
                                 (hngh.adapters.filesystem:make-filesystem-store
                                  :root store)
                                 clock)
            (hngh.adapters.filesystem:transport-fault (condition)
              (values (format nil "transport fault: ~A" condition) 3))
            (hngh.adapters.filesystem:store-refusal (condition)
              (values (format nil "store refusal: ~A" condition) 2)))
          (dispatch-command* positionals nil clock)))))

;;; Operator-visible root ----------------------------------------------------

(defun display (value)
  "Render VALUE to a plain factual string for an operator."
  (hngh.presentation:render value))