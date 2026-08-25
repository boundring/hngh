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

(defun store-has-transport-admission-receipt-p (store identifier transport)
  "True when STORE holds an :admission receipt naming IDENTIFIER for the
given TRANSPORT kind (its receipt carries the transport fact from the
admission use case). A run admitted for :filesystem does not admit :model
or :terminal capture."
  (and store
       (let ((needle-run (format nil "run: ~A" identifier))
             (needle-transport
               (format nil "transport: ~A"
                       (string-downcase (symbol-name transport)))))
         (and (find-if (lambda (entry)
                         (and (eq :admission (entry-receipt-kind entry))
                              (member needle-run (entry-receipt-facts entry)
                                      :test #'string=)
                              (member needle-transport
                                      (entry-receipt-facts entry)
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

(defun gather-federated-evidence (ports &key peer method time-window
                                        max-facts)
  "Build the closed federation request and gather remote evidence through
PORTS. PORTS must be a federation-ports object; no default exists, so a
run without an admitted and composed federation transport is refused
upstream before this is reached."
  (hngh.adapters.federation:gather-federated-evidence
   (hngh.adapters.federation:make-federation-request
    :peer peer :method (or method :carrier-bundle)
    :time-window time-window :max-facts max-facts)
   ports))

(defun verify-remote-attestation (ports attestation now)
  "Verify a parsed REMOTE-ATTESTATION envelope through PORTS against the
injected NOW timestamp. No default attestation ports exist; without an
injected object the operator surface refuses no-attestation-transport."
  (hngh.adapters.federation:verify-remote-attestation
   attestation now ports))

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
  "Reconstruct the run recorded in PLIST, at its recorded state. Walks
the domain's linear run-state chain, but skips the :cancelled sibling
branch when rebuilding :evacuated or :dead (a run reaches those from
:running/:checkpointed directly, never through :cancelled)."
  (let* ((recorded (getf plist :state))
         (run (hngh.domain:make-run
              :identifier (getf plist :identifier)
              :mission (rebuild-mission (getf plist :mission))
              :role (rebuild-role (getf plist :role))
              :loadout (rebuild-loadout (getf plist :loadout)))))
    (if (eq :created recorded)
        run
        ;; advance the linear progression (states before the terminal
        ;; siblings), stopping at the recorded non-terminal state, then
        ;; jump directly to the recorded terminal.
        (let ((progressed
                (dolist (step '(:armed :running :checkpointed) run)
                  (setf run (hngh.domain:advance-run run step))
                  (when (eq step recorded)
                    (return run)))))
          (if (member recorded '(:cancelled :evacuated :dead))
              (hngh.domain:advance-run progressed recorded)
              progressed)))))

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
  propose [key=value...]  issue-cert ACTION RUN VERDICT-FILE [PATH...]~%~
  mutation-check ACTION RUN [VERDICT-FILE] [EVIDENCE...]  present [RUN]~%~
  review RUN content-hash=HASH paths=PATH,... [reviewer=PATH]  terminal RUN~%~
  fetch-evidence RUN peer=ID [max-facts=N]  verify-attestation RUN FILE [pins=PATH]~%~
  list-pins PATH~%~
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
  "The newest recorded run for IDENTIFIER, rebuilt from STORE's lines.
Ranking uses the domain's run-state order (the single source of truth),
so terminal states like :cancelled and :dead outrank any non-terminal
line for the same run."
  (when store
    (let ((best nil) (best-rank -1))
      (dolist (line (hngh.adapters.filesystem:store-entries store))
        (when (string= identifier (getf line :identifier))
          (let ((rank (position (getf line :state)
                                hngh.domain::+run-states+)))
            (when (and rank (> rank best-rank))
              (setf best line best-rank rank)))))
      (and best (rebuild-run (getf best :run))))))

(defun result-output (result)
  "Map an application result to (values output exit-code): 0 accepted,
1 conflict or refusal, 2 malformed (unknown transport)."
  (case (hngh.application:application-result-status result)
    (:accepted (values (hngh.presentation:render result) 0))
    (:conflict (values (hngh.presentation:render result) 1))
    (:refused
     (values (hngh.presentation:render result)
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
               (values (hngh.presentation:render run) 0)
               (missing-run-output (first positionals))))))))

;;; Bounded worker transport commands -----------------------------------------
;;; Rung 10: review and terminal capture. The review command sends a closed
;;; model-review request through the injected review ports (no default
;;; provider: without :review-ports it refuses no-review-transport) and is
;;; served only to a run holding a :model admission receipt. The terminal
;;; command captures one operator statement through the injected operator
;;; ports (no default input: without :terminal-ports it refuses
;;; no-terminal-transport) and serves only a run holding a :terminal
;;; admission receipt. Neither command ever spawns a subprocess when the
;;; injected ports are fakes: the terminal digest is computed in-process.
;;; Exit codes match the operator surface: 0 complete/captured, 1 refused
;;; (not admitted, missing transport, closed refusal), 2 malformed
;;; invocation, 3 transport fault.

(defparameter +review-option-keys+
  '(:content-hash :paths :policy-context :reviewer))

(defun report-review-result (result)
  "Map a REVIEW-RESULT to (values output exit-code): 0 complete, 1 refused,
3 transport fault."
  (case (hngh.adapters.review:review-result-status result)
    (:complete (values (hngh.presentation:render result) 0))
    (:refused
     (values (hngh.presentation:render result)
             (if (member "transport-fault"
                         (hngh.adapters.review:review-result-refusal-labels
                          result)
                         :test #'string=)
                 3 1)))))

(defparameter +reviewer-config-keys+
  '(:endpoint :model :max-tokens :timeout :token-file)
  "The closed reviewer-transport file vocabulary.")

(defun parse-reviewer-config (text)
  "Strict-parse operator reviewer-transport text: KEY=VALUE lines over the
five closed keys, `#` comments and blank lines skipped; unknown, duplicate,
missing, empty, or non-integer fields refuse. Returns a plist."
  (unless (stringp text)
    (error "reviewer config must be text"))
  (let ((plist '())
        (seen '()))
    (dolist (line (uiop:split-string text :separator '(#\Newline)))
      (let ((line (string-right-trim '(#\Return) line)))
        (unless (or (uiop:emptyp line) (char= (char line 0) #\#))
          (let ((eq (position #\= line)))
            (unless eq
              (error "malformed reviewer line: ~S" line))
            (let* ((key-text (subseq line 0 eq))
                   (key (intern (string-upcase key-text) :keyword))
                   (value (subseq line (1+ eq))))
              (unless (member key +reviewer-config-keys+)
                (error "unknown reviewer key: ~A" key-text))
              (when (member key seen)
                (error "duplicate reviewer key: ~A" key-text))
              (unless (plusp (length value))
                (error "empty reviewer value: ~A" key-text))
              (push key seen)
              (push value plist)
              (push key plist))))))
    (dolist (key +reviewer-config-keys+)
      (unless (member key seen)
        (error "missing reviewer key: ~A"
               (string-downcase (symbol-name key)))))
    (dolist (key '(:max-tokens :timeout))
      (setf (getf plist key) (parse-integer (getf plist key))))
    plist))

(defun read-reviewer-file (path)
  "Read and strict-parse an operator reviewer-transport file, then read the
provider token from its named token-file. Returns (values ports nil) or
(values nil refusal-text). The token reaches only the one curl
Authorization header (see MAKE-MODEL-TRANSPORTS); it never enters the
prompt, a result, or the store."
  (handler-case
      (let* ((config (parse-reviewer-config (uiop:read-file-string path)))
             (token (string-trim '(#\Newline #\Return #\Space #\Tab)
                                 (uiop:read-file-string
                                  (getf config :token-file)))))
        (unless (plusp (length token))
          (error "empty provider token"))
        (values
         (hngh.adapters.review:make-review-ports
          :invoke-reviewer
          (hngh.adapters.model:make-model-transports
           :endpoint (getf config :endpoint)
           :model-name (getf config :model)
           :max-tokens (getf config :max-tokens)
           :timeout (getf config :timeout)
           :provider-token token))
         nil))
    (file-error () (values nil "cannot read reviewer file"))
    (error () (values nil "malformed reviewer file"))))

(defun dispatch-review (args store clock review-ports)
  (declare (ignore clock))
  (multiple-value-bind (positionals options) (collect-options args)
    (let ((unknown (find-if (lambda (pair)
                              (not (member (car pair) +review-option-keys+)))
                            options)))
      (when unknown
        (return-from dispatch-review
          (values (format nil "unknown review key: ~A~%~A"
                          (cdr unknown) (command-usage))
                  2)))
    (unless (= 1 (length positionals))
      (return-from dispatch-review (values (command-usage) 2)))
    ;; The operator reviewer file is the transport admission: when present
    ;; it replaces any injected review ports with the real curl-backed
    ;; provider transport from the operator's config.
    (let* ((reviewer-path (cdr (assoc :reviewer options)))
           (ports
             (if reviewer-path
                 (multiple-value-bind (reviewer-ports refusal)
                     (read-reviewer-file reviewer-path)
                   (when refusal
                     (return-from dispatch-review
                       (values (format nil "review refused: ~A" refusal)
                               2)))
                   reviewer-ports)
                 review-ports))
           (identifier (first positionals))
           (run (run-from-store store identifier)))
      (unless run
        (return-from dispatch-review (missing-run-output identifier)))
      (unless (store-has-transport-admission-receipt-p store identifier
                                                       :model)
        (return-from dispatch-review
          (values (format nil "review refused: run ~A not admitted for model"
                          identifier)
                  1)))
      (unless ports
        (return-from dispatch-review
          (values "review refused: no-review-transport" 1)))
      (handler-case
          (let* ((plist (options-plist options))
                 (result (request-run-review
                          ports
                          :content-hash (getf plist :content-hash)
                          :candidate-paths
                          (parse-comma-labels (getf plist :paths))
                          :policy-context
                          (or (parse-comma-labels
                               (getf plist :policy-context))
                              (list "operator")))))
            (report-review-result result))
        (error (condition)
          (values (format nil "malformed review: ~A" condition) 2)))))))

(defun report-operator-result (result)
  "Map an OPERATOR-RESULT to (values output exit-code): 0 captured, 1
refused, 3 transport fault."
  (case (hngh.adapters.terminal:operator-result-status result)
    (:complete (values (hngh.presentation:render result) 0))
    (:refused
     (values (hngh.presentation:render result)
             (if (member "transport-fault"
                         (hngh.adapters.terminal:operator-result-refusal-labels
                          result)
                         :test #'string=)
                 3 1)))))

(defun dispatch-terminal (args store clock terminal-ports)
  (declare (ignore clock))
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (not (= 1 (length positionals))))
      (return-from dispatch-terminal (values (command-usage) 2)))
    (let* ((identifier (first positionals))
           (run (run-from-store store identifier)))
      (unless run
        (return-from dispatch-terminal (missing-run-output identifier)))
      (unless (store-has-transport-admission-receipt-p store identifier
                                                       :terminal)
        (return-from dispatch-terminal
          (values (format nil "terminal refused: run ~A not admitted for terminal"
                          identifier)
                  1)))
      (unless terminal-ports
        (return-from dispatch-terminal
          (values "terminal refused: no-terminal-transport" 1)))
      (handler-case
          (report-operator-result
           (hngh.adapters.terminal:capture-operator-statement terminal-ports))
        (error (condition)
          (values (format nil "malformed terminal: ~A" condition) 2))))))

;;; Governance command surface ----------------------------------------------
;;; The in-process dogfood loop for an operator: propose forms a closed
;;; policy proposal from operator fields, issue-cert binds a stored run
;;; and mints a candidate certificate under an admitted verdict, and
;;; mutation-check replays the mutation against fresh fixture evidence
;;; through injected mutation ports. No subprocess is ever spawned by
;;; these commands: mutation-check runs against the injected ports object.
;;; Exit codes match the operator surface: 0 admitted/executed, 1 refused
;;; or mismatched, 2 malformed invocation, 3 transport fault.

(defparameter +propose-option-keys+
  '(:class :problem :outcome :purpose :caller
    :input-contract :output-contract :failure-contract
    :declared-capabilities :capability-diff :source-manifest
    :risk-note :dependency :evidence-trigger :evidence-requirements))

(defun parse-comma-labels (value)
  (let ((parts (uiop:split-string value :separator ",")))
    (if (some #'uiop:emptyp parts) nil parts)))

(defun parse-dogfood-manifest (value)
  "PATH=HASH:ROLE"
  (let ((eq (position #\= value)))
    (unless eq
      (error "source-manifest must be PATH=HASH:ROLE"))
    (let* ((path (subseq value 0 eq))
           (hash-role (subseq value (1+ eq)))
           (colon (position #\: hash-role)))
      (unless colon
        (error "source-manifest must be PATH=HASH:ROLE"))
      (list (hngh.domain:make-source-manifest-entry
             :relative-path path
             :content-hash (subseq hash-role 0 colon)
             :source-role (subseq hash-role (1+ colon)))))))

(defun parse-evidence-requirement (value)
  "PRINCIPLE:KIND:FINGERPRINTS"
  (let ((parts (uiop:split-string value :separator ":")))
    (unless (= 3 (length parts))
      (error "evidence-requirements must be PRINCIPLE:KIND:FINGERPRINTS"))
    (destructuring-bind (principle kind fingerprints) parts
      (let ((fingerprints (remove-if #'uiop:emptyp
                                     (uiop:split-string fingerprints
                                                       :separator ","))))
        (unless fingerprints
          (error "evidence-requirements must name a fingerprint"))
        (hngh.domain:make-evidence-requirement
         :principle (intern (string-upcase principle) :keyword)
         :kind (intern (string-upcase kind) :keyword)
         :required-fingerprints fingerprints
         :evidence-facts
         (mapcar (lambda (fingerprint)
                   (hngh.domain:make-evidence-fact
                    :kind :fixture :fingerprint fingerprint :state :current))
                 fingerprints))))))

(defun dogfood-verdict ()
  "The deterministic admitted verdict behind the certificate surface: every
matrix principle carries one current fixture-tagged evidence requirement,
so the verdict is :admitted."
  (hngh.domain:evaluate-policy-proposal
   (hngh.domain:make-policy-proposal
    :class :feature
    :problem "operator dogfood" :outcome "governed mutation"
    :purpose "exercise the surface" :caller "operator"
    :input-contract "run" :output-contract "certificate"
    :failure-contract "refusal" :declared-capabilities '("mutation")
    :capability-diff "none"
    :source-manifest (list (hngh.domain:make-source-manifest-entry
                            :relative-path "operator.md"
                            :content-hash "operator"
                            :source-role "surface"))
    :risk-note "none" :dependency "domain" :evidence-trigger "operator"
    :evidence-requirements
    (mapcar (lambda (principle)
              (hngh.domain:make-evidence-requirement
               :principle principle
               :kind (if (member principle '(:purpose :caller))
                         :purpose :claim-proof)
               :required-fingerprints '("operator")
               :evidence-facts
               (list (hngh.domain:make-evidence-fact
                      :kind :fixture :fingerprint "operator"
                      :state :current))))
            hngh.domain::+matrix-principles+))))

(defun dogfood-payload (identifier action)
  "Shared fresh facts for the certificate and its fresh evidence."
  (declare (ignore identifier))
  (let ((content-hash (format nil "dogfood-~(~A~)" action)))
    (values content-hash
            (list content-hash)
            (list (hngh.domain:make-source-manifest-entry
                   :relative-path "operator.md"
                   :content-hash content-hash
                   :source-role "surface")))))

(defun dogfood-certificate (store identifier action paths)
  "Mint the candidate certificate for the dogfood loop: repository
identity comes from STORE's root name, the base revision from the
IDENTIFIER, candidate paths from PATHS."
  (let ((root-directory
          (hngh.adapters.filesystem::filesystem-store-root-directory store))
        (content-hash (format nil "dogfood-~(~A~)" action)))
    (hngh.domain:issue-candidate-certificate
     (dogfood-verdict)
     :action action
     :repository-identity
     (car (last (pathname-directory
                 (uiop:ensure-directory-pathname root-directory))))
     :base-revision identifier
     :candidate-paths paths
     :content-hash content-hash
     :evidence-hashes (list content-hash)
     :review-findings '()
     :source-manifest (list (hngh.domain:make-source-manifest-entry
                             :relative-path "operator.md"
                             :content-hash content-hash
                             :source-role "surface"))
     :policy-profile "dogfood"
     :expiry "2026-08-25T00:00:00Z")))

(defun dispatch-propose (args store clock)
  (declare (ignore store clock))
  (multiple-value-bind (positionals options) (collect-options args)
    (when positionals
      (return-from dispatch-propose
        (values (format nil "propose takes key=value pieces only~%~A"
                        (command-usage))
                2)))
    (let ((unknown (find-if (lambda (pair)
                              (not (member (car pair) +propose-option-keys+)))
                            options)))
      (when unknown
        (return-from dispatch-propose
          (values (format nil "unknown propose key: ~A~%~A"
                          (cdr unknown) (command-usage))
                  2))))
    (handler-case
        (let* ((plist (options-plist options))
               (requirements
                 (mapcar #'parse-evidence-requirement
                         (mapcar #'cdr
                                 (remove-if-not
                                  (lambda (pair)
                                    (eq :evidence-requirements (car pair)))
                                  options))))
               (proposal (hngh.domain:make-policy-proposal
                          :class (intern (string-upcase (getf plist :class))
                                         :keyword)
                          :problem (getf plist :problem)
                          :outcome (getf plist :outcome)
                          :purpose (getf plist :purpose)
                          :caller (getf plist :caller)
                          :input-contract (getf plist :input-contract)
                          :output-contract (getf plist :output-contract)
                          :failure-contract (getf plist :failure-contract)
                          :declared-capabilities
                          (parse-comma-labels (getf plist :declared-capabilities))
                          :capability-diff (getf plist :capability-diff)
                          :source-manifest
                          (parse-dogfood-manifest (getf plist :source-manifest))
                          :risk-note (getf plist :risk-note)
                          :dependency (getf plist :dependency)
                          :evidence-trigger (getf plist :evidence-trigger)
                          :evidence-requirements requirements))
               (verdict (hngh.domain:evaluate-policy-proposal proposal)))
          (if (eq :admitted (hngh.domain:policy-verdict-state verdict))
              (values (hngh.presentation:render verdict) 0)
              (values (hngh.presentation:render verdict) 1)))
      (error (condition)
        (values (format nil "malformed propose: ~A~%~A" condition (command-usage))
                2)))))

(defun real-run-evidence (candidate-paths cwd gather-ports)
  "Genuine candidate evidence: runs scripts/verify-candidate.py in
CWD through the injected or default process transport and completes
repository identity and per-file content hashes. Returns (values
evidence nil) or (values nil refusal-label); fails closed."
  (hngh.adapters.run-gather:run-candidate-evidence
   candidate-paths cwd gather-ports))

(defun parse-verdict-report (text)
  "Strict closed parser for a rendered policy verdict (as emitted by
hngh.presentation:render): a verdict header, one line per principle
result, then a reasons line. Any deviation yields (values nil
\"malformed-verdict-evidence\")."
  (handler-case
      (let* ((lines (remove-if (lambda (line)
                                 (uiop:emptyp (string-trim
                                               '(#\Space #\Tab) line)))
                               (uiop:split-string (or text "")
                                                  :separator '(#\Newline))))
             (head (first lines)))
        (unless (and lines head)
          (return-from parse-verdict-report
            (values nil "malformed-verdict-evidence")))
        (let* ((tokens (uiop:split-string (string-trim '(#\Space #\Tab) head)
                                          :separator '(#\Space)))
               (state (and (= 3 (length tokens))
                           (string= "verdict" (first tokens))
                           (string= "state=" (second tokens) :end2 6)
                           (intern (string-upcase (subseq (second tokens) 6))
                                   :keyword)))
               (count-text (and (= 3 (length tokens))
                                (string= "principles=" (third tokens) :end2 11)
                                (subseq (third tokens) 11)))
               (count (and count-text
                           (every #'digit-char-p count-text)
                           (parse-integer count-text))))
          (unless (and state
                       (member state '(:admitted :refused :needs-escalation))
                       count (plusp count))
            (return-from parse-verdict-report
              (values nil "malformed-verdict-evidence")))
          (let ((principle-lines (butlast (rest lines)))
                (reasons-line (car (last lines))))
            (unless (and (string= "reasons=" reasons-line :end2 8)
                         (= (length principle-lines) count))
              (return-from parse-verdict-report
                (values nil "malformed-verdict-evidence")))
            (let ((results '()))
              (dolist (line principle-lines)
                (let* ((trimmed (string-trim '(#\Space #\Tab) line))
                       (state-at (search " state=" trimmed))
                       (name (and state-at
                                  (subseq trimmed (length "principle ") state-at)))
                       (suffix (and state-at
                                    (subseq trimmed (+ state-at (length " state="))))))
                  (unless (and state-at
                               (string= trimmed "principle "
                                        :end1 (length "principle ")
                                        :end2 (length "principle "))
                               name (plusp (length name))
                               suffix (plusp (length suffix))
                               (not (position #\Space suffix)))
                    (return-from parse-verdict-report
                      (values nil "malformed-verdict-evidence")))
                  (push (hngh.domain:make-principle-result
                         :principle (intern (string-upcase name) :keyword)
                         :state (intern (string-upcase suffix) :keyword)
                         :evidence-fingerprints '())
                        results)))
              (let* ((reasons-text (subseq reasons-line (length "reasons=")))
                     (reason-labels
                       (if (or (zerop (length (string-trim '(#\Space #\Tab)
                                                            reasons-text)))
                               (string-equal (string-trim '(#\Space #\Tab)
                                                          reasons-text)
                                             "none"))
                           '()
                           (mapcar (lambda (label)
                                     (string-trim '(#\Space #\Tab) label))
                                   (uiop:split-string reasons-text
                                                      :separator '(#\;))))))
                (values (hngh.domain:make-policy-verdict
                         :state state
                         :principle-results (nreverse results)
                         :reason-labels reason-labels)
                        nil))))))
    (error ()
      (values nil "malformed-verdict-evidence"))))

(defun read-verdict-report (path)
  "Read and parse the operator-produced verdict report at PATH.
Returns (values verdict nil), (values nil \"missing-verdict-file\"),
or (values nil \"malformed-verdict-evidence\")."
  (handler-case
      (progn
        (unless (probe-file path)
          (return-from read-verdict-report
            (values nil "missing-verdict-file")))
        (parse-verdict-report (uiop:read-file-string path)))
    (error ()
      (values nil "malformed-verdict-evidence"))))

(defun real-certificate (verdict action paths evidence)
  "Mint a candidate certificate from the operator-produced VERDICT
and the real candidate EVIDENCE. Nothing fixture-grade reaches the
certificate."
  (hngh.domain:issue-candidate-certificate
   verdict
   :action action
   :repository-identity (getf evidence :repository-identity)
   :base-revision (getf evidence :base-revision)
   :candidate-paths (sort (copy-list paths) #'string<)
   :content-hash (getf evidence :content-hash)
   :evidence-hashes (getf evidence :evidence-hashes)
   :review-findings '()
   :source-manifest (getf evidence :source-manifest)
   :policy-profile "real"
   :expiry (format-utc-timestamp (+ (get-universal-time) 86400))))

(defun report-mutation-result (result)
  "Map a MUTATION-RESULT to the operator-visible output and exit."
  (case (hngh.adapters.mutation:mutation-result-status result)
    (:executed (values (hngh.presentation:render result) 0))
    (:mismatch (values (hngh.presentation:render result) 1))
    (:refused (values (hngh.presentation:render result) 1))
    (:transport-fault (values (hngh.presentation:render result) 3))
    (:command-failed (values (hngh.presentation:render result) 1))))

(defun real-issue-cert (action verdict-file paths gather-ports)
  "Issue a genuine certificate: only an operator-produced verdict
report (READ-VERDICT-REPORT) and real candidate evidence
(REAL-RUN-EVIDENCE) may mint one. Anything missing, unadmitted, or
malformed is refused."
  (multiple-value-bind (verdict verdict-label)
      (read-verdict-report verdict-file)
    (unless verdict
      (return-from real-issue-cert
        (values (format nil "certificate refused: ~A" verdict-label) 1)))
    (unless (eq :admitted (hngh.domain:policy-verdict-state verdict))
      (return-from real-issue-cert
        (values "certificate refused: unadmitted-verdict" 1)))
    (multiple-value-bind (evidence evidence-label)
        (real-run-evidence paths (uiop:getcwd) gather-ports)
      (unless evidence
        (return-from real-issue-cert
          (values (format nil "certificate refused: ~A" evidence-label) 1)))
      (values (hngh.presentation:render
               (real-certificate verdict action paths evidence))
              0))))

(defun dispatch-issue-cert (args store clock gather-ports)
  (declare (ignore clock))
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (< (length positionals) 2))
      (return-from dispatch-issue-cert (values (command-usage) 2)))
    (let ((action (intern (string-upcase (first positionals)) :keyword))
          (identifier (second positionals)))
      (unless (member action hngh.adapters.mutation::+mutation-actions+)
        (return-from dispatch-issue-cert
          (values (format nil "issue-cert action: ~{~A~^|~}~%~A"
                          (mapcar (lambda (a)
                                    (string-downcase (symbol-name a)))
                                  hngh.adapters.mutation::+mutation-actions+)
                          (command-usage))
                  2)))
      (let ((run (run-from-store store identifier)))
        (unless run
          (return-from dispatch-issue-cert (missing-run-output identifier)))
        (unless (store-has-admission-receipt-p store identifier)
          (return-from dispatch-issue-cert
            (values (format nil "certificate refused: run ~A not admitted"
                            identifier)
                    1)))
        (handler-case
            (if (third positionals)
                (real-issue-cert action (third positionals)
                                 (or (cdddr positionals) '("candidate.lisp"))
                                 gather-ports)
                (values "certificate refused: missing-verdict-evidence" 1))
          (error (condition)
            (values (format nil "malformed issue-cert: ~A" condition) 2)))))))


(defun fixture-mutation-check (store identifier action positionals mutation-ports clock)
  "Fixture-grade mutation check kept for the pre-verdict-report
workflow; superseded by REAL-MUTATION-CHECK once a verdict file is
passed."
  (multiple-value-bind (content-hash evidence-hashes manifest)
      (dogfood-payload identifier action)
    (let* ((certificate
             (dogfood-certificate store identifier action
                                  '("candidate.lisp")))
           (evidence
             (hngh.adapters.mutation:make-mutation-evidence
              :repository-identity
              (car (last (pathname-directory
                          (uiop:ensure-directory-pathname
                           (hngh.adapters.filesystem::
                            filesystem-store-root-directory store)))))
              :base-revision identifier
              :candidate-paths '("candidate.lisp")
              :content-hash content-hash
              :evidence-hashes (append evidence-hashes
                                       (cddr positionals))
              :principle-verdicts (list (dogfood-verdict))
              :review-findings '()
              :source-manifest manifest
              :policy-profile "dogfood"
              :now (funcall clock)))
           (result
             (hngh.main:execute-run-mutation
              certificate evidence
              (or mutation-ports (default-mutation-ports))
              :action action)))
      (case (hngh.adapters.mutation:mutation-result-status result)
        (:executed (values (hngh.presentation:render result) 0))
        (:mismatch (values (hngh.presentation:render result) 1))
        (:refused (values (hngh.presentation:render result) 1))
        (:transport-fault (values (hngh.presentation:render result) 3))
        (:command-failed (values (hngh.presentation:render result) 1))))))


(defun real-mutation-check (store identifier action verdict-file
                            positionals mutation-ports gather-ports clock)
  "Mutation-check backed by the operator-verified verdict report and
the real runner evidence. Anything missing, unadmitted, or malformed
is refused."
  (declare (ignore store identifier))
  (multiple-value-bind (verdict verdict-label)
      (read-verdict-report verdict-file)
    (unless verdict
      (return-from real-mutation-check
        (values (format nil "mutation-check refused: ~A" verdict-label) 1)))
    (unless (eq :admitted (hngh.domain:policy-verdict-state verdict))
      (return-from real-mutation-check
        (values "mutation-check refused: unadmitted-verdict" 1)))
    (multiple-value-bind (evidence evidence-label)
        (real-run-evidence (or (cdddr positionals) '("candidate.lisp"))
                           (uiop:getcwd) gather-ports)
      (unless evidence
        (return-from real-mutation-check
          (values (format nil "mutation-check refused: ~A" evidence-label) 1)))
      (let* ((certificate
               (real-certificate verdict action
                                 (or (cdddr positionals) '("candidate.lisp"))
                                 evidence))
             (evidence
               (hngh.adapters.mutation:make-mutation-evidence
                :repository-identity (getf evidence :repository-identity)
                :base-revision (getf evidence :base-revision)
                :candidate-paths (getf evidence :candidate-paths)
                :content-hash (getf evidence :content-hash)
                :evidence-hashes (getf evidence :evidence-hashes)
                :principle-verdicts (list verdict)
                :review-findings '()
                :source-manifest (getf evidence :source-manifest)
                :policy-profile "real"
                :now (funcall clock)))
             (result
               (hngh.main:execute-run-mutation
                certificate evidence
                (or mutation-ports (default-mutation-ports))
                :action action)))
        (case (hngh.adapters.mutation:mutation-result-status result)
          (:executed (values (hngh.presentation:render result) 0))
          (:mismatch (values (hngh.presentation:render result) 1))
          (:refused (values (hngh.presentation:render result) 1))
          (:transport-fault (values (hngh.presentation:render result) 3))
          (:command-failed (values (hngh.presentation:render result) 1)))))))

(defun dispatch-mutation-check (args store clock mutation-ports gather-ports)
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (< (length positionals) 2))
      (return-from dispatch-mutation-check (values (command-usage) 2)))
    (let* ((action (intern (string-upcase (first positionals)) :keyword))
           (identifier (second positionals)))
      (unless (member action hngh.adapters.mutation::+mutation-actions+)
        (return-from dispatch-mutation-check
          (values (format nil "mutation-check action: ~{~A~^|~}~%~A"
                          (mapcar (lambda (a)
                                    (string-downcase (symbol-name a)))
                                  hngh.adapters.mutation::+mutation-actions+)
                          (command-usage))
                  2)))
      (let ((run (run-from-store store identifier)))
        (unless run
          (return-from dispatch-mutation-check (missing-run-output identifier)))
        (unless (store-has-admission-receipt-p store identifier)
          (return-from dispatch-mutation-check
            (values (format nil "mutation-check refused: run ~A not admitted"
                            identifier)
                    1)))
        (handler-case
            (if (third positionals)
                (real-mutation-check store identifier action
                                     (third positionals) positionals
                                     mutation-ports gather-ports clock)
                (fixture-mutation-check store identifier action positionals
                                        mutation-ports clock))
          (error (condition)
            (values (format nil "malformed mutation-check: ~A" condition) 2)))))))

;;; Federation commands --------------------------------------------------
;;; Rung 11: fetch-evidence gathers remote evidence through the injected
;;; federation ports (no default transport: without :federation-ports it
;;; refuses no-federation-transport) and is served only to a run holding
;;; a :federation admission receipt. verify-attestation reads an
;;; operator-provided carrier bundle FILE, parses and verifies it through
;;; the injected attestation ports (no default: without :attestation-ports
;;; it refuses no-attestation-transport) against the harness clock.
;;; Neither command ever spawns a subprocess or touches a wire when the
;;; injected ports are fakes. Exit codes match the operator surface:
;;; 0 complete/verified, 1 refused, 2 malformed invocation or file,
;;; 3 transport fault.

(defparameter +fetch-option-keys+ '(:peer :max-facts :time-window))

(defun dispatch-fetch-evidence (args store clock federation-ports)
  (declare (ignore clock))
  (multiple-value-bind (positionals options) (collect-options args)
    (let ((unknown (find-if (lambda (pair)
                              (not (member (car pair) +fetch-option-keys+)))
                            options)))
      (when unknown
        (return-from dispatch-fetch-evidence
          (values (format nil "unknown fetch-evidence key: ~A~%~A"
                          (cdr unknown) (command-usage))
                  2))))
    (unless (= 1 (length positionals))
      (return-from dispatch-fetch-evidence (values (command-usage) 2)))
    (let* ((identifier (first positionals))
           (run (run-from-store store identifier)))
      (unless run
        (return-from dispatch-fetch-evidence (missing-run-output identifier)))
      (unless (store-has-transport-admission-receipt-p store identifier
                                                       :federation)
        (return-from dispatch-fetch-evidence
          (values (format nil "fetch-evidence refused: run ~A not admitted for federation"
                          identifier)
                  1)))
      (unless federation-ports
        (return-from dispatch-fetch-evidence
          (values "fetch-evidence refused: no-federation-transport" 1)))
      (handler-case
          (let* ((plist (options-plist options))
                 (peer (getf plist :peer))
                 (max-facts (and (getf plist :max-facts)
                                 (parse-integer (getf plist :max-facts)))))
            (unless peer
              (return-from dispatch-fetch-evidence
                (values "fetch-evidence refused: missing peer" 2)))
            (let ((result
                    (gather-federated-evidence
                     federation-ports
                     :peer peer
                     :max-facts max-facts
                     :time-window (and (getf plist :time-window)
                                       (uiop:split-string
                                        (getf plist :time-window)
                                        :separator ",")))))
              (report-federation-result result)))
        (error (condition)
          (values (format nil "malformed fetch-evidence: ~A" condition) 2))))))

(defparameter +verify-option-keys+ '(:pins)
  "verify-attestation accepts only the operator pins file option.")

(defun read-pins-file (path)
  "Read and strict-parse an operator pins file. Returns
(values registry nil) or (values nil refusal-text)."
  (handler-case
      (values (hngh.adapters.federation:parse-pinned-keys
               (uiop:read-file-string path))
              nil)
    (file-error () (values nil "cannot read pins file"))
    (error () (values nil "malformed pins file"))))

(defun dispatch-verify-attestation (args store clock attestation-ports)
  (multiple-value-bind (positionals options) (collect-options args)
    (let ((unknown (find-if (lambda (pair)
                              (not (member (car pair) +verify-option-keys+)))
                            options)))
      (when (or unknown (/= 2 (length positionals)))
        (return-from dispatch-verify-attestation
          (values
           (if unknown
               (format nil "unknown verify-attestation option: ~A~%~A"
                       (cdr unknown) (command-usage))
               (command-usage))
           2))))
    ;; The operator pins file is the trust anchor: when present it
    ;; replaces any injected attestation ports with the real pinned
    ;; registry over the installed read-only process transport.
    (let* ((pins-path (cdr (assoc :pins options)))
           (ports
             (if pins-path
                 (multiple-value-bind (registry refusal)
                     (read-pins-file pins-path)
                   (when refusal
                     (return-from dispatch-verify-attestation
                       (values (format nil "verify-attestation refused: ~A"
                                       refusal)
                               2)))
                   (hngh.adapters.federation:make-pinned-attestation-ports
                    registry #'hngh.adapters.evidence:process-run))
                 attestation-ports))
           (identifier (first positionals))
           (path (second positionals))
           (run (run-from-store store identifier)))
      (unless run
        (return-from dispatch-verify-attestation (missing-run-output identifier)))
      (unless (store-has-transport-admission-receipt-p store identifier
                                                       :federation)
        (return-from dispatch-verify-attestation
          (values (format nil "verify-attestation refused: run ~A not admitted for federation"
                          identifier)
                  1)))
      (unless ports
        (return-from dispatch-verify-attestation
          (values "verify-attestation refused: no-attestation-transport" 1)))
      (handler-case
          (let* ((text (uiop:read-file-string path))
                 (attestation
                   (hngh.adapters.federation:parse-attestation-envelope text)))
            (let ((result
                    (verify-remote-attestation
                     ports attestation (funcall clock))))
              (report-attestation-result result)))
        (error (condition)
          (values (format nil "malformed verify-attestation: ~A" condition)
                  2))))))

(defun dispatch-list-pins (args)
  "list-pins PATH: read and strict-parse an operator pins file, then
render one line per pin. The command is a pure operator utility: it
touches no run ledger and spawns no process."
  (multiple-value-bind (positionals options) (collect-options args)
    (when (or options (/= 1 (length positionals)))
      (return-from dispatch-list-pins (values (command-usage) 2)))
    (multiple-value-bind (registry refusal)
        (read-pins-file (first positionals))
      (if refusal
          (values (format nil "list-pins refused: ~A" refusal) 2)
          (values (hngh.presentation:render-pin-list registry) 0)))))

(defun report-federation-result (result)
  "Map a FEDERATION-RESULT to (values output exit-code): 0 complete,
1 refused, 3 transport fault."
  (case (hngh.adapters.federation:federation-result-status result)
    (:complete (values (hngh.presentation:render result) 0))
    (:refused
     (values (hngh.presentation:render result)
             (if (member "transport-fault"
                         (hngh.adapters.federation:federation-result-refusal-labels result)
                         :test #'string=)
                 3 1)))))

(defun report-attestation-result (result)
  "Map an ATTESTATION-RESULT to (values output exit-code): 0 verified,
1 refused, 3 transport fault."
  (case (hngh.adapters.federation:attestation-result-status result)
    (:verified (values (hngh.presentation:render result) 0))
    (:refused (values (hngh.presentation:render result) 1))
    (:fault (values (hngh.presentation:render result) 3))))

(defun dispatch-command* (positionals store clock mutation-ports gather-ports
                              review-ports terminal-ports
                              federation-ports attestation-ports)
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
    ((string= command "propose") (dispatch-propose args store clock))
    ((string= command "issue-cert")
     (dispatch-issue-cert args store clock gather-ports))
    ((string= command "mutation-check")
     (dispatch-mutation-check args store clock mutation-ports gather-ports))
    ((string= command "review") (dispatch-review args store clock review-ports))
    ((string= command "terminal")
     (dispatch-terminal args store clock terminal-ports))
    ((string= command "fetch-evidence")
     (dispatch-fetch-evidence args store clock federation-ports))
    ((string= command "verify-attestation")
     (dispatch-verify-attestation args store clock attestation-ports))
    ((string= command "list-pins") (dispatch-list-pins args))
    ((string= command "present") (dispatch-present args store clock))
    (t (values (format nil "unknown command: ~A~%~A" command (command-usage))
               2)))))

(defun dispatch-command (argv &key clock-now mutation-ports gather-ports
                              review-ports terminal-ports
                              federation-ports attestation-ports)
  "Parse the operator ARGV list, execute the named command, and return
(values output-string exit-code). Exit codes: 0 accepted; 1 refused or
conflict; 2 malformed invocation (unknown command, wrong arity, unknown
option, transport, or verb); 3 transport fault. CLOCK-NOW may inject a
timestamp callback for deterministic tests. MUTATION-PORTS injects the
mutation adapter ports for mutation-check, so the command never spawns
a subprocess when fakes are supplied. GATHER-PORTS injects the
candidate-evidence process transport for issue-cert and mutation-check,
so real evidence gathering also never spawns a subprocess when fakes are
supplied. REVIEW-PORTS injects the model-review adapter ports for the
review command (no default provider exists; without injection the command
refuses no-review-transport). TERMINAL-PORTS injects the operator
statement ports for the terminal command (no default input exists;
without injection the command refuses no-terminal-transport).
FEDERATION-PORTS and ATTESTATION-PORTS inject the federation adapter
ports for the fetch-evidence and verify-attestation commands; no default
exists, so without injection the commands refuse no-federation-transport
and no-attestation-transport and plain scripts/hngh never touches a
wire."
  (multiple-value-bind (positionals store-path bad-option)
      (split-argv argv)
    (when bad-option
      (return-from dispatch-command
        (values (format nil "unknown option: ~A~%~A" bad-option (command-usage))
                2)))
    (let ((clock (or clock-now (default-clock-callback))))
      (if store-path
          (handler-case
              (dispatch-command* positionals
                                 (hngh.adapters.filesystem:make-filesystem-store
                                  :root store-path)
                                 clock mutation-ports gather-ports
                                 review-ports terminal-ports
                                 federation-ports attestation-ports)
            (hngh.adapters.filesystem:transport-fault (condition)
              (values (format nil "transport fault: ~A" condition) 3))
            (hngh.adapters.filesystem:store-refusal (condition)
              (values (format nil "store refusal: ~A" condition) 2)))
          (dispatch-command* positionals nil clock mutation-ports gather-ports
                             review-ports terminal-ports
                             federation-ports attestation-ports)))))

;;; Operator-visible root ----------------------------------------------------

(defun display (value)
  "Render VALUE to a plain factual string for an operator."
  (hngh.presentation:render value))