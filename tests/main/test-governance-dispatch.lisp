;;;; tests/main/test-governance-dispatch.lisp
;;;; Operator command surface for the governance pipeline: propose
;;;; (form proposal -> policy verdict), issue-cert (admitted verdict ->
;;;; candidate certificate), mutation-check (certificate + fresh evidence
;;;; -> executed/mismatch through injected fixture ports).
;;;; Conventions mirror test-dispatch.lisp; nothing here spawns processes.

(in-package #:hngh.tests)

(defun gn-dispatch-root ()
  "A fresh scratch store root."
  (let ((path (uiop:with-temporary-file (:pathname path :keep t)
                (delete-file path)
                (ensure-directories-exist (uiop:ensure-directory-pathname path)))))
    path))

(defun gn-clock ()
  "2026-08-24T00:00:00Z")

(defun gn-dispatch (argv &key root mutation-ports gather-ports
                        review-ports terminal-ports)
  "Run ARGV through the operator surface with a fixed clock and
optional injected mutation, candidate-evidence, review, and terminal ports."
  (let ((*error-output* (make-string-output-stream)))
    (multiple-value-list
     (hngh.main:dispatch-command
      (if root (cons (format nil "--store=~A" root) argv) argv)
      :clock-now #'gn-clock
      :mutation-ports mutation-ports
      :gather-ports gather-ports
      :review-ports review-ports
      :terminal-ports terminal-ports))))

(defun gn-ports ()
  "A fixture mutation ports object; the reporter is discarded."
  (multiple-value-bind (ports reporter)
      (make-mutation-ports-fake)
    (declare (ignore reporter))
    ports))

(defun gn-verdict (kind)
  "A temporary verdict report path in the two-line form: \"admitted\",
\"refused\", or anything else for a malformed file."
  (uiop:with-temporary-file (:pathname path :keep t)
    (with-open-file (stream path :direction :output :if-exists :supersede)
      (cond ((string= kind "admitted")
             (format stream
                     (concatenate
                      'string
                      "verdict state=admitted principles="
                      "closed-authority:passed,least-authority:passed,"
                      "dependency-direction:passed,fail-closed:passed,"
                      "evidence-before-claim:passed,atomic-mutation:passed,"
                      "reversibility:passed,no-hidden-execution:passed,"
                      "cost-and-route-discipline:passed,source-grounding:passed"
                      "~%evidence=2 findings=0 hash=~A~%")
                     (make-string 64 :initial-element #\b)))
            ((string= kind "refused")
             (format stream
                     (concatenate
                      'string
                      "verdict state=refused principles="
                      "closed-authority:passed,least-authority:passed,"
                      "dependency-direction:passed,fail-closed:refused,"
                      "evidence-before-claim:passed,atomic-mutation:passed,"
                      "reversibility:passed,no-hidden-execution:passed,"
                      "cost-and-route-discipline:passed,source-grounding:passed"
                      "~%evidence=2 findings=0 hash=~A~%")
                     (make-string 64 :initial-element #\b)))
            (t (format stream "not a verdict report~%"))))
    (namestring path)))

(defun gn-gather ()
  "A fixture candidate-evidence transport: mocks git identity, sha256
subprocesses, and the verify-candidate closed report."
  (hngh.adapters.run-gather::make-candidate-gather-ports
   :process-run
   (lambda (cwd argv)
     (declare (ignore cwd))
     (cond ((string= (first argv) "git")
            (values 0 (format nil "https://example.invalid/repo~%") ""))
           ((and (third argv) (search "hashlib" (third argv)))
            (values 0 (format nil "~A~%"
                              "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
                    ""))
           (t
            (values 0
                    (format nil "base-revision:0123456789abcdef0123456789abcdef01234567~%candidate-hash:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa~%working-tree-dirty:no~%working-tree-staged:no~%working-tree-untracked:no~%parenthesis-guard:passed~%manifest:candidate.lisp~%:passed~%")
                    ""))))))

(defun gn-exit (result)
  (second result))

(defun gn-has (needle result)
  (search needle (first result)))

(defparameter +gn-principle-names+
  '("closed-authority" "least-authority" "dependency-direction" "fail-closed"
    "evidence-before-claim" "atomic-mutation" "reversibility"
    "no-hidden-execution" "cost-and-route-discipline" "source-grounding"))

(defparameter +gn-matrix+
  '(("closed-authority" "purpose") ("closed-authority" "caller")
    ("closed-authority" "input-contract") ("closed-authority" "output-contract")
    ("closed-authority" "failure-contract") ("least-authority" "capability-set")
    ("least-authority" "capability-diff") ("dependency-direction" "static-source")
    ("fail-closed" "closed-failure-disposition")
    ("evidence-before-claim" "claim-proof") ("atomic-mutation" "base-revision")
    ("atomic-mutation" "candidate-manifest") ("atomic-mutation" "content-hash")
    ("reversibility" "reversion-or-containment")
    ("no-hidden-execution" "component-import")
    ("cost-and-route-discipline" "route") ("cost-and-route-discipline" "budget")
    ("cost-and-route-discipline" "token-limit")
    ("cost-and-route-discipline" "expiry") ("source-grounding" "source-manifest")
    ("source-grounding" "conclusion-link"))
  "The closed evidence matrix: twenty-one requirement kinds over the
ten principles.")

(defun gn-fp (index)
  "A deterministic 64-hex-lowercase fingerprint."
  (format nil "~(~64,'0X~)" index))

(defun gn-matrix-pieces (&key drop swap)
  "The twenty-one requirement+fact argv pieces. DROP names a P:K pair
whose fact is left unsupplied; SWAP names a P:K pair whose fact is
supplied under \"fail-closed\" instead (cross-principle supply)."
  (loop for (principle kind) in +gn-matrix+
        for index from 1
        for fp = (gn-fp index)
        for pair = (format nil "~A:~A" principle kind)
        append (list (format nil "evidence-requirements=~A:~A:~A"
                             principle kind fp))
        unless (equal pair drop)
          append (list (format nil "evidence-fact=~A:~A:~A"
                               (if (equal pair swap) "fail-closed" principle)
                               kind fp))))

(defun gn-finding (principle text cite)
  "One findings argv piece: <principle><TAB><text><TAB><cite>."
  (format nil "review-findings=~A~A~A~A~A" principle (string #\Tab) text
          (string #\Tab) cite))

(defparameter +gn-propose-base+
  (append
   '("class=feature"
    "problem=the operator surface is unreachable"
    "outcome=governance commands land"
    "purpose=dogfood the governance loop"
    "caller=operator"
    "input-contract=operator flags"
    "output-contract=verdict certificate mutation"
    "failure-contract=refusal labels"
    "declared-capabilities=propose,issue-cert,mutation-check"
    "capability-diff=none"
    "source-manifest=policy.md=hash-0:source"
    "risk-note=none"
    "dependency=domain"
    "evidence-trigger=operator")
   (list (format nil "content-hash=~A" (gn-fp 255))))
  "The proposal declarations plus content-hash; each case supplies its
own facts.")

(defparameter +gn-propose-pieces+
  (append +gn-propose-base+ (gn-matrix-pieces))
  "The twenty-one real facts fixture: every closed-matrix requirement
carries exactly one supplied fact.")

(defparameter +dogfood-refused-pieces+
  (append
   '("class=feature"
     "problem=operator close"
     "outcome=terminal state"
     "purpose=close the run"
     "caller=operator"
     "input-contract=run"
     "output-contract=state"
     "failure-contract=refusal"
     "declared-capabilities=close-run"
     "capability-diff=none"
     "source-manifest=operator-close.md=operator-close:surface"
     "risk-note=none"
     "dependency=domain"
     "evidence-trigger=operator")
   (list (format nil "content-hash=~A" (gn-fp 254))
         (format nil "evidence-requirements=closed-authority:claim-proof:~A"
                 (gn-fp 253))))
  "A proposal whose one requirement is never supplied a fact: it refuses.")

(defparameter +model-create-args+
  '("create-run" "Create a valid run" "builder"
    "loadout-route-label=model" "loadout-context-limit=1" "loadout-token-limit=2"
    "loadout-cost-limit=3" "loadout-time-limit=4" "loadout-tool-labels=make-test"
    "loadout-network-labels=model-review" "loadout-writable-scopes=repository"))

(defparameter +terminal-create-args+
  '("create-run" "Create a valid run" "builder"
    "loadout-route-label=local" "loadout-context-limit=1" "loadout-token-limit=2"
    "loadout-cost-limit=3" "loadout-time-limit=4"
    "loadout-tool-labels=make-test/terminal-input"
    "loadout-network-labels=none" "loadout-writable-scopes=repository"))

(defun gn-review-ports ()
  "A fixture model-review ports object; the reporter is discarded."
  (multiple-value-bind (ports reporter)
      (make-review-ports-fake
       :responses (list (list :return 0
                              "{\"findings\":[{\"label\":\"ok\",\"citation\":\"src/a.lisp\"}]}"
                              "")))
    (declare (ignore reporter))
    ports))

(defun gn-terminal-ports ()
  "A fixture operator statement ports object; the reporter is discarded."
  (multiple-value-bind (ports reporter)
      (make-operator-ports-fake :responses (list (list :return "operator statement")))
    (declare (ignore reporter))
    ports))

(defun gn-admitted-run (root)
  "Drive a run to admitted state under ROOT and return its identifier."
  (let ((result (gn-dispatch (append +create-args+ nil) :root root)))
    (check (= 0 (gn-exit result)) "create-run accepts under dogfood root"))
  (let ((result (gn-dispatch
                 '("admit-transport" "run-1" "filesystem" "repository")
                 :root root)))
    (check (= 0 (gn-exit result)) "admit-transport accepts")
    "run-1"))

;;; propose ---------------------------------------------------------------

(let ((root (gn-dispatch-root)))
  ;; (i) propose with twenty-one real facts -> all ten principles pass
  (let ((result (gn-dispatch (append '("propose") +gn-propose-pieces+)
                             :root root)))
    (check (= 0 (gn-exit result))
           "(i) propose with twenty-one real facts is admitted")
    (check (gn-has "verdict state=admitted" result)
           "admitted verdict renders")
    (check (gn-has "closed-authority:passed" result)
           "the closed-authority pair renders passed")
    (check (gn-has "source-grounding:passed" result)
           "the source-grounding pair renders passed")
    (check (null (hngh.domain:policy-verdict-reason-labels (third result)))
           "admitted verdict carries no refusal reasons"))
  ;; (ii) one requirement's fact missing -> that principle refuses
  (let ((result (gn-dispatch
                 (append '("propose") +gn-propose-base+
                         (gn-matrix-pieces :drop "least-authority:capability-set"))
                 :root root)))
    (check (= 1 (gn-exit result))
           "(ii) a missing fact refuses its principle")
    (check (gn-has "verdict state=refused" result)
           "refused verdict renders")
    (check (gn-has "least-authority:refused" result)
           "the least-authority pair renders refused")
    (check (member "missing-evidence"
                   (hngh.domain:policy-verdict-reason-labels (third result))
                   :test #'string=)
           "the refusal labels the missing evidence"))
  ;; (iii) a fact under the wrong principle cannot satisfy a requirement
  (let ((result (gn-dispatch
                 (append '("propose") +gn-propose-base+
                         (gn-matrix-pieces :swap "least-authority:capability-set"))
                 :root root)))
    (check (= 1 (gn-exit result))
           "(iii) a fact under the wrong principle refuses")
    (check (gn-has "least-authority:refused" result)
           "the cross-supplied principle renders refused"))
  (let ((result (gn-dispatch (append '("propose") +dogfood-refused-pieces+)
                             :root root)))
    (check (= 1 (gn-exit result))
           "propose with partial evidence is refused")
    (check (gn-has "verdict state=refused" result)
           "refused verdict renders")
    (check (member "missing-principle-result"
                   (hngh.domain:policy-verdict-reason-labels (third result))
                   :test #'string=)
           "refusal labels surface"))
  ;; (iv) an unknown kind or a non-sha256 fingerprint refuses
  (dolist (piece (list (format nil "evidence-fact=closed-authority:bogus:~A"
                               (gn-fp 1))
                       "evidence-fact=closed-authority:claim-proof:not-a-sha256"
                       "evidence-requirements=closed-authority:claim-proof:short"))
    (let ((result (gn-dispatch (append '("propose") +gn-propose-pieces+
                                       (list piece))
                               :root root)))
      (check (= 2 (gn-exit result))
             "(iv) an unknown kind or bad fingerprint exits 2")))
  ;; review findings ride the proposal as bounded data
  (let ((result (gn-dispatch
                 (append '("propose") +gn-propose-pieces+
                         (list (gn-finding "closed-authority"
                                           "risk p=0.80: scope unclear"
                                           "candidate.lisp")
                               (gn-finding "fail-closed"
                                           "risk p=0.75: refusal unproven"
                                           "candidate.lisp")))
                 :root root)))
    (check (= 0 (gn-exit result)) "review findings ride the proposal")
    (check (gn-has "findings=2" result) "the verdict counts the findings")
    (check (= 2 (length (hngh.domain::policy-verdict-review-findings
                         (third result))))
           "the verdict carries the findings rows"))
  ;; more than 32 findings refuse; duplicate rows refuse
  (let ((result (gn-dispatch
                 (append '("propose") +gn-propose-pieces+
                         (loop for n from 1 to 33
                               collect (gn-finding "fail-closed"
                                                   (format nil "risk row ~D" n)
                                                   "candidate.lisp")))
                 :root root)))
    (check (= 2 (gn-exit result)) "more than 32 findings exit 2"))
  (let ((result (gn-dispatch
                 (append '("propose") +gn-propose-pieces+
                         (list (gn-finding "fail-closed" "same row"
                                           "candidate.lisp")
                               (gn-finding "fail-closed" "same row"
                                           "candidate.lisp")))
                 :root root)))
    (check (= 2 (gn-exit result)) "duplicate findings exit 2"))
  (dolist (args '(("propose")
                  ("propose" "class=feature")))
    (let ((result (gn-dispatch args :root root)))
      (check (= 2 (gn-exit result))
             "propose with missing fields exits 2")))
  (let ((result (gn-dispatch (append '("propose")
                                     +dogfood-refused-pieces+
                                     '("bogus=1"))
                             :root root)))
    (check (= 2 (gn-exit result)) "unknown propose key exits 2"))
  (uiop:delete-directory-tree root :validate t))


;;; mutation-check: the single mint+execute verb --------------------------

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let ((result (gn-dispatch '("mutation-check" "stage" "run-1")
                             :root root :mutation-ports (gn-ports))))
    (check (= 1 (gn-exit result))
           "mutation-check refuses without an operator verdict")
    (check (gn-has "missing-verdict-evidence" result)
           "refusal names the missing verdict evidence"))
  (let ((result (gn-dispatch '("mutation-check" "bogus" "run-1") :root root)))
    (check (= 2 (gn-exit result)) "mutation-check rejects an unknown action"))
  (uiop:delete-directory-tree root :validate t))

;;; mutation-check refuses without admission

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +create-args+ nil) :root root)
  (let ((result (gn-dispatch '("mutation-check" "stage" "run-1")
                             :root root :mutation-ports (gn-ports))))
    (check (= 1 (gn-exit result))
           "mutation-check refuses a run without admission")
    (check (gn-has "not admitted" result)
           "refusal names the missing admission"))
  (uiop:delete-directory-tree root :validate t))

;;; mutation-check ------------------------------------------------------

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let ((result (gn-dispatch '("mutation-check" "stage" "run-1" "stale-a")
                             :root root :mutation-ports (gn-ports))))
    (check (= 1 (gn-exit result))
           "mutation-check refuses a missing verdict file")
    (check (gn-has "missing-verdict-file" result)
           "refusal names the missing verdict file"))
  (uiop:delete-directory-tree root :validate t))

;;; mutation-check never spawns a subprocess

(let ((root (gn-dispatch-root))
      (spawns 0))
  (gn-admitted-run root)
  (let ((original (symbol-function 'uiop:run-program)))
    (setf (symbol-function 'uiop:run-program)
          (lambda (&rest args)
            (declare (ignore args))
            (incf spawns)))
    (unwind-protect
         (let ((result (gn-dispatch
                        (list "mutation-check" "stage" "run-1"
                              (gn-verdict "admitted"))
                        :root root :mutation-ports (gn-ports)
                        :gather-ports (gn-gather))))
           (check (= 0 (gn-exit result))
                  "mutation-check with injected ports executes")
           (check (zerop spawns)
                  "no real subprocess is ever spawned by mutation-check"))
      (setf (symbol-function 'uiop:run-program) original)))
  (uiop:delete-directory-tree root :validate t))

;;; missing runs

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let ((result (gn-dispatch (list "mutation-check" "stage" "ghost-9"
                                   (gn-verdict "admitted"))
                             :root root :mutation-ports (gn-ports))))
    (check (= 1 (gn-exit result))
           "mutation-check reports a missing run with a verdict"))
  (let ((result (gn-dispatch '("mutation-check" "stage" "ghost-9")
                             :root root :mutation-ports (gn-ports))))
    (check (= 1 (gn-exit result)) "mutation-check reports a missing run"))
  (uiop:delete-directory-tree root :validate t))



;;; mutation-check real evidence chain: mint+execute only from an
;;; operator verdict file and a genuine gather ---------------------

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let* ((verdict-file (gn-verdict "admitted"))
         (result (gn-dispatch
                  (list "mutation-check" "prepare-candidate" "run-1"
                        verdict-file)
                  :root root :mutation-ports (gn-ports)
                  :gather-ports (gn-gather))))
    (check (= 0 (gn-exit result))
           "mutation-check mints and executes from an operator verdict file")
    (check (gn-has "mutation status=executed" result)
           "the merged verb renders the executed mutation"))
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let* ((verdict-file (gn-verdict "refused"))
         (result (gn-dispatch (list "mutation-check" "stage" "run-1"
                                    verdict-file)
                              :root root :mutation-ports (gn-ports)
                              :gather-ports (gn-gather))))
    (check (= 1 (gn-exit result))
           "mutation-check refuses an unadmitted verdict file")
    (check (gn-has "unadmitted-verdict" result)
           "refusal names the unadmitted verdict"))
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let* ((verdict-file (gn-verdict "malformed"))
         (result (gn-dispatch (list "mutation-check" "stage" "run-1"
                                    verdict-file)
                              :root root :mutation-ports (gn-ports)
                              :gather-ports (gn-gather))))
    (check (= 1 (gn-exit result))
           "mutation-check refuses a malformed verdict file")
    (check (gn-has "malformed-verdict-evidence" result)
           "refusal names the malformed verdict evidence"))
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let ((result (gn-dispatch (list "mutation-check" "stage" "run-1" (gn-verdict "admitted"))
                             :root root :mutation-ports (gn-ports)
                             :gather-ports (gn-gather))))
    (check (= 0 (gn-exit result))
           "mutation-check executes on real evidence")
    (check (gn-has "mutation status=executed" result)
           "real-path mutation renders"))
  (uiop:delete-directory-tree root :validate t))

;;; review findings ride the verdict into the certificate ----------------

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let* ((proposed (gn-dispatch
                    (append '("propose") +gn-propose-pieces+
                            (list (gn-finding "closed-authority"
                                              "risk p=0.80: scope unclear"
                                              "candidate.lisp")
                                  (gn-finding "fail-closed"
                                              "risk p=0.75: refusal unproven"
                                              "candidate.lisp")))
                    :root root))
         (verdict (third proposed))
         (result (gn-dispatch
                  (list "mutation-check" "prepare-candidate" "run-1" verdict)
                  :root root :mutation-ports (gn-ports)
                  :gather-ports (gn-gather))))
    (check (= 0 (gn-exit proposed)) "the proposal carries bounded findings")
    (check (gn-has "findings=2" proposed)
           "the proposed verdict counts the findings")
    (check (= 2 (length (hngh.domain::policy-verdict-review-findings verdict)))
           "the proposed verdict carries the findings rows")
    (check (= 0 (gn-exit result))
           "mutation-check executes over the findings-carrying verdict")
    (check (gn-has "mutation status=executed" result)
           "the findings-carrying mutation renders"))
  (uiop:delete-directory-tree root :validate t))

;;; review and terminal: bounded worker transports -----------------------

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +model-create-args+ nil) :root root)
  (let ((result (gn-dispatch '("admit-transport" "run-1" "model" "repository")
                             :root root)))
    (check (= 0 (gn-exit result))
           "admit-transport accepts the model transport on a model loadout"))
  (let ((result (gn-dispatch '("review" "run-1" "content-hash=hash-1"
                               "paths=src/a.lisp")
                             :root root :review-ports (gn-review-ports))))
    (check (= 0 (gn-exit result))
           "review runs through the injected fake ports")
    (check (gn-has "review status=complete" result)
           "review renders the complete review result")
    (check (gn-has "finding label=ok" result)
           "review renders the provider finding"))
  (let ((result (gn-dispatch '("review" "run-1")
                             :root root :review-ports (gn-review-ports))))
    (check (= 2 (gn-exit result))
           "review without content-hash and paths is malformed"))
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +model-create-args+ nil) :root root)
  (gn-dispatch '("admit-transport" "run-1" "model" "repository") :root root)
  (let ((result (gn-dispatch '("review" "run-1" "content-hash=abc"
                               "paths=src/a.lisp")
                             :root root)))
    (check (= 1 (gn-exit result))
           "review without injected ports refuses")
    (check (gn-has "no-review-transport" result)
           "review refusal names no-review-transport"))
  (let ((result (gn-dispatch '("review" "run-1" "content-hash=abc"
                               "paths=src/a.lisp")
                             :root root :review-ports nil)))
    (check (= 1 (gn-exit result))
           "review with nil ports refuses no-review-transport"))
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +create-args+ nil) :root root)
  (let ((result (gn-dispatch '("review" "run-1" "content-hash=abc"
                               "paths=src/a.lisp")
                             :root root :review-ports (gn-review-ports))))
    (check (= 1 (gn-exit result))
           "review refuses a run without a model admission receipt")
    (check (gn-has "not admitted for model" result)
           "review refusal names the missing model admission"))
  (let ((result (gn-dispatch '("admit-transport" "run-1" "model" "repository")
                             :root root)))
    (check (= 1 (gn-exit result))
           "admit-transport refuses model on a plain loadout")
    (check (gn-has "loadout-refuses-transport" result)
           "the loadout refusal carries its closed label"))
  (uiop:delete-directory-tree root :validate t))

;;; the admitted transport set stays closed: model outside refuses ------------

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +model-create-args+ nil) :root root)
  (let ((hngh.domain:+admitted-transports+ '(:filesystem)))
    (let ((result (gn-dispatch '("admit-transport" "run-1" "model" "repository")
                               :root root)))
      (check (= 2 (gn-exit result))
             "a transport outside the admitted set exits 2")
      (check (gn-has "unknown-transport" result)
             "the closed-set refusal names unknown-transport")))
  (let ((hngh.domain:+admitted-transports+ '(:filesystem)))
    (let ((result (gn-dispatch '("admit-transport" "run-1" "terminal" "repository")
                               :root root)))
      (check (= 2 (gn-exit result))
             "a terminal outside the admitted set exits 2")))
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +terminal-create-args+ nil) :root root)
  (let ((result (gn-dispatch '("admit-transport" "run-1" "terminal" "repository")
                             :root root)))
    (check (= 0 (gn-exit result))
           "admit-transport accepts the terminal transport on a terminal load"))
  (let ((result (gn-dispatch '("terminal" "run-1")
                             :root root :terminal-ports (gn-terminal-ports))))
    (check (= 0 (gn-exit result))
           "terminal capture runs through the injected fake ports")
    (check (gn-has "operator status=complete" result)
           "terminal capture renders the operator result")
    (check (gn-has "sha256:" result)
           "terminal capture renders the fingerprint binding"))
  (let ((result (gn-dispatch '("terminal" "run-1") :root root)))
    (check (= 1 (gn-exit result))
           "terminal without injected ports refuses")
    (check (gn-has "no-terminal-transport" result)
           "terminal refusal names no-terminal-transport"))
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +terminal-create-args+ nil) :root root)
  (let ((result (gn-dispatch '("terminal" "run-1")
                             :root root :terminal-ports (gn-terminal-ports))))
    (check (= 1 (gn-exit result))
           "terminal capture refuses a run without a terminal receipt")
    (check (gn-has "not admitted for terminal" result)
           "terminal refusal names the missing terminal admission"))
  (uiop:delete-directory-tree root :validate t))

;;; review and terminal never spawn a subprocess with injected ports -------

(let ((root (gn-dispatch-root))
      (spawns 0))
  (gn-dispatch (append +model-create-args+ nil) :root root)
  (gn-dispatch '("admit-transport" "run-1" "model" "repository") :root root)
  (let ((original (symbol-function 'uiop:run-program)))
    (setf (symbol-function 'uiop:run-program)
          (lambda (&rest args)
            (declare (ignore args))
            (incf spawns)))
    (unwind-protect
         (let ((result (gn-dispatch '("review" "run-1" "content-hash=abc"
                                      "paths=src/a.lisp")
                                    :root root :review-ports (gn-review-ports))))
           (check (= 0 (gn-exit result))
                  "review with injected ports completes"))
      (setf (symbol-function 'uiop:run-program) original)))
  (check (zerop spawns)
         "no real subprocess is spawned by the review command")
  (uiop:delete-directory-tree root :validate t))

(let ((root (gn-dispatch-root))
      (spawns 0))
  (gn-dispatch (append +terminal-create-args+ nil) :root root)
  (gn-dispatch '("admit-transport" "run-1" "terminal" "repository") :root root)
  (let ((original (symbol-function 'uiop:run-program)))
    (setf (symbol-function 'uiop:run-program)
          (lambda (&rest args)
            (declare (ignore args))
            (incf spawns)))
    (unwind-protect
         (let ((result (gn-dispatch '("terminal" "run-1")
                                    :root root :terminal-ports (gn-terminal-ports))))
           (check (= 0 (gn-exit result))
                  "terminal capture with injected ports completes"))
      (setf (symbol-function 'uiop:run-program) original)))
  (check (zerop spawns)
         "no real subprocess is spawned by the terminal command")
  (uiop:delete-directory-tree root :validate t))

(terpri)

;;; reviewer transport admission -------------------------------------------
;;; review RUN ... reviewer=PATH admits an operator reviewer-transport file
;;; (endpoint/model/max-tokens/timeout/token-file); the file is validated
;;; before any run or transport work.

(defun gn-reviewer-file (contents)
  "Write CONTENTS to a kept temp file; returns its namestring."
  (uiop:with-temporary-file (:pathname path :keep t)
    (with-open-file (stream path :direction :output :if-exists :supersede)
      (write-string contents stream))
    (namestring path)))

(defparameter +gn-valid-reviewer+
  (concatenate 'string
               "endpoint=http://127.0.0.1:1/v1/chat/completions" '(#\Newline)
               "model=test/model" '(#\Newline)
               "max-tokens=512" '(#\Newline)
               "timeout=60" '(#\Newline)
               "token-file=/tmp/hngh-missing-token"))

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +model-create-args+ nil) :root root)
  (gn-dispatch '("admit-transport" "run-1" "model" "repository") :root root)
  (let ((result (gn-dispatch (list "review" "run-1" "content-hash=abc"
                                   "paths=src/a.lisp"
                                   "reviewer=/tmp/hngh-missing-reviewer.conf")
                             :root root)))
    (check (= 2 (gn-exit result))
           "a missing reviewer file is a malformed invocation")
    (check (gn-has "cannot read reviewer file" result)
           "the refusal names the unreadable reviewer file"))
  (let ((result (gn-dispatch (list "review" "run-1" "content-hash=abc"
                                   "paths=src/a.lisp"
                                   (format nil "reviewer=~A"
                                           (gn-reviewer-file +gn-valid-reviewer+)))
                             :root root)))
    (check (= 2 (gn-exit result))
           "a reviewer file whose token file is missing is malformed")
    (check (gn-has "cannot read reviewer file" result)
           "the refusal names the unreadable token file"))
  (dolist (bad (list
                ;; missing required keys
                "endpoint=http://127.0.0.1:1/v1/chat/completions"
                ;; unknown key
                (concatenate 'string +gn-valid-reviewer+ '(#\Newline) "extra=1")
                ;; duplicate key
                (concatenate 'string +gn-valid-reviewer+ '(#\Newline)
                             "timeout=90")
                ;; non-integer numeric field
                (concatenate 'string
                             "endpoint=http://127.0.0.1:1/v1/chat/completions" '(#\Newline)
                             "model=test/model" '(#\Newline)
                             "max-tokens=abc" '(#\Newline)
                             "timeout=60" '(#\Newline)
                             "token-file=/tmp/hngh-missing-token")
                ;; line without =
                (concatenate 'string +gn-valid-reviewer+ '(#\Newline) "endpoint")
                ;; empty value
                (concatenate 'string +gn-valid-reviewer+ '(#\Newline) "model=")))
    (let ((result (gn-dispatch (list "review" "run-1" "content-hash=abc"
                                     "paths=src/a.lisp"
                                     (format nil "reviewer=~A"
                                             (gn-reviewer-file bad)))
                               :root root)))
      (check (= 2 (gn-exit result))
             (format nil "malformed reviewer file refuses: ~S"
                     (subseq bad 0 (min 40 (length bad)))))
      (check (gn-has "malformed reviewer file" result)
             "the refusal names the malformed reviewer file")))
  (uiop:delete-directory-tree root :validate t))
;;; propose profile=FILE: the profile narrows, never broadens --------------

(defun gn-write-profile (contents)
  "A temporary profile file carrying CONTENTS; returns its namestring."
  (let* ((directory (uiop:temporary-directory))
         (path (uiop:native-namestring
                (merge-pathnames
                 (make-pathname :name (format nil "gn-profile-~A"
                                              (gensym "p"))
                                :type "txt")
                 directory))))
    (with-open-file (stream path :direction :output :if-exists :supersede)
      (write-string contents stream))
    path))

(defun gn-propose-with-profile (root profile-path review-p)
  "The ten-principle fixture proposal; source-grounding uses :review
when REVIEW-P and :claim-proof otherwise, each with its matching fact."
  (let ((pieces
          (append (list "propose")
                  +gn-propose-base+
                  (loop for principle in +gn-principle-names+
                        for index from 401
                        for fp = (gn-fp index)
                        for use-kind = (if (string= principle
                                                     "source-grounding")
                                           (if review-p "review" "claim-proof")
                                           "claim-proof")
                        append (list (format nil "evidence-requirements=~A:~A:~A"
                                             principle use-kind fp)
                                     (format nil "evidence-fact=~A:~A:~A"
                                             principle use-kind fp)))
                  (list (format nil "profile=~A" profile-path)))))
    (gn-dispatch pieces :root root)))

(let ((root (gn-dispatch-root))
      (profile (gn-write-profile
                (concatenate 'string "source-grounding"
                             (string #\Tab) "review"))))
  (let ((result (gn-propose-with-profile root profile nil)))
    (check (= 1 (gn-exit result))
           "a review-only profile refuses a claim-proof proposal")
    (check (member "missing-principle-result"
                   (hngh.domain:policy-verdict-reason-labels (third result))
                   :test #'string=)
           "the refusal names the missing principle result"))
  (let ((result (gn-propose-with-profile root profile t)))
    (check (= 0 (gn-exit result))
           "a review profile admits a proposal carrying review evidence")
    (check (gn-has "verdict state=admitted" result)
           "the admitted verdict renders"))
  (let* ((path (gn-write-profile
                (concatenate 'string "source-grounding"
                             (string #\Tab) "bogus")))
         (result (gn-dispatch (append '("propose") +gn-propose-pieces+
                                      (list (format nil "profile=~A" path)))
                              :root root)))
    (check (= 2 (gn-exit result))
           "a malformed profile file is a malformed invocation"))
  (uiop:delete-directory-tree root :validate t))
