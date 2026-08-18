(in-package :hngh.tests)

;;; Rung 5 mutation executor tests. These stay on fixture evidence and a fake
;;; process transport; no test invokes Git or mutates the working tree.

(defun mutation-symbol (name)
  (let ((package (find-package :hngh.adapters.mutation)))
    (unless package
      (error "mutation adapter package is unavailable"))
    (multiple-value-bind (symbol status) (find-symbol name package)
      (unless (and symbol (eq status :external))
        (error "mutation symbol is unavailable: ~A" name))
      symbol)))

(defun mutation-call (name &rest arguments)
  (apply (symbol-function (mutation-symbol name)) arguments))

(defun mutation-value (name)
  (symbol-value (mutation-symbol name)))

(defun mutation-result-status (result)
  (mutation-call "MUTATION-RESULT-STATUS" result))

(defun mutation-result-action (result)
  (mutation-call "MUTATION-RESULT-ACTION" result))

(defun mutation-result-labels (result)
  (mutation-call "MUTATION-RESULT-REFUSAL-LABELS" result))

(defun mutation-result-command (result)
  (mutation-call "MUTATION-RESULT-COMMAND" result))

(defun mutation-result-command-output (result)
  (list (mutation-call "MUTATION-RESULT-EXIT-CODE" result)
        (mutation-call "MUTATION-RESULT-STDOUT" result)
        (mutation-call "MUTATION-RESULT-STDERR" result)))

(defun make-mutation-manifest ()
  (list (hngh.domain:make-source-manifest-entry
         :relative-path "policy.md"
         :content-hash "policy-hash"
         :source-role "policy")))

(defun make-mutation-verdict ()
  (make-fixture-admitted-verdict))

(defun make-mutation-certificate (&key (action :stage)
                                  (repository-identity "repo")
                                  (base-revision "base-1")
                                  (candidate-paths '("src/candidate.lisp"))
                                  (content-hash "content-1")
                                  (evidence-hashes '("evidence-1"))
                                  (principle-verdicts (list (make-mutation-verdict)))
                                  (review-findings '("review-1"))
                                  (source-manifest (make-mutation-manifest))
                                  (policy-profile "profile-1")
                                  (expiry "2026-08-19T00:00:00Z"))
  (hngh.domain:make-candidate-certificate
   :action action
   :repository-identity repository-identity
   :base-revision base-revision
   :candidate-paths candidate-paths
   :content-hash content-hash
   :evidence-hashes evidence-hashes
   :principle-verdicts principle-verdicts
   :review-findings review-findings
   :source-manifest source-manifest
   :policy-profile policy-profile
   :expiry expiry))

(defun make-mutation-evidence (&key
                                 (repository-identity "repo")
                                 (base-revision "base-1")
                                 (candidate-paths '("src/candidate.lisp"))
                                 (content-hash "content-1")
                                 (evidence-hashes '("evidence-1"))
                                 (principle-verdicts (list (make-mutation-verdict)))
                                 (review-findings '("review-1"))
                                 (source-manifest (make-mutation-manifest))
                                 (policy-profile "profile-1")
                                 (now "2026-08-18T00:00:00Z"))
  (mutation-call "MAKE-MUTATION-EVIDENCE"
                 :repository-identity repository-identity
                 :base-revision base-revision
                 :candidate-paths candidate-paths
                 :content-hash content-hash
                 :evidence-hashes evidence-hashes
                 :principle-verdicts principle-verdicts
                 :review-findings review-findings
                 :source-manifest source-manifest
                 :policy-profile policy-profile
                 :now now))

(defun make-mutation-fake (&key (exit-code 0) (stdout "ok\n") (stderr "")
                                fault gather-result)
  (make-mutation-ports-fake :exit-code exit-code :stdout stdout :stderr stderr
                            :fault fault :gather-result gather-result))

(defun execute-mutation-fixture (certificate evidence ports &key action)
  (if action
      (mutation-call "EXECUTE-MUTATION" certificate evidence ports
                     :action action)
      (mutation-call "EXECUTE-MUTATION" certificate evidence ports)))

;;; Closed command vocabulary and action-bound success paths.
(check (equal '(:none :prepare-candidate :stage :commit :push)
              (mutation-value "+MUTATION-ACTIONS+"))
       "mutation action set is fixed and enumerable")

(dolist (action '(:prepare-candidate :stage :commit :push))
  (let* ((certificate (make-mutation-certificate :action action))
         (evidence (make-mutation-evidence))
         (process-fake nil)
         (reporter nil)
         (result nil))
    (multiple-value-setq (process-fake reporter)
      (make-mutation-fake))
    (setf result (execute-mutation-fixture certificate evidence process-fake))
    (check (eq :executed (mutation-result-status result))
           "current certificate executes its named action")
    (check (eql action (mutation-result-action result))
           "execution result preserves the certificate action")
    (check (= 1 (getf (funcall reporter) :calls))
           "accepted mutation invokes transport once")
    (check (equal (first (getf (funcall reporter) :argv-seen))
                  (mutation-result-command result))
           "accepted mutation reports its exact closed command")
    (check
     (equal
      (case action
        ((:prepare-candidate :stage)
         '("git" "add" "--" "src/candidate.lisp"))
        (:commit
         '("git" "commit" "--message" "hngh: candidate content-1" "--"
           "src/candidate.lisp"))
        (:push '("git" "push" "origin" "HEAD")))
      (mutation-result-command result))
     "action uses its fixed argv template")))

;;; :none and action escalation are refused before the transport.
(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter) (make-mutation-fake))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate :action :none)
                 (make-mutation-evidence) process-fake)))
    (check (eq :refused (mutation-result-status result))
           "none action refuses without mutation")
    (check (member "no-op-action" (mutation-result-labels result)
                   :test #'string=)
           "none action names its refusal")
    (check (zerop (getf (funcall reporter) :calls))
           "none action never invokes transport")))

(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter) (make-mutation-fake))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate :action :stage)
                 (make-mutation-evidence) process-fake :action :publish)))
    (check (eq :refused (mutation-result-status result))
           "unsupported requested action refuses")
    (check (member "unsupported-action" (mutation-result-labels result)
                   :test #'string=)
           "unsupported requested action names its refusal")
    (check (zerop (getf (funcall reporter) :calls))
           "unsupported requested action never invokes transport")))

(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter) (make-mutation-fake))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate :action :stage)
                 (make-mutation-evidence) process-fake :action :commit)))
    (check (eq :refused (mutation-result-status result))
           "certificate cannot escalate to another action")
    (check (member "unauthorized-action" (mutation-result-labels result)
                   :test #'string=)
           "action escalation names its refusal")
    (check (zerop (getf (funcall reporter) :calls))
           "action escalation never invokes transport")))

;;; Every bound certificate fact is checked at the point of action.
(dolist (case '((:base-revision "changed" "base-revision-mismatch")
                (:content-hash "changed" "content-hash-mismatch")
                (:candidate-paths ("src/other.lisp") "candidate-paths-mismatch")
                (:repository-identity "other-repository" "repository-identity-mismatch")
                (:evidence-hashes ("other-evidence") "evidence-hashes-mismatch")
                (:policy-profile "other-profile" "policy-profile-mismatch")
                (:review-findings ("other-review") "review-findings-mismatch")
                (:source-manifest :different-manifest "source-manifest-mismatch")))
  (destructuring-bind (slot value label) case
    (let ((certificate (make-mutation-certificate))
          (evidence (make-mutation-evidence)))
      (let ((arguments (list :repository-identity "repo"
                             :base-revision "base-1"
                             :candidate-paths '("src/candidate.lisp")
                             :content-hash "content-1"
                             :evidence-hashes '("evidence-1")
                             :principle-verdicts (list (make-mutation-verdict))
                             :review-findings '("review-1")
                             :source-manifest (make-mutation-manifest)
                             :policy-profile "profile-1"
                             :now "2026-08-18T00:00:00Z")))
        (setf (getf arguments slot)
              (if (eql slot :source-manifest)
                  (list (hngh.domain:make-source-manifest-entry
                         :relative-path "other-policy.md"
                         :content-hash "other-policy-hash"
                         :source-role "policy"))
                  value))
        (setf evidence (apply #'make-mutation-evidence arguments)))
      (multiple-value-bind (process-fake reporter) (make-mutation-fake)
        (declare (ignore reporter))
        (let ((result (execute-mutation-fixture certificate evidence process-fake)))
          (check (eq :mismatch (mutation-result-status result))
                 "changed certificate fact refuses as a mismatch")
          (check (member label (mutation-result-labels result) :test #'string=)
                 "changed certificate fact names its mismatch"))))))

(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter) (make-mutation-fake))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate)
                 (make-mutation-evidence :now "2026-08-20T00:00:00Z")
                 process-fake)))
    (check (eq :refused (mutation-result-status result))
           "expired certificate refuses")
    (check (member "expired-certificate" (mutation-result-labels result)
                   :test #'string=)
           "expired certificate names its refusal")
    (check (zerop (getf (funcall reporter) :calls))
           "expired certificate never invokes transport")))

(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter) (make-mutation-fake))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate)
                 (make-mutation-evidence :principle-verdicts nil)
                 process-fake)))
    (check (eq :refused (mutation-result-status result))
           "missing principle verdict refuses")
    (check (member "missing-principle-verdict" (mutation-result-labels result)
                   :test #'string=)
           "missing principle verdict names its refusal")
    (check (zerop (getf (funcall reporter) :calls))
           "missing verdict never invokes transport")))

;;; Command and transport failures are typed and carry no success result.
(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter)
    (make-mutation-fake :exit-code 1 :stdout "" :stderr "rejected"))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate) (make-mutation-evidence)
                 process-fake)))
    (check (eq :command-failed (mutation-result-status result))
           "nonzero command result refuses as command failure")
    (check (equal '(1 "" "rejected") (mutation-result-command-output result))
           "command failure preserves bounded process output")
    (check (= 1 (getf (funcall reporter) :calls))
           "command failure invokes only the named command")))

(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter) (make-mutation-fake :fault t))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate) (make-mutation-evidence)
                 process-fake)))
    (check (eq :transport-fault (mutation-result-status result))
           "transport fault refuses closed")
    (check (member "transport-fault" (mutation-result-labels result)
                   :test #'string=)
           "transport fault names its refusal")
    (check (= 1 (getf (funcall reporter) :calls))
           "transport fault is observed once")))

(let* ((calls 0)
       (ports
        (mutation-call
         "MAKE-MUTATION-PORTS"
         :run-process
         (lambda (argv)
           (declare (ignore argv))
           (incf calls)
           (values nil nil nil)))))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate)
                 (make-mutation-evidence) ports)))
    (check (eq :transport-fault (mutation-result-status result))
           "malformed transport return refuses closed")
    (check (= 1 calls)
           "malformed transport return is observed once")))

(let ((result (execute-mutation-fixture nil nil nil)))
  (check (eq :refused (mutation-result-status result))
         "malformed executor input refuses closed")
  (check (member "malformed-input" (mutation-result-labels result)
                 :test #'string=)
         "malformed executor input names its refusal"))

(let ((process-fake nil) (reporter nil))
  (multiple-value-setq (process-fake reporter)
    (make-mutation-fake :gather-result (make-mutation-evidence)))
  (let ((result (execute-mutation-fixture
                 (make-mutation-certificate) nil process-fake)))
    (check (eq :executed (mutation-result-status result))
           "executor can gather fresh evidence through its port")
    (check (= 1 (getf (funcall reporter) :calls))
           "gathered evidence still invokes only the mutation command")))
