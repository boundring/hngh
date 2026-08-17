(in-package :hngh.tests)

(let* ((path (copy-seq "src/domain/mission.lisp"))
       (hash (copy-seq "hash-1"))
       (role (copy-seq "domain source"))
       (entry (hngh.domain:make-source-manifest-entry
               :relative-path path :content-hash hash :source-role role)))
  (setf (char path 0) #\X)
  (setf (char hash 0) #\X)
  (setf (char role 0) #\X)
  (check (equal "src/domain/mission.lisp"
                (hngh.domain:source-manifest-entry-relative-path entry))
         "manifest entry copies caller-owned path")
  (check (equal "hash-1"
                (hngh.domain:source-manifest-entry-content-hash entry))
         "manifest entry copies caller-owned hash")
  (check (equal "domain source"
                (hngh.domain:source-manifest-entry-source-role entry))
         "manifest entry copies caller-owned role"))

(let* ((entry (hngh.domain:make-source-manifest-entry
               :relative-path "src/domain/mission.lisp"
               :content-hash "hash-1"
               :source-role "domain source"))
       (path (hngh.domain:source-manifest-entry-relative-path entry))
       (hash (hngh.domain:source-manifest-entry-content-hash entry))
       (role (hngh.domain:source-manifest-entry-source-role entry)))
  (setf (char path 0) #\X)
  (setf (char hash 0) #\X)
  (setf (char role 0) #\X)
  (check (and (equal "src/domain/mission.lisp"
                    (hngh.domain:source-manifest-entry-relative-path entry))
              (equal "hash-1"
                     (hngh.domain:source-manifest-entry-content-hash entry))
              (equal "domain source"
                     (hngh.domain:source-manifest-entry-source-role entry)))
         "manifest entry isolates every public string reader result"))

(let ((fact (hngh.domain:make-evidence-fact
             :kind :fixture :fingerprint "fp-1" :state :current)))
  (check (and (eql :fixture (hngh.domain:evidence-fact-kind fact))
              (equal "fp-1" (hngh.domain:evidence-fact-fingerprint fact))
              (eql :current (hngh.domain:evidence-fact-state fact)))
         "evidence fact preserves its closed values"))

(let ((input (copy-seq "fp-1"))
      (fact nil))
  (setf fact (hngh.domain:make-evidence-fact
              :kind :fixture :fingerprint input :state :current))
  (setf (char input 0) #\X)
  (let ((reported (hngh.domain:evidence-fact-fingerprint fact)))
    (setf (char reported 0) #\X)
    (check (equal "fp-1" (hngh.domain:evidence-fact-fingerprint fact))
           "evidence fingerprint is isolated from input and reader mutation")))

(let ((result (hngh.domain:make-principle-result
               :principle :closed-authority
               :state :passed
               :evidence-fingerprints '("fp-1" "fp-2"))))
  (check (and (eql :closed-authority
                   (hngh.domain:principle-result-principle result))
              (eql :passed (hngh.domain:principle-result-state result))
              (equal '("fp-1" "fp-2")
                     (hngh.domain:principle-result-evidence-fingerprints result)))
         "principle result preserves validated values"))

(let ((input (list (copy-seq "fp-1")))
      (result nil))
  (setf result (hngh.domain:make-principle-result
                :principle :closed-authority :state :passed
                :evidence-fingerprints input))
  (setf (char (first input) 0) #\X)
  (let ((reported (hngh.domain:principle-result-evidence-fingerprints result)))
    (setf (char (first reported) 0) #\X)
    (check (equal '("fp-1")
                  (hngh.domain:principle-result-evidence-fingerprints result))
           "principle evidence fingerprints isolate input and reader mutation")))

(let ((verdict (hngh.domain:make-policy-verdict
                :state :admitted
                :principle-results
                (list (hngh.domain:make-principle-result
                       :principle :closed-authority
                       :state :passed
                       :evidence-fingerprints '("fp-1")))
                :reason-labels '("all required principles passed"))))
  (check (and (eql :admitted (hngh.domain:policy-verdict-state verdict))
              (= 1 (length (hngh.domain:policy-verdict-principle-results verdict)))
              (equal '("all required principles passed")
                     (hngh.domain:policy-verdict-reason-labels verdict)))
         "policy verdict preserves validated values"))

(dolist (case '((hngh.domain:validate-proposal-class :unknown)
                (hngh.domain:validate-principle-identifier :unknown)
                (hngh.domain:validate-failure-category :unknown)
                (hngh.domain:validate-failure-disposition :unknown)))
  (check (signals-error-p (lambda () (apply #'funcall case)))
         "unknown governance vocabulary refuses"))

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-evidence-fact
           :kind :fixture :fingerprint "" :state :current)))
       "malformed evidence refuses")
(dolist (state '(:unknown :invalid))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-evidence-fact
             :kind :fixture :fingerprint "fp" :state state)))
         "unknown evidence state refuses"))
(dolist (state '(:unknown :invalid))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-principle-result
             :principle :closed-authority :state state
             :evidence-fingerprints '("fp"))))
         "unknown principle result state refuses"))
(dolist (state '(:unknown :invalid))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-policy-verdict
             :state state :principle-results '() :reason-labels '("reason"))))
         "unknown policy verdict state refuses"))
(dolist (arguments '((:content-hash "hash" :source-role "role")
                     (:relative-path "path" :source-role "role")
                     (:relative-path "path" :content-hash "hash")))
  (check (signals-error-p
          (lambda ()
            (apply #'hngh.domain:make-source-manifest-entry arguments)))
         "missing source manifest field refuses"))
(dolist (arguments '((:relative-path "" :content-hash "hash" :source-role "role")
                     (:relative-path "path" :content-hash "" :source-role "role")
                     (:relative-path "path" :content-hash "hash" :source-role "")))
  (check (signals-error-p
          (lambda () (apply #'hngh.domain:make-source-manifest-entry arguments)))
         "malformed source manifest field refuses"))
(dolist (arguments '((:principle nil :state :passed :evidence-fingerprints '("fp"))
                     (:principle :closed-authority :state nil :evidence-fingerprints '("fp"))
                     (:principle :closed-authority :state :passed
                      :evidence-fingerprints 'not-a-list)))
  (check (signals-error-p
          (lambda () (apply #'hngh.domain:make-principle-result arguments)))
         "missing principle result field refuses"))
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-principle-result
           :principle :closed-authority
           :state :passed
           :evidence-fingerprints '("fp-1" "fp-1"))))
       "duplicate evidence fingerprints refuse")
(let ((first-result (hngh.domain:make-principle-result
                     :principle :closed-authority :state :passed
                     :evidence-fingerprints '("fp-1")))
      (second-result (hngh.domain:make-principle-result
                      :principle :closed-authority :state :refused
                      :evidence-fingerprints '("fp-2"))))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-policy-verdict
             :state :refused :principle-results (list first-result second-result)
             :reason-labels '("reason"))))
         "duplicate principle results refuse"))
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-policy-verdict
           :state :refused :principle-results '()
           :reason-labels '("reason" "reason"))))
       "duplicate reason labels refuse")
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-policy-verdict
           :state nil :principle-results '() :reason-labels '())))
       "missing policy verdict fields refuse")

(let* ((labels (list "reason"))
       (results (list (hngh.domain:make-principle-result
                       :principle :least-authority :state :refused
                       :evidence-fingerprints '("fp"))))
       (verdict (hngh.domain:make-policy-verdict
                 :state :refused :principle-results results
                 :reason-labels labels)))
  (setf (first labels) "changed")
  (setf (first results) nil)
  (check (equal '("reason")
                (hngh.domain:policy-verdict-reason-labels verdict))
         "policy verdict copies caller-owned labels")
  (check (not (null (first (hngh.domain:policy-verdict-principle-results verdict))))
         "policy verdict copies caller-owned results")
  (let ((reported (hngh.domain:policy-verdict-reason-labels verdict)))
    (setf (first reported) "changed")
    (check (equal '("reason")
                  (hngh.domain:policy-verdict-reason-labels verdict))
           "policy verdict defensively copies public labels")))

(dolist (name '("SOURCE-MANIFEST-ENTRY-ACTION" "POLICY-VERDICT-AUTHORITY"
                "PRINCIPLE-RESULT-CERTIFICATE"))
  (check (null (find-symbol name :hngh.domain))
         "governance value exposes no action authority or certificate field"))

(check (signals-error-p (lambda () (hngh.domain:validate-evidence-requirement-kind nil)))
       "nil evidence requirement kind refuses")
(check (signals-error-p (lambda () (hngh.domain:validate-evidence-requirement-kind :unknown)))
       "unknown evidence requirement kind refuses")

(let* ((fact (hngh.domain:make-evidence-fact :kind :open :fingerprint "fact-1" :state :current))
       (facts (list fact))
       (fingerprints (list (copy-seq "proof-1")))
       (requirement (hngh.domain:make-evidence-requirement
                     :principle :fail-closed :kind :claim-proof
                     :required-fingerprints fingerprints :evidence-facts facts)))
  (setf (first fingerprints) "changed")
  (setf (first (hngh.domain:evidence-requirement-required-fingerprints requirement)) "changed")
  (setf facts nil)
  (check (and (eql :fail-closed (hngh.domain:evidence-requirement-principle requirement))
              (eql :claim-proof (hngh.domain:evidence-requirement-kind requirement))
              (equal '("proof-1")
                     (hngh.domain:evidence-requirement-required-fingerprints requirement))
              (= 1 (length (hngh.domain:evidence-requirement-evidence-facts requirement))))
         "evidence requirement preserves and isolates valid data"))
(check (signals-error-p
        (lambda () (hngh.domain:make-evidence-requirement
                    :principle :fail-closed :kind :claim-proof
                    :required-fingerprints '("fp" "fp") :evidence-facts '())))
       "duplicate required fingerprints refuse")
(let ((fact (hngh.domain:make-evidence-fact :kind :open :fingerprint "same" :state :current)))
  (check (signals-error-p
          (lambda () (hngh.domain:make-evidence-requirement
                      :principle :fail-closed :kind :claim-proof
                      :required-fingerprints '("fp") :evidence-facts (list fact fact))))
         "duplicate evidence fact fingerprints refuse"))
(check (signals-error-p
        (lambda () (hngh.domain:make-evidence-requirement
                    :principle :fail-closed :kind :claim-proof :evidence-facts '())))
       "missing required fingerprints refuse")

(let* ((entry (hngh.domain:make-source-manifest-entry
               :relative-path "src/a" :content-hash "hash" :source-role "source"))
       (req-a (hngh.domain:make-evidence-requirement
               :principle :fail-closed :kind :purpose
               :required-fingerprints '("purpose") :evidence-facts '()))
       (req-b (hngh.domain:make-evidence-requirement
               :principle :fail-closed :kind :caller
               :required-fingerprints '("caller") :evidence-facts '()))
       (proposal (hngh.domain:make-policy-proposal
                 :class :feature :problem "problem" :outcome "outcome"
                 :purpose "purpose" :caller "caller" :input-contract "input"
                 :output-contract "output" :failure-contract "failure"
                 :declared-capabilities '() :capability-diff "none"
                 :source-manifest (list entry) :risk-note "risk"
                 :dependency "dependency" :evidence-trigger "trigger"
                 :evidence-requirements (list req-a req-b))))
  (check (and (equal "problem" (hngh.domain:policy-proposal-problem proposal))
              (null (hngh.domain:policy-proposal-declared-capabilities proposal))
              (= 1 (length (hngh.domain:policy-proposal-source-manifest proposal)))
              (= 2 (length (hngh.domain:policy-proposal-evidence-requirements proposal))))
         "policy proposal preserves valid pure data"))

(dolist (field '(:class :problem :outcome :purpose :caller :input-contract
                 :output-contract :failure-contract :declared-capabilities
                 :capability-diff :source-manifest :risk-note :dependency
                 :evidence-trigger :evidence-requirements))
  (check (signals-error-p
          (lambda ()
            (let ((args '(:class :feature :problem "p" :outcome "o" :purpose "p"
                          :caller "c" :input-contract "i" :output-contract "o"
                          :failure-contract "f" :declared-capabilities ()
                          :capability-diff "d" :source-manifest () :risk-note "r"
                          :dependency "d" :evidence-trigger "e"
                          :evidence-requirements ())))
              (remf args field)
              (apply #'hngh.domain:make-policy-proposal args))))
         "missing policy proposal field refuses"))
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-policy-proposal
           :class :feature :problem "p" :outcome "o" :purpose "p" :caller "c"
           :input-contract "i" :output-contract "o" :failure-contract "f"
           :declared-capabilities '("cap" "cap") :capability-diff "d"
           :source-manifest (list (hngh.domain:make-source-manifest-entry
                                   :relative-path "src/a" :content-hash "h" :source-role "s")
                                  (hngh.domain:make-source-manifest-entry
                                   :relative-path "src/a" :content-hash "h2" :source-role "s"))
           :risk-note "r" :dependency "d" :evidence-trigger "e"
           :evidence-requirements '())))
       "duplicate proposal fields and empty lists refuse")
(dolist (name '("EVIDENCE-REQUIREMENT-ACTION" "POLICY-PROPOSAL-AUTHORITY"
                "POLICY-PROPOSAL-CERTIFICATE"))
  (check (null (find-symbol name :hngh.domain))
         "new governance values expose no action authority or certificate"))

(let* ((fingerprint (copy-seq "purpose-fact"))
       (fact (hngh.domain:make-evidence-fact
              :kind :fixture :fingerprint fingerprint :state :current))
       (required (list (copy-seq "purpose-fact")))
       (facts (list fact))
       (requirement (hngh.domain:make-evidence-requirement
                     :principle :closed-authority
                     :kind :purpose
                     :required-fingerprints required
                     :evidence-facts facts)))
  (setf (char fingerprint 0) #\X)
  (setf (char (first required) 0) #\X)
  (setf (first facts) nil)
  (check (and (eql :closed-authority
                   (hngh.domain:evidence-requirement-principle requirement))
              (eql :purpose
                   (hngh.domain:evidence-requirement-kind requirement))
              (equal '("purpose-fact")
                     (hngh.domain:evidence-requirement-required-fingerprints requirement))
              (= 1 (length (hngh.domain:evidence-requirement-evidence-facts requirement))))
         "evidence requirement preserves validated values")
  (let ((reported (hngh.domain:evidence-requirement-required-fingerprints requirement))
        (reported-facts (hngh.domain:evidence-requirement-evidence-facts requirement)))
    (setf (char (first reported) 0) #\X)
    (setf (first reported-facts) nil)
    (check (and (equal '("purpose-fact")
                       (hngh.domain:evidence-requirement-required-fingerprints requirement))
                (= 1 (length (hngh.domain:evidence-requirement-evidence-facts requirement))))
           "evidence requirement defensively copies public values")))

(let* ((entry (hngh.domain:make-source-manifest-entry
               :relative-path "docs/policy.md" :content-hash "hash" :source-role "policy"))
       (purpose-fact (hngh.domain:make-evidence-fact
                      :kind :fixture :fingerprint "purpose" :state :current))
       (caller-fact (hngh.domain:make-evidence-fact
                     :kind :fixture :fingerprint "caller" :state :current))
       (purpose-requirement (hngh.domain:make-evidence-requirement
                             :principle :closed-authority :kind :purpose
                             :required-fingerprints '("purpose")
                             :evidence-facts (list purpose-fact)))
       (caller-requirement (hngh.domain:make-evidence-requirement
                            :principle :closed-authority :kind :caller
                            :required-fingerprints '("caller")
                            :evidence-facts (list caller-fact)))
       (capabilities (list "read"))
       (manifest (list entry))
       (requirements (list purpose-requirement caller-requirement))
       (proposal (hngh.domain:make-policy-proposal
                  :class :feature :problem "missing contract" :outcome "frozen values"
                  :purpose "freeze input" :caller "policy control"
                  :input-contract "immutable values" :output-contract "immutable result"
                  :failure-contract "typed refusal" :declared-capabilities capabilities
                  :capability-diff "none" :source-manifest manifest :risk-note "none"
                  :dependency "domain only" :evidence-trigger "before evaluation"
                  :evidence-requirements requirements)))
  (setf (first capabilities) "changed")
  (setf (first manifest) nil)
  (setf (first requirements) nil)
  (check (and (eql :feature (hngh.domain:policy-proposal-class proposal))
              (equal "missing contract" (hngh.domain:policy-proposal-problem proposal))
              (equal "frozen values" (hngh.domain:policy-proposal-outcome proposal))
              (equal '("read") (hngh.domain:policy-proposal-declared-capabilities proposal))
              (= 1 (length (hngh.domain:policy-proposal-source-manifest proposal)))
              (= 2 (length (hngh.domain:policy-proposal-evidence-requirements proposal))))
         "policy proposal preserves validated values")
  (let ((reported-capabilities (hngh.domain:policy-proposal-declared-capabilities proposal))
        (reported-manifest (hngh.domain:policy-proposal-source-manifest proposal))
        (reported-requirements (hngh.domain:policy-proposal-evidence-requirements proposal)))
    (setf (first reported-capabilities) "changed")
    (setf (first reported-manifest) nil)
    (setf (first reported-requirements) nil)
    (check (and (equal '("read") (hngh.domain:policy-proposal-declared-capabilities proposal))
                (= 1 (length (hngh.domain:policy-proposal-source-manifest proposal)))
                (= 2 (length (hngh.domain:policy-proposal-evidence-requirements proposal))))
           "policy proposal defensively copies public values")))

(let* ((entry (hngh.domain:make-source-manifest-entry
               :relative-path "policy.md" :content-hash "hash" :source-role "policy"))
       (requirement (hngh.domain:make-evidence-requirement
                     :principle :closed-authority :kind :purpose
                     :required-fingerprints '("purpose") :evidence-facts '()))
       (proposal (hngh.domain:make-policy-proposal
                  :class :feature :problem "problem" :outcome "outcome"
                  :purpose "purpose" :caller "caller" :input-contract "input"
                  :output-contract "output" :failure-contract "failure"
                  :declared-capabilities '() :capability-diff "none"
                  :source-manifest (list entry) :risk-note "risk"
                  :dependency "domain" :evidence-trigger "trigger"
                  :evidence-requirements (list requirement))))
  (dolist (reader '(hngh.domain:policy-proposal-problem
                    hngh.domain:policy-proposal-outcome
                    hngh.domain:policy-proposal-purpose
                    hngh.domain:policy-proposal-caller
                    hngh.domain:policy-proposal-input-contract
                    hngh.domain:policy-proposal-output-contract
                    hngh.domain:policy-proposal-failure-contract
                    hngh.domain:policy-proposal-capability-diff
                    hngh.domain:policy-proposal-risk-note
                    hngh.domain:policy-proposal-dependency
                    hngh.domain:policy-proposal-evidence-trigger))
    (let ((reported (funcall reader proposal)))
      (setf (char reported 0) #\X)
      (check (not (char= #\X (char (funcall reader proposal) 0)))
             "every policy proposal string reader defensively copies"))))

(dolist (kind '(:unknown nil))
  (check (signals-error-p
          (lambda () (hngh.domain:validate-evidence-requirement-kind kind)))
         "unknown evidence requirement kind refuses"))

(let ((fact (hngh.domain:make-evidence-fact
             :kind :fixture :fingerprint "fact" :state :current)))
  (dolist (arguments '((:kind :purpose :required-fingerprints '("fact") :evidence-facts '())
                       (:principle :closed-authority :required-fingerprints '("fact") :evidence-facts '())
                       (:principle :closed-authority :kind :purpose :evidence-facts '())))
    (check (signals-error-p
            (lambda () (apply #'hngh.domain:make-evidence-requirement arguments)))
           "missing evidence requirement field refuses"))
  (dolist (arguments `((:principle :closed-authority :kind :unknown
                        :required-fingerprints ("fact") :evidence-facts ())
                       (:principle :closed-authority :kind :purpose
                        :required-fingerprints () :evidence-facts ())
                       (:principle :closed-authority :kind :purpose
                        :required-fingerprints ("fact" "fact") :evidence-facts ())
                       (:principle :closed-authority :kind :purpose
                        :required-fingerprints ("fact") :evidence-facts (,fact ,fact))))
    (check (signals-error-p
            (lambda () (apply #'hngh.domain:make-evidence-requirement arguments)))
           "malformed or duplicate evidence requirement refuses")))

(let* ((entry (hngh.domain:make-source-manifest-entry
               :relative-path "policy.md" :content-hash "hash" :source-role "policy"))
       (requirement (hngh.domain:make-evidence-requirement
                     :principle :closed-authority :kind :purpose
                     :required-fingerprints '("purpose") :evidence-facts '()))
       (base '(:class :feature :problem "problem" :outcome "outcome"
               :purpose "purpose" :caller "caller" :input-contract "input"
               :output-contract "output" :failure-contract "failure"
               :declared-capabilities () :capability-diff "none"
               :source-manifest nil :risk-note "risk" :dependency "domain"
               :evidence-trigger "trigger" :evidence-requirements nil)))
  (dolist (field '(:class :problem :outcome :purpose :caller :input-contract
                   :output-contract :failure-contract :declared-capabilities
                   :capability-diff :source-manifest :risk-note :dependency
                   :evidence-trigger :evidence-requirements))
    (let ((arguments (copy-list base)))
      (remf arguments field)
      (check (signals-error-p
              (lambda () (apply #'hngh.domain:make-policy-proposal arguments)))
             "missing policy proposal field refuses")))
  (dolist (arguments `((:class :feature :problem "problem" :outcome "outcome"
                        :purpose "purpose" :caller "caller" :input-contract "input"
                        :output-contract "output" :failure-contract "failure"
                        :declared-capabilities () :capability-diff "none"
                        :source-manifest () :risk-note "risk" :dependency "domain"
                        :evidence-trigger "trigger" :evidence-requirements (,requirement))
                       (:class :feature :problem "problem" :outcome "outcome"
                        :purpose "purpose" :caller "caller" :input-contract "input"
                        :output-contract "output" :failure-contract "failure"
                        :declared-capabilities () :capability-diff "none"
                        :source-manifest (,entry) :risk-note "risk" :dependency "domain"
                        :evidence-trigger "trigger" :evidence-requirements ())
                       (:class :feature :problem "problem" :outcome "outcome"
                        :purpose "purpose" :caller "caller" :input-contract "input"
                        :output-contract "output" :failure-contract "failure"
                        :declared-capabilities ("read" "read") :capability-diff "none"
                        :source-manifest (,entry) :risk-note "risk" :dependency "domain"
                        :evidence-trigger "trigger" :evidence-requirements (,requirement))
                       (:class :feature :problem "problem" :outcome "outcome"
                        :purpose "purpose" :caller "caller" :input-contract "input"
                        :output-contract "output" :failure-contract "failure"
                        :declared-capabilities () :capability-diff "none"
                        :source-manifest (,entry ,entry) :risk-note "risk" :dependency "domain"
                        :evidence-trigger "trigger" :evidence-requirements (,requirement))
                       (:class :feature :problem "problem" :outcome "outcome"
                        :purpose "purpose" :caller "caller" :input-contract "input"
                        :output-contract "output" :failure-contract "failure"
                        :declared-capabilities () :capability-diff "none"
                        :source-manifest (,entry) :risk-note "risk" :dependency "domain"
                        :evidence-trigger "trigger" :evidence-requirements (,requirement ,requirement))))
    (check (signals-error-p
            (lambda () (apply #'hngh.domain:make-policy-proposal arguments)))
           "malformed or duplicate policy proposal refuses")))

(dolist (name '("POLICY-PROPOSAL-ACTION" "POLICY-PROPOSAL-AUTHORITY"
                "EVIDENCE-REQUIREMENT-CERTIFICATE"))
  (check (null (find-symbol name :hngh.domain))
         "proposal values expose no action authority or certificate field"))

(let ((fact (hngh.domain:make-evidence-fact
             :kind :fixture :fingerprint "fact" :state :current)))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-evidence-requirement
             :principle :fail-closed :kind :claim-proof
             :required-fingerprints '("fact")
             :evidence-facts (list fact "not-a-fact"))))
         "wrong-typed evidence fact member refuses"))

(let* ((entry (hngh.domain:make-source-manifest-entry
               :relative-path "policy.md" :content-hash "hash" :source-role "policy"))
       (requirement (hngh.domain:make-evidence-requirement
                     :principle :closed-authority :kind :purpose
                     :required-fingerprints '("purpose") :evidence-facts '())))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-policy-proposal
             :class :feature :problem "problem" :outcome "outcome"
             :purpose "purpose" :caller "caller" :input-contract "input"
             :output-contract "output" :failure-contract "failure"
             :declared-capabilities () :capability-diff "none"
             :source-manifest (list entry "not-an-entry") :risk-note "risk"
             :dependency "domain" :evidence-trigger "trigger"
             :evidence-requirements (list requirement))))
         "wrong-typed source manifest member refuses")
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-policy-proposal
             :class :feature :problem "problem" :outcome "outcome"
             :purpose "purpose" :caller "caller" :input-contract "input"
             :output-contract "output" :failure-contract "failure"
             :declared-capabilities () :capability-diff "none"
             :source-manifest (list entry) :risk-note "risk"
             :dependency "domain" :evidence-trigger "trigger"
             :evidence-requirements (list requirement "not-a-requirement"))))
         "wrong-typed evidence requirement member refuses"))

;; ---------------------------------------------------------------------------
;; C1: evaluate-policy-proposal — pure deterministic principle evaluator
;; ---------------------------------------------------------------------------

(defun make-fixture-requirement (principle kind required-fingerprints facts)
  (hngh.domain:make-evidence-requirement
   :principle principle :kind kind
   :required-fingerprints required-fingerprints
   :evidence-facts facts))

(defun make-fixture-proposal (requirements)
  (hngh.domain:make-policy-proposal
   :class :feature :problem "problem" :outcome "outcome"
   :purpose "purpose" :caller "caller" :input-contract "input"
   :output-contract "output" :failure-contract "failure"
   :declared-capabilities '() :capability-diff "none"
   :source-manifest (list (hngh.domain:make-source-manifest-entry
                           :relative-path "policy.md" :content-hash "hash"
                           :source-role "policy"))
   :risk-note "risk" :dependency "domain" :evidence-trigger "trigger"
   :evidence-requirements requirements))

;; (a) ten-principle proposal, one requirement each, every required fingerprint
;; supplied once by a :current fact -> :admitted, 10 principle-results all
;; :passed, reason-labels '().
(let* ((principles '(:closed-authority :least-authority :dependency-direction
                     :fail-closed :evidence-before-claim :atomic-mutation
                     :reversibility :no-hidden-execution
                     :cost-and-route-discipline :source-grounding))
       (requirements
         (loop for principle in principles
               for n from 1
               collect (make-fixture-requirement
                        principle (if (member principle '(:purpose :caller))
                                      :purpose :claim-proof)
                        (list (format nil "fp-~D" n))
                        (list (hngh.domain:make-evidence-fact
                               :kind :fixture
                               :fingerprint (format nil "fp-~D" n)
                               :state :current)))))
       (proposal (make-fixture-proposal requirements))
       (verdict (hngh.domain:evaluate-policy-proposal proposal)))
  (check (eql :admitted (hngh.domain:policy-verdict-state verdict))
         "evaluate-policy-proposal admits a ten-principle fully-evidenced proposal")
  (check (= 10 (length (hngh.domain:policy-verdict-principle-results verdict)))
         "evaluate-policy-proposal returns one principle-result per matrix principle")
  (check (every (lambda (result)
                  (eql :passed (hngh.domain:principle-result-state result)))
                (hngh.domain:policy-verdict-principle-results verdict))
         "evaluate-policy-proposal marks every supplied principle-result passed")
  (check (every (lambda (result)
                  (= 1 (length
                        (hngh.domain:principle-result-evidence-fingerprints result))))
                (hngh.domain:policy-verdict-principle-results verdict))
         "each passed principle-result carries its required fingerprint")
  (check (null (hngh.domain:policy-verdict-reason-labels verdict))
         "admitted proposal carries no reason labels"))

;; (b) nine principles present -> :refused, label "missing-principle-result",
;; that principle-result state :refused fingerprints '().
(let* ((principles '(:closed-authority :least-authority :dependency-direction
                     :fail-closed :evidence-before-claim :atomic-mutation
                     :reversibility :no-hidden-execution
                     :cost-and-route-discipline))
       (requirements
         (loop for principle in principles
               for n from 1
               collect (make-fixture-requirement
                        principle :claim-proof
                        (list (format nil "fp-~D" n))
                        (list (hngh.domain:make-evidence-fact
                               :kind :fixture
                               :fingerprint (format nil "fp-~D" n)
                               :state :current)))))
       (proposal (make-fixture-proposal requirements))
       (verdict (hngh.domain:evaluate-policy-proposal proposal))
       (missing (find :source-grounding
                      (hngh.domain:policy-verdict-principle-results verdict)
                      :key #'hngh.domain:principle-result-principle)))
  (check (eql :refused (hngh.domain:policy-verdict-state verdict))
         "a proposal missing one matrix principle is refused")
  (check (and missing
              (eql :refused (hngh.domain:principle-result-state missing))
              (null (hngh.domain:principle-result-evidence-fingerprints missing)))
         "missing principle yields a refused result with no fingerprints")
  (check (member "missing-principle-result"
                 (hngh.domain:policy-verdict-reason-labels verdict)
                 :test #'string=)
         "missing principle records the missing-principle-result label"))

;; (c) required fingerprint absent for one principle -> :refused,
;; "missing-evidence".
(let* ((fact (hngh.domain:make-evidence-fact :kind :fixture
                                             :fingerprint "present" :state :current))
       (requirements (list (make-fixture-requirement
                            :closed-authority :claim-proof
                            '("absent" "present") (list fact))))
       (proposal (make-fixture-proposal requirements))
       (verdict (hngh.domain:evaluate-policy-proposal proposal))
       (result (first (hngh.domain:policy-verdict-principle-results verdict))))
  (check (eql :refused (hngh.domain:policy-verdict-state verdict))
         "an absent required fingerprint refuses the proposal")
  (check (eql :refused (hngh.domain:principle-result-state result))
         "an absent required fingerprint refuses its principle result")
  (check (member "missing-evidence"
                 (hngh.domain:policy-verdict-reason-labels verdict)
                 :test #'string=)
         "absent required fingerprint records the missing-evidence label"))

;; (d) required fingerprint supplied only by a :stale fact -> :refused,
;; "stale-evidence".
(let* ((fact (hngh.domain:make-evidence-fact :kind :fixture
                                             :fingerprint "fp" :state :stale))
       (proposal (make-fixture-proposal
                  (list (make-fixture-requirement
                         :closed-authority :claim-proof '("fp") (list fact)))))
       (verdict (hngh.domain:evaluate-policy-proposal proposal)))
  (check (eql :refused (hngh.domain:policy-verdict-state verdict))
         "stale evidence refuses the proposal")
  (check (member "stale-evidence"
                 (hngh.domain:policy-verdict-reason-labels verdict)
                 :test #'string=)
         "stale evidence records the stale-evidence label"))

;; (e) malformed / conflicting / unverifiable fact states -> matching labels.
(dolist (case '(("malformed-evidence" :malformed)
                ("conflicting-evidence" :conflicting)
                ("unverifiable-evidence" :unverifiable)))
  (destructuring-bind (label state) case
    (let* ((fact (hngh.domain:make-evidence-fact :kind :fixture
                                                 :fingerprint "fp" :state state))
           (proposal (make-fixture-proposal
                      (list (make-fixture-requirement
                             :closed-authority :claim-proof '("fp") (list fact)))))
           (verdict (hngh.domain:evaluate-policy-proposal proposal)))
      (check (eql :refused (hngh.domain:policy-verdict-state verdict))
             (format nil "~A evidence refuses the proposal" label))
      (check (member label
                     (hngh.domain:policy-verdict-reason-labels verdict)
                     :test #'string=)
             (format nil "~A fact records the ~A label" label label)))))

;; (f) fact with state :missing -> "missing-evidence".
(let* ((fact (hngh.domain:make-evidence-fact :kind :fixture
                                             :fingerprint "fp" :state :missing))
       (proposal (make-fixture-proposal
                  (list (make-fixture-requirement
                         :closed-authority :claim-proof '("fp") (list fact)))))
       (verdict (hngh.domain:evaluate-policy-proposal proposal)))
  (check (member "missing-evidence"
                 (hngh.domain:policy-verdict-reason-labels verdict)
                 :test #'string=)
         "missing fact records the missing-evidence label"))

;; (g) a principle with two requirements, one passes one fails -> that
;; principle-result :refused, other principles :passed, verdict :refused.
(let* ((good-fact (hngh.domain:make-evidence-fact :kind :fixture
                                                  :fingerprint "good" :state :current))
       (bad-fact (hngh.domain:make-evidence-fact :kind :fixture
                                                 :fingerprint "bad" :state :stale))
       (other-fact (hngh.domain:make-evidence-fact :kind :fixture
                                                   :fingerprint "other" :state :current))
       (requirements (list
                      (make-fixture-requirement :closed-authority :purpose
                                                '("good") (list good-fact))
                      (make-fixture-requirement :closed-authority :caller
                                                '("bad") (list bad-fact))
                      (make-fixture-requirement :least-authority :purpose
                                                '("other") (list other-fact))))
       (proposal (make-fixture-proposal requirements))
       (verdict (hngh.domain:evaluate-policy-proposal proposal))
       (closed (find :closed-authority
                     (hngh.domain:policy-verdict-principle-results verdict)
                     :key #'hngh.domain:principle-result-principle))
       (least (find :least-authority
                    (hngh.domain:policy-verdict-principle-results verdict)
                    :key #'hngh.domain:principle-result-principle)))
  (check (eql :refused (hngh.domain:principle-result-state closed))
         "a principle with one failing requirement is refused")
  (check (eql :passed (hngh.domain:principle-result-state least))
         "a sibling principle with only passing requirements stays passed")
  (check (eql :refused (hngh.domain:policy-verdict-state verdict))
         "proposal with any failing principle is refused"))

;; (h) cross-principle isolation: A requires "X" supplied by a current fact; B
;; also requires "X" but supplies NO facts -> B :refused with
;; "missing-evidence" (A's fact must NOT satisfy B).
(let* ((fact (hngh.domain:make-evidence-fact :kind :fixture
                                             :fingerprint "X" :state :current))
       (requirements (list
                      (make-fixture-requirement :closed-authority :purpose
                                                '("X") (list fact))
                      (make-fixture-requirement :least-authority :purpose
                                                '("X") '())))
       (proposal (make-fixture-proposal requirements))
       (verdict (hngh.domain:evaluate-policy-proposal proposal))
       (least (find :least-authority
                    (hngh.domain:policy-verdict-principle-results verdict)
                    :key #'hngh.domain:principle-result-principle)))
  (check (eql :refused (hngh.domain:principle-result-state least))
         "a principle's evidence does not satisfy another principle's requirement")
  (check (member "missing-evidence"
                 (hngh.domain:policy-verdict-reason-labels verdict)
                 :test #'string=)
         "un-evidenced sibling principle records missing-evidence"))

;; (i) scrambled requirement order -> principle-results in matrix order.
(let* ((requirements
         (list
          (make-fixture-requirement :source-grounding :purpose
                                    '("sg")
                                    (list (hngh.domain:make-evidence-fact
                                           :kind :fixture :fingerprint "sg"
                                           :state :current)))
          (make-fixture-requirement :closed-authority :purpose
                                    '("ca")
                                    (list (hngh.domain:make-evidence-fact
                                           :kind :fixture :fingerprint "ca"
                                           :state :current)))))
       (proposal (make-fixture-proposal requirements))
       (verdict (hngh.domain:evaluate-policy-proposal proposal))
       (results (hngh.domain:policy-verdict-principle-results verdict)))
  (check (eql :closed-authority
              (hngh.domain:principle-result-principle (first results)))
         "evaluate-policy-proposal orders principle-results in matrix order (first)")
  (check (eql :source-grounding
              (hngh.domain:principle-result-principle (car (last results))))
         "evaluate-policy-proposal orders principle-results in matrix order (last)"))

;; (j) evaluate-policy-proposal on nil and on a non-proposal object ->
;; signals-error-p.
(check (signals-error-p
        (lambda () (hngh.domain:evaluate-policy-proposal nil)))
       "nil proposal refuses evaluation")
(check (signals-error-p
        (lambda () (hngh.domain:evaluate-policy-proposal :not-a-proposal)))
       "non-proposal object refuses evaluation")

;; (k) an extra :current fact beyond required fingerprints does not refuse.
(let* ((extra (hngh.domain:make-evidence-fact :kind :fixture
                                              :fingerprint "extra" :state :current))
       (required (hngh.domain:make-evidence-fact :kind :fixture
                                                 :fingerprint "required"
                                                 :state :current))
       (proposal (make-fixture-proposal
                  (list (make-fixture-requirement
                         :closed-authority :claim-proof
                         '("required") (list required extra)))))
       (verdict (hngh.domain:evaluate-policy-proposal proposal))
       (result (first (hngh.domain:policy-verdict-principle-results verdict))))
  (check (eql :passed (hngh.domain:principle-result-state result))
         "extra current fact does not refuse a satisfied requirement"))

;; C2: evaluate-failure-disposition maps each closed failure category to exactly
;; one disposition, refusing unknown categories. The two conditionally worded
;; table rows (domain-policy-or-invariant, tool-or-environment-fault) resolve to
;; their primary default in the pure policy.
(dolist (pair '((:domain-policy-or-invariant . :propagate-to-test-gate)
                (:application-invariant . :propagate-to-test-gate)
                (:port-callback-fault-or-malformed-return
                 . :normalize-to-refusal-at-callback)
                (:atomic-recording-conflict . :normalize-to-conflict-without-retry)
                (:insufficient-or-stale-evidence . :refuse)
                (:tool-or-environment-fault . :refuse)
                (:review-disagreement . :needs-escalation)
                (:mutation-precondition-mismatch-or-failure
                 . :stop-and-record-evidence))
          pair)
  (let ((category (car pair))
        (disposition (cdr pair)))
    (check (eql disposition
                (hngh.domain:evaluate-failure-disposition category))
           "evaluate-failure-disposition maps a failure category to its disposition")))
(check (signals-error-p
        (lambda () (hngh.domain:evaluate-failure-disposition :unknown)))
       "unknown failure category refuses disposition evaluation")
(check (member
        (hngh.domain:evaluate-failure-disposition :review-disagreement)
        '(:propagate-to-test-gate :typed-domain-refusal
          :normalize-to-refusal-at-callback :normalize-to-conflict-without-retry
          :refuse :needs-escalation :stop-and-record-evidence))
       "evaluate-failure-disposition returns a validated disposition")
