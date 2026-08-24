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

(defun gn-dispatch (argv &key root mutation-ports)
  "Run ARGV through the operator surface with a fixed clock and an
optional injected mutation ports object."
  (let ((*error-output* (make-string-output-stream)))
    (multiple-value-list
     (hngh.main:dispatch-command
      (if root (cons (format nil "--store=~A" root) argv) argv)
      :clock-now #'gn-clock
      :mutation-ports mutation-ports))))

(defun gn-ports ()
  "A fixture mutation ports object; the reporter is discarded."
  (multiple-value-bind (ports reporter)
      (make-mutation-ports-fake)
    (declare (ignore reporter))
    ports))

(defun gn-exit (result)
  (second result))

(defun gn-has (needle result)
  (search needle (first result)))

(defparameter +gn-propose-pieces+
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
    "evidence-trigger=operator"
    "evidence-requirements=closed-authority:claim-proof:fp-1"
    "evidence-requirements=least-authority:claim-proof:fp-2"
    "evidence-requirements=dependency-direction:claim-proof:fp-3"
    "evidence-requirements=fail-closed:claim-proof:fp-4"
    "evidence-requirements=evidence-before-claim:claim-proof:fp-5"
    "evidence-requirements=atomic-mutation:claim-proof:fp-6"
    "evidence-requirements=reversibility:claim-proof:fp-7"
    "evidence-requirements=no-hidden-execution:claim-proof:fp-8"
    "evidence-requirements=cost-and-route-discipline:claim-proof:fp-9"
    "evidence-requirements=source-grounding:claim-proof:fp-10"))

(defparameter +dogfood-refused-pieces+
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
    "evidence-trigger=operator"
    "evidence-requirements=closed-authority:claim-proof:operator-close"))

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
  (let ((result (gn-dispatch (append '("propose") +gn-propose-pieces+)
                             :root root)))
    (check (= 0 (gn-exit result))
           "propose with closed fixture evidence is admitted")
    (check (gn-has "verdict state=admitted" result)
           "admitted verdict renders")
    (check (gn-has "reasons=none" result)
           "admitted verdict carries no refusal reasons"))
  (let ((result (gn-dispatch (append '("propose") +dogfood-refused-pieces+)
                             :root root)))
    (check (= 1 (gn-exit result))
           "propose with partial evidence is refused")
    (check (gn-has "verdict state=refused" result)
           "refused verdict renders")
    (check (gn-has "missing-principle-result" result)
           "refusal labels surface"))
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

;;; issue-cert ------------------------------------------------------------

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let ((result (gn-dispatch '("issue-cert" "stage" "run-1") :root root)))
    (check (= 0 (gn-exit result))
           "issue-cert mints under an admitted run")
    (check (gn-has "certificate action=stage" result)
           "certificate renders"))
  (let ((result (gn-dispatch '("issue-cert" "bogus" "run-1") :root root)))
    (check (= 2 (gn-exit result)) "issue-cert rejects an unknown action"))
  (uiop:delete-directory-tree root :validate t))

;;; issue-cert refuses without admission

(let ((root (gn-dispatch-root)))
  (gn-dispatch (append +create-args+ nil) :root root)
  (let ((result (gn-dispatch '("issue-cert" "stage" "run-1") :root root)))
    (check (= 1 (gn-exit result))
           "issue-cert refuses a run without admission")
    (check (gn-has "not admitted" result)
           "refusal names the missing admission"))
  (uiop:delete-directory-tree root :validate t))

;;; mutation-check ------------------------------------------------------

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let ((result (gn-dispatch '("mutation-check" "stage" "run-1")
                             :root root :mutation-ports (gn-ports))))
    (check (= 0 (gn-exit result))
           "mutation-check executes against fixture evidence")
    (check (gn-has "mutation status=executed" result)
           "executed mutation renders"))
  (let ((result (gn-dispatch '("mutation-check" "stage" "run-1" "stale-a")
                             :root root :mutation-ports (gn-ports))))
    (check (= 1 (gn-exit result)) "mutation-check mismatch exits 1")
    (check (gn-has "mutation status=mismatch" result)
           "mismatch status renders"))
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
         (let ((result (gn-dispatch '("mutation-check" "stage" "run-1")
                                    :root root :mutation-ports (gn-ports))))
           (check (= 0 (gn-exit result))
                  "mutation-check with injected ports executes")
           (check (zerop spawns)
                  "no real subprocess is ever spawned by mutation-check"))
      (setf (symbol-function 'uiop:run-program) original)))
  (uiop:delete-directory-tree root :validate t))

;;; missing runs

(let ((root (gn-dispatch-root)))
  (gn-admitted-run root)
  (let ((result (gn-dispatch '("issue-cert" "stage" "ghost-9") :root root)))
    (check (= 1 (gn-exit result)) "issue-cert reports a missing run"))
  (let ((result (gn-dispatch '("mutation-check" "stage" "ghost-9")
                             :root root :mutation-ports (gn-ports))))
    (check (= 1 (gn-exit result)) "mutation-check reports a missing run"))
  (uiop:delete-directory-tree root :validate t))

(terpri)