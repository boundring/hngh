;;;; tests/unit/test-operation-gate.lisp — Wave C item 8: :operation human gate
;;;;
;;;; Core-file commits + dependency installs require explicit human approval
;;;; (spec: docs/design/operation-gate.md, tandem-a). Unapproved -> :blocked
;;;; task + safety-boundary :denied journal + operation.denied bus event.
;;;; Approved + lint-deps-failed -> refused even when approved (composition).
;;;; Exact-match approvals only; config-seed fail-soft (deny-all on garbage).
;;;; Fixture-driven: no real installs, commits, or daemon calls — the daemon
;;;; side is a recorded stub.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.operation-gate
  :description "Wave C item 8 — :operation human gate for core commits + dep installs"
  :in :hngh)

(in-suite :hngh.operation-gate)

;;; --- Fixture: isolated temp hngh-home (prod init order) ----------------

(defvar *opg-tmp-home* nil
  "Temp hngh-home for the current operation-gate test fixture.")

(defvar *opg-saved-config* nil
  "Saved hngh.core.config:*config* for restore on teardown.")

(defun opg-setup ()
  "Init event bus, state store, safety boundary, AI orchestrator in
production order against an isolated temp home. Fresh config defaults —
no :operation-approvals, so the fixture state IS deny-by-default."
  (let ((home (make-tmp-home)))
    (setf *opg-tmp-home* home
          *opg-saved-config* hngh.core.config:*config*)
    (setf hngh.core.config:*config*
          (copy-list hngh.core.config:*default-config*))
    (ensure-directories-exist home)
    (hngh.core.event-bus:init :hngh-home home)
    (hngh.core.state-store:init :hngh-home home)
    (hngh.core.safety-boundary:init :hngh-home home)
    (hngh.plugins.ai-orchestrator:init :hngh-home home)))

(defun opg-teardown ()
  "Shut down in reverse order, restore config, clean temp home."
  (hngh.plugins.ai-orchestrator:shutdown)
  (hngh.core.safety-boundary:shutdown)
  (hngh.core.state-store:shutdown)
  (hngh.core.event-bus:shutdown)
  (setf hngh.core.config:*config* *opg-saved-config*)
  (when *opg-tmp-home*
    (cleanup-tmp-home *opg-tmp-home*)
    (setf *opg-tmp-home* nil)))

(defun opg-denied-targets ()
  "Collect :denied targets from the safety-boundary action log."
  (loop for entry in (hngh.core.safety-boundary:read-action-log)
        when (eq (getf entry :kind) :denied)
        collect (getf entry :target)))

(defun opg-denied-details ()
  "Collect :denied details from the safety-boundary action log."
  (loop for entry in (hngh.core.safety-boundary:read-action-log)
        when (eq (getf entry :kind) :denied)
        collect (getf entry :detail)))

(defun opg-seed-approvals (approvals)
  "Directly seed *approved-operations* (config-seed equivalent, live-only
speed of test). Each approval: (:kind <kw> :targets <list>)."
  (let ((now (get-universal-time)))
    (bt:with-lock-held (hngh.plugins.ai-orchestrator::*approved-operations-lock*)
      (setf hngh.plugins.ai-orchestrator:*approved-operations*
            (loop for a in approvals
                  collect (list :kind (getf a :kind)
                                :targets (copy-list (getf a :targets))
                                :approved-at now
                                :approver "test-human"))))))

(defun opg-clear-approvals ()
  "Reset the approval registry to deny-all."
  (bt:with-lock-held (hngh.plugins.ai-orchestrator::*approved-operations-lock*)
    (setf hngh.plugins.ai-orchestrator:*approved-operations* '())))

(defun opg-approval-plist ()
  "Return the current live approval registry."
  (copy-list hngh.plugins.ai-orchestrator:*approved-operations*))

;;; --- Tests: default deny -------------------------------------------------

(test opg-default-deny-blocks-submit
  "An unapproved :dep-install op is blocked at submit, journaled, and
announced on the bus."
  (opg-setup)
  (unwind-protect
       (let ((captured nil))
         (hngh.core.event-bus:subscribe
          "operation.denied"
          (lambda (ev)
            (setf captured
                  (list :topic (hngh.core.event-bus:event-topic ev)
                        :payload (hngh.core.event-bus:event-payload ev)))))
         (let ((id (hngh.plugins.ai-orchestrator:submit-task
                    "install foo"
                    :operation-spec
                    (list :kind :dep-install
                          :targets '("foo")
                          :lint-deps :pending
                          :requested-by "test"))))
           (let ((task (find id (hngh.plugins.ai-orchestrator:list-tasks)
                             :key (lambda (e) (getf e :id)))))
             (is (eq :blocked (getf task :status))
                 "unapproved op enters :blocked")
             (is (equal "awaiting-human-approval" (getf task :blocked-reason))
                 "blocked reason names human approval")
             (is (eq :operation (getf task :type))
                 "operation-spec forces :type :operation")
             (is (eq :approval (getf task :authority))
                 "operation-spec forces :authority :approval")))
         (is-false (hngh.plugins.ai-orchestrator:operation-gate-check
                    :dep-install '("foo"))
                   "gate is NIL for unapproved op")
         (is (member "operation/dep-install" (opg-denied-targets) :test #'equal)
             "refusal journaled as :denied with operation/<kind> target")
         (is-true captured "refusal must emit an operation.denied bus event")
         (is (string= "operation.denied" (getf captured :topic))
             "emitted topic must be operation.denied")
         (is (eq :dep-install (getf (getf captured :payload) :kind))
             "event payload must carry the refused kind")
         (is (eq :operation-not-approved (getf (getf captured :payload) :reason))
             "event payload must carry :reason :operation-not-approved"))
    (opg-teardown)))

;;; --- Tests: approved path passes ------------------------------------------

(test opg-approved-path-passes
  "An approved op submits :queued, the gate opens, and approve-task is the
human-only flip back from :blocked to :queued."
  (opg-setup)
  (unwind-protect
       (progn
         (opg-seed-approvals '((:kind :dep-install :targets ("foo"))))
         (let ((denials-before (length (opg-denied-targets))))
           (let ((id (hngh.plugins.ai-orchestrator:submit-task
                      "install foo"
                      :operation-spec
                      (list :kind :dep-install :targets '("foo")
                            :lint-deps :pending :requested-by "test"))))
             (let ((task (find id (hngh.plugins.ai-orchestrator:list-tasks)
                               :key (lambda (e) (getf e :id)))))
               (is (eq :queued (getf task :status))
                   "approved op submits :queued")))
           (is (= denials-before (length (opg-denied-targets)))
               "approved submit must not journal a denial")
           (is-true (hngh.plugins.ai-orchestrator:operation-gate-check
                     :dep-install '("foo"))
                    "gate T for an approved op")
           (is (= denials-before (length (opg-denied-targets)))
               "approved gate check must not journal a denial")
           ;; Same operation but unapproved target must stay refused.
           (is-false (hngh.plugins.ai-orchestrator:operation-gate-check
                      :dep-install '("bar"))
                     "unapproved sibling target stays refused")
           ;; approve-task writes :approval-at and flips a blocked task.
           (let ((id2 (hngh.plugins.ai-orchestrator:submit-task
                       "install baz"
                       :operation-spec
                       (list :kind :dep-install :targets '("baz")
                             :lint-deps :pending :requested-by "test"))))
             (hngh.plugins.ai-orchestrator:approve-task id2 :approver "test-human")
             (let ((task (find id2 (hngh.plugins.ai-orchestrator:list-tasks)
                               :key (lambda (e) (getf e :id)))))
               (is (eq :queued (getf task :status))
                   "approve-task flips :blocked to :queued")
               (is (integerp (getf task :approval-at))
                   "approve-task sets :approval-at")))
           ;; Unapproved submissions each journal a denial: the bar gate-check
           ;; refusal + the baz submit = 2; the approved path adds none.
           (is (= 2 (length (opg-denied-targets)))
               "denials counted: bar gate-check + baz submit, not the approved path")
           (is (not (member "operation-lint-deps-failed" (opg-denied-details)
                            :test #'equal))
               "approval must not journal a lint-deps denial"))
    (opg-teardown))))

(test opg-approve-flips-blocked-to-queued-eligible
  "After approve-task, a formerly-blocked op is eligible for dispatch."
  (opg-setup)
  (unwind-protect
       (let ((id (hngh.plugins.ai-orchestrator:submit-task
                  "commit core"
                  :operation-spec
                  (list :kind :core-commit
                        :targets '("src/packages.lisp")
                        :lint-deps :passed
                        :requested-by "test"))))
         (is (eq :blocked
                 (getf (find id (hngh.plugins.ai-orchestrator:list-tasks)
                             :key (lambda (e) (getf e :id)))
                       :status))
             "precondition: unapproved op is blocked")
         (hngh.plugins.ai-orchestrator:approve-task id :approver "test-human")
         (let ((queue (hngh.plugins.ai-orchestrator:list-tasks)))
           (let ((eligible
                   (hngh.plugins.ai-orchestrator:next-eligible-task
                    queue (get-universal-time) :clear)))
             (is (= id (getf eligible :id))
                 "approved task is picked by next-eligible-task"))))
    (opg-teardown)))

;;; --- Tests: composition with lint-deps (card's key test) ------------------

(test opg-composition-lint-deps-failed
  "An approved core-commit whose lint-deps is :failed is refused — approval
grants access, lint-deps grants safety, both required."
  (opg-setup)
  (unwind-protect
       (progn
         (opg-seed-approvals '((:kind :core-commit :targets ("src/core/a.lisp"))))
         ;; Approved-but-lint-failed: must refuse with the lint reason.
         (is-true (hngh.plugins.ai-orchestrator:operation-gate-check
                   :core-commit '("src/core/a.lisp") :lint-deps :passed)
                  "approved + lint-deps passed -> T")
         (is-false (hngh.plugins.ai-orchestrator:operation-gate-check
                    :core-commit '("src/core/a.lisp") :lint-deps :failed)
                   "approved + lint-deps failed -> NIL despite approval")
         (is (member "operation-lint-deps-failed" (opg-denied-details)
                     :test #'equal)
             "lint-failure refusal journaled with operation-lint-deps-failed"))
    (opg-teardown)))

;;; --- Tests: refused at the driver (no delegate) ---------------------------

(test opg-refused-at-driver-no-delegate
  "A gate-failing op never reaches delegate: task-driver-tick marks it
:failed and no agent is spawned."
  (opg-setup)
  (unwind-protect
       (let ((id (hngh.plugins.ai-orchestrator:submit-task
                  "commit core"
                  :operation-spec
                  (list :kind :core-commit
                        :targets '("src/core/x.lisp")
                        :lint-deps :failed
                        :requested-by "test"))))
         ;; Approve it so it's eligible; the driver gate must still refuse
         ;; because lint-deps failed (composition).
         (hngh.plugins.ai-orchestrator:approve-task id :approver "test-human")
         (let ((agents-before (length (hngh.plugins.ai-orchestrator:list-agents))))
           (hngh.plugins.ai-orchestrator:task-driver-tick)
           (let ((task (find id (hngh.plugins.ai-orchestrator:list-tasks)
                             :key (lambda (e) (getf e :id)))))
             (is (eq :failed (getf task :status))
                 "gate-failing op is :failed at the driver")
             (is (equal "operation refused" (getf task :error))
                 "task error names the refusal"))
           (is (= agents-before
                  (length (hngh.plugins.ai-orchestrator:list-agents)))
               "no agent spawned (delegate never called)")))
    (opg-teardown)))

;;; --- Tests: exact-match only ----------------------------------------------

(test opg-exact-match-only
  "Approvals match exactly: subset and superset requests are refused."
  (opg-setup)
  (unwind-protect
       (progn
         (opg-seed-approvals
          '((:kind :core-commit :targets ("src/core/a.lisp" "src/core/b.lisp"))))
         (is-true (hngh.plugins.ai-orchestrator:operation-gate-check
                   :core-commit '("src/core/a.lisp" "src/core/b.lisp")
                   :lint-deps :passed)
                  "exact target list -> approved")
         (is-false (hngh.plugins.ai-orchestrator:operation-gate-check
                    :core-commit '("src/core/a.lisp") :lint-deps :passed)
                   "subset of approved targets -> refused")
         (is-false (hngh.plugins.ai-orchestrator:operation-gate-check
                    :core-commit '("src/core/a.lisp" "src/core/b.lisp"
                                   "src/core/c.lisp")
                    :lint-deps :passed)
                   "superset of approved targets -> refused")
         (is-true (hngh.plugins.ai-orchestrator:operation-gate-check
                   :core-commit '("src/core/b.lisp" "src/core/a.lisp")
                   :lint-deps :passed)
                  "same set, different order -> approved (content equality)")
         (is-false (hngh.plugins.ai-orchestrator:operation-gate-check
                    :dep-install '("foo") :lint-deps :passed)
                   "different kind -> refused"))
    (opg-teardown)))

;;; --- Tests: package-manager gate -------------------------------------------

(test opg-package-manager-gate
  "install-packages refuses unapproved installs BEFORE any daemon call;
approved installs proceed to the (recorded) daemon."
  (opg-setup)
  (unwind-protect
       (let ((daemon-calls '()))
         (let ((orig (fdefinition 'hngh.plugins.package-manager::call-system-daemon)))
           (unwind-protect
                (progn
                  (setf (fdefinition 'hngh.plugins.package-manager::call-system-daemon)
                        (lambda (method &rest args)
                          (declare (ignore args))
                          (push method daemon-calls)
                          (values "" 0)))
                  (hngh.plugins.package-manager:init :hngh-home *opg-tmp-home*)
                  ;; Unapproved: error, daemon NOT called.
                  (handler-case
                      (progn
                        (hngh.plugins.package-manager:install-packages
                         '("foo") :reason "test")
                        (is-false t "unapproved install must signal"))
                    (error () nil))
                  (is (not (member "org.hngh.System.PackageManager.InstallPackages"
                                   daemon-calls :test #'equal))
                      "daemon must NOT be called for unapproved install")
                  (is (member "operation/dep-install" (opg-denied-targets)
                              :test #'equal)
                      "unapproved install journaled as :denied")
                  ;; Approved: proceeds to daemon.
                  (opg-seed-approvals '((:kind :dep-install :targets ("bar"))))
                  (let ((result
                          (hngh.plugins.package-manager:install-packages
                           '("bar") :reason "test")))
                    (is-true result "approved install proceeds (stub daemon ok)"))
                  (is (member "org.hngh.System.PackageManager.InstallPackages"
                              daemon-calls :test #'equal)
                      "approved install reaches the daemon"))
             (setf (fdefinition 'hngh.plugins.package-manager::call-system-daemon)
                   orig))))
    (opg-teardown)))

;;; --- Tests: config seed fail-soft ------------------------------------------

(test opg-config-seed-fail-soft
  "Garbage :operation-approvals config seeds an empty registry (deny-all),
never a crash."
  (opg-setup)
  (unwind-protect
       (progn
         (opg-clear-approvals)
         (setf hngh.core.config:*config* '(:operation-approvals "garbage-not-a-list"))
         (hngh.plugins.ai-orchestrator:shutdown)
         (hngh.plugins.ai-orchestrator:init :hngh-home *opg-tmp-home*)
         (is (null (opg-approval-plist))
             "garbage config -> empty approval registry (deny-all)")
         (is-false (hngh.plugins.ai-orchestrator:operation-gate-check
                    :dep-install '("foo"))
                   "deny-all holds after garbage seed"))
    (opg-teardown)))