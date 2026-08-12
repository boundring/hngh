(in-package :hngh.tests)

(defparameter +canonical-run-states+
  '(:created :armed :running :checkpointed :cancelled :evacuated :dead
    :afterlife :scored :archived))

(defparameter +legal-run-successors+
  '((:created :armed :cancelled :dead)
    (:armed :running :cancelled :dead)
    (:running :checkpointed :cancelled :evacuated :dead)
    (:checkpointed :running :cancelled :evacuated :dead)
    (:cancelled :afterlife)
    (:evacuated :afterlife)
    (:dead :afterlife)
    (:afterlife :scored)
    (:scored :archived)
    (:archived)))

(defparameter +state-paths+
  '((:created)
    (:armed :armed)
    (:running :armed :running)
    (:checkpointed :armed :running :checkpointed)
    (:cancelled :cancelled)
    (:evacuated :armed :running :evacuated)
    (:dead :dead)
    (:afterlife :cancelled :afterlife)
    (:scored :cancelled :afterlife :scored)
    (:archived :cancelled :afterlife :scored :archived)))

(defun legal-successor-p (source target)
  (member target (rest (assoc source +legal-run-successors+))))

(defun make-domain-run ()
  (hngh.domain:make-run
   :identifier "run-1"
   :mission (hngh.domain:make-mission
             :objective "Specify the run domain"
             :non-objectives '("Persist no state")
             :source-references '("docs/project/roadmap.md")
             :acceptance-criteria '("All transitions are covered")
             :writable-scopes '("repository")
             :verification "make test"
             :evacuation-condition "Contract is reviewed")
   :role (hngh.domain:make-role-template
          :name "builder"
          :capabilities '("edit")
          :required-review-role "reviewer"
          :permitted-loadout-classes '("manual"))
   :loadout (hngh.domain:make-loadout
             :route-label :local
             :context-limit 1
             :token-limit 2
             :cost-limit 3
             :time-limit 4
             :tool-labels '("make-test")
             :network-labels '("none")
             :writable-scopes '("repository"))))

(defun run-at-state (state)
  (let ((run (make-domain-run)))
    (dolist (successor (rest (assoc state +state-paths+)))
      (setf run (hngh.domain:advance-run run successor)))
    run))

(defun signals-invalid-run-transition-p (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (hngh.domain:invalid-run-transition () t)))

(dolist (source +canonical-run-states+)
  (dolist (target +canonical-run-states+)
    (let ((allowed (legal-successor-p source target))
          (run (run-at-state source)))
      (check (eql (not (null allowed))
                  (hngh.domain:allowed-transition-p source target))
             (format nil "transition predicate matches ~S -> ~S" source target))
      (if allowed
          (let ((advanced (hngh.domain:advance-run run target)))
            (check (and (not (eq run advanced))
                        (eql source (hngh.domain:run-state run))
                        (eql target (hngh.domain:run-state advanced)))
                   (format nil "transition advances ~S -> ~S without mutation" source target)))
          (check (signals-invalid-run-transition-p
                  (lambda () (hngh.domain:advance-run run target)))
                 (format nil "transition refuses ~S -> ~S" source target))))))

(let ((run (make-domain-run)))
  (let ((receipt (hngh.domain:make-receipt
                  :kind :verification
                  :facts '("make test passed")))
        (score (hngh.domain:make-score-record
                :delivery 1
                :cost 2
                :headroom 3
                :turnaround 4
                :lesson-reuse 5))
        (afterlife (hngh.domain:make-afterlife-record
                    :terminal-cause :limit
                    :observed-facts '("limit reached")
                    :salvage-labels '("checkpoint")
                    :rejected-hypotheses '("retry is safe")
                    :lesson-candidate "stop before the limit")))
    (declare (ignore receipt score afterlife))
    (check (eql :created (hngh.domain:run-state run))
           "evidence records do not change run state")
    (check (signals-invalid-run-transition-p
            (lambda () (hngh.domain:advance-run run :running)))
           "a receipt cannot start a run")
    (check (null (find-symbol "RECEIPT-AUTHORITY" :hngh.domain))
           "receipt exposes no authority field")
    (check (null (find-symbol "SCORE-RECORD-STATE" :hngh.domain))
           "score exposes no state field")
    (check (null (find-symbol "SCORE-RECORD-AUTHORITY" :hngh.domain))
           "score exposes no authority field")
    (check (null (find-symbol "AFTERLIFE-RECORD-AUTHORITY" :hngh.domain))
           "lesson record exposes no authority field")))

(defun domain-slot-writable-p (name)
  (fboundp (list 'setf (find-symbol name :hngh.domain))))

(dolist (slot-name '("MISSION-OBJECTIVE"
                     "MISSION-NON-OBJECTIVES"
                     "MISSION-SOURCE-REFERENCES"
                     "MISSION-ACCEPTANCE-CRITERIA"
                     "MISSION-WRITABLE-SCOPES"
                     "MISSION-VERIFICATION"
                     "MISSION-EVACUATION-CONDITION"
                     "ROLE-TEMPLATE-NAME"
                     "ROLE-TEMPLATE-CAPABILITIES"
                     "ROLE-TEMPLATE-REQUIRED-REVIEW-ROLE"
                     "ROLE-TEMPLATE-PERMITTED-LOADOUT-CLASSES"
                     "LOADOUT-ROUTE-LABEL"
                     "LOADOUT-CONTEXT-LIMIT"
                     "LOADOUT-TOKEN-LIMIT"
                     "LOADOUT-COST-LIMIT"
                     "LOADOUT-TIME-LIMIT"
                     "LOADOUT-TOOL-LABELS"
                     "LOADOUT-NETWORK-LABELS"
                     "LOADOUT-WRITABLE-SCOPES"
                     "RUN-IDENTIFIER"
                     "RUN-MISSION"
                     "RUN-ROLE"
                     "RUN-LOADOUT"
                     "RUN-STATE"
                     "RECEIPT-KIND"
                     "RECEIPT-FACTS"
                     "SCORE-RECORD-DELIVERY"
                     "SCORE-RECORD-COST"
                     "SCORE-RECORD-HEADROOM"
                     "SCORE-RECORD-TURNAROUND"
                     "SCORE-RECORD-LESSON-REUSE"
                     "AFTERLIFE-RECORD-TERMINAL-CAUSE"
                     "AFTERLIFE-RECORD-OBSERVED-FACTS"
                     "AFTERLIFE-RECORD-SALVAGE-LABELS"
                     "AFTERLIFE-RECORD-REJECTED-HYPOTHESES"
                     "AFTERLIFE-RECORD-LESSON-CANDIDATE"))
  (check (not (domain-slot-writable-p (concatenate 'string "%" slot-name)))
         (format nil "domain storage slot ~A is read-only" slot-name)))

(check (not (domain-slot-writable-p "RUN-STATE"))
       "public run state accessor is read-only")
