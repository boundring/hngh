(in-package #:hngh.tests)

;;; Rung 8: operator command surface. DISPATCH-COMMAND is the closed,
;;; process-local entry point returning (values output exit-code) per the
;;; design contract. The vertical slice drives the whole lifecycle
;;; in-process under a temp --store root; refusals keep literal labels,
;;; malformed invocations exit 2, transport faults exit 3, and nothing
;;; persists without an operator-named store.

(defun dispatch-root ()
  "A unique, existing directory under the process temp root."
  (let* ((base (uiop:with-temporary-file (:pathname p :keep t)
                 (delete-file p)
                 p))
         (root (uiop:ensure-directory-pathname base)))
    (ensure-directories-exist root)
    root))

(defun fixed-clock ()
  "2026-08-24T00:00:00Z")

(defun dispatch (argv &key root clock)
  "One dispatch-command invocation; ROOT becomes --store=PATH. Usage output
is captured so malformed-invocation tests stay quiet."
  (let ((*error-output* (make-string-output-stream)))
    (multiple-value-list
     (hngh.main:dispatch-command
      (if root
          (cons (format nil "--store=~A" root) argv)
          argv)
      :clock-now (or clock #'fixed-clock)))))

(defun exit-code (result)
  (second result))

(defun has-output (needle result)
  (search needle (first result)))

(defparameter +create-args+
  '("create-run" "Create a valid run" "builder"
    "loadout-route-label=local" "loadout-context-limit=1" "loadout-token-limit=2"
    "loadout-cost-limit=3" "loadout-time-limit=4" "loadout-tool-labels=make-test"
    "loadout-network-labels=none" "loadout-writable-scopes=repository"))

;;; Full lifecycle under a temp root ----------------------------------------

(let* ((root (dispatch-root))
       (created (dispatch +create-args+ :root root)))
  (check (= 0 (exit-code created)) "create-run accepts under a store")
  (check (has-output "accepted" created) "create-run renders accepted")
  (check (has-output "run run-1" created) "create-run names the run")
  (let ((armed-before (dispatch '("arm-run" "run-1") :root root)))
    (check (= 1 (exit-code armed-before))
           "arm before admit fails closed"))
  (let ((started-before (dispatch '("start-run" "run-1") :root root)))
    (check (= 1 (exit-code started-before))
           "start before arm is refused"))
  (let ((admitted (dispatch '("admit-transport" "run-1" "filesystem" "repository")
                            :root root)))
    (check (= 0 (exit-code admitted))
           "admit-transport accepts the filesystem transport")
    (check (has-output "transport: filesystem" admitted)
           "admission receipt carries the transport fact"))
  (let ((duplicate (dispatch '("admit-transport" "run-1" "filesystem" "repository")
                             :root root)))
    (check (= 1 (exit-code duplicate)) "duplicate admission conflicts"))
  (let ((unknown (dispatch '("admit-transport" "run-1" "network") :root root)))
    (check (= 2 (exit-code unknown)) "an unknown transport is malformed"))
  (let ((armed (dispatch '("arm-run" "run-1") :root root)))
    (check (= 0 (exit-code armed)) "arm accepts after admission")
    (check (has-output "state=armed" armed) "arm renders the armed state"))
  (let ((started (dispatch '("start-run" "run-1") :root root)))
    (check (= 0 (exit-code started)) "start accepts an armed run")
    (check (has-output "state=running" started) "start renders the running state"))
  (let ((failed-checkpoint (dispatch '("checkpoint" "run-1" "failed" "complete")
                                     :root root)))
    (check (= 1 (exit-code failed-checkpoint)) "a failed checkpoint is refused"))
  (let ((bad-verification (dispatch '("checkpoint" "run-1" "banana" "complete")
                                    :root root)))
    (check (= 2 (exit-code bad-verification))
           "an unknown verification verb is malformed"))
  (let ((checkpointed (dispatch '("checkpoint" "run-1" "passed" "complete")
                                :root root)))
    (check (= 0 (exit-code checkpointed)) "a passed checkpoint accepts"))
  (let ((bad-close (dispatch '("close-run" "run-1" "banana") :root root)))
    (check (= 2 (exit-code bad-close)) "an unknown disposition is malformed"))
  (let ((closed (dispatch '("close-run" "run-1" "evacuated") :root root)))
    (check (= 0 (exit-code closed)) "close-run accepts an admitted closure"))
  (let ((presented (dispatch '("present" "run-1") :root root)))
    (check (= 0 (exit-code presented)) "present finds the run")
    (check (has-output "state=evacuated" presented)
           "present renders the terminal state"))
  (let ((all (dispatch '("present") :root root)))
    (check (= 0 (exit-code all)) "present with no id lists the store")
    (check (has-output "run-1" all) "present lists the recorded run"))
  (let ((ghost (dispatch '("present" "ghost-1") :root root)))
    (check (= 1 (exit-code ghost)) "present with an unknown id is refused"))
  (let ((option-rejected (dispatch '("admit-transport" "run-1" "filesystem"
                                     "bogus=x")
                                   :root root)))
    (check (= 2 (exit-code option-rejected)) "an unknown option is malformed"))
  (check (probe-file (merge-pathnames "record.lisp" root))
         "the store file exists under the root")
  (let ((recomposed (dispatch '("present" "run-1") :root root)))
    (check (= 0 (exit-code recomposed))
           "records survive store re-composition"))
  (uiop:delete-directory-tree root :validate t))

;;; No record persists without --store --------------------------------------

(let ((created (dispatch +create-args+)))
  (check (= 0 (exit-code created)) "create-run accepts without a store"))
(let ((presented (dispatch '("present" "run-1"))))
  (check (= 1 (exit-code presented))
         "no record persists without --store"))

;;; Malformed invocations exit 2 --------------------------------------------

(let ((unknown-command (dispatch '("transmogrify"))))
  (check (= 2 (exit-code unknown-command)) "an unknown command is malformed"))
(let ((wrong-arity (dispatch '("arm-run"))))
  (check (= 2 (exit-code wrong-arity)) "a missing operand is malformed"))
(let ((missing-loadout (dispatch '("create-run" "M" "R"))))
  (check (= 2 (exit-code missing-loadout)) "a missing loadout is malformed"))
(let ((extra (dispatch '("create-run" "M" "R" "loadout-route-label=local"
                         "loadout-context-limit=1" "loadout-token-limit=2" "loadout-cost-limit=3"
                         "loadout-time-limit=4" "loadout-tool-labels=make-test"
                         "loadout-network-labels=none" "loadout-writable-scopes=repository"
                         "bogus-key=x"))))
  (check (= 2 (exit-code extra)) "an unknown create-run key is malformed"))
(let ((bad-limit (dispatch '("create-run" "M" "R" "loadout-route-label=local"
                             "context-limit=x" "loadout-token-limit=2" "loadout-cost-limit=3"
                             "loadout-time-limit=4" "loadout-tool-labels=make-test"
                             "loadout-network-labels=none" "loadout-writable-scopes=repository"))))
  (check (= 2 (exit-code bad-limit)) "a non-numeric limit is malformed"))

;;; Transport faults exit 3 --------------------------------------------------

;;; A missing store directory is refused up front (exit 2), for every
;;; command, since the check lives in DISPATCH-COMMAND itself. An existing
;;; store root still proceeds; a root that exists but is a file remains a
;;; transport fault.

(let ((refusal (dispatch '("create-run" "M" "R") :root "/nonexistent-hngh-root-xyz/")))
  (check (= 2 (exit-code refusal)) "create-run with a missing store is refused")
  (check (has-output "store directory missing" refusal)
         "the refusal names the missing store directory")
  (check (has-output "/nonexistent-hngh-root-xyz" refusal)
         "the refusal names the path"))
(let ((refusal (dispatch '("present") :root "/nonexistent-hngh-root-xyz/")))
  (check (= 2 (exit-code refusal)) "present with a missing store is refused too"))
(let ((refusal (dispatch +create-args+ :root "/nonexistent-hngh-root-xyz/")))
  (check (= 2 (exit-code refusal))
         "a full create-run with a missing store is refused"))
(let ((file (uiop:with-temporary-file (:pathname p :keep t) p)))
  (check (= 3 (exit-code (dispatch '("present") :root file)))
         "a store root that is a file is a transport fault"))


;;; A cancelled (out-of-chain terminal) run must survive recomposition ------

(let ((root (dispatch-root)))
  (dispatch +create-args+ :root root)
  (dispatch '("admit-transport" "run-1" "filesystem" "repository") :root root)
  (dispatch '("close-run" "run-1" "cancelled") :root root)
  (let ((presented (dispatch '("present" "run-1") :root root)))
    (check (= 0 (exit-code presented))
           "present survives a cancelled (out-of-chain) terminal run")
    (check (has-output "state=cancelled" presented)
           "present renders the cancelled terminal state"))
  (uiop:delete-directory-tree root :validate t))
