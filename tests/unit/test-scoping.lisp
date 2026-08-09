;;;; tests/unit/test-scoping.lisp — Wave C item 5: least-agency tool scoping
;;;;
;;;; Deny-by-default grant gate for the AI Tool Hub (spec:
;;;; docs/design/least-agency-scoping.md, tandem-a). Registered-but-ungranted
;;;; tools are refused fail-closed; explicit grants (config-seeded or runtime)
;;;; pass; structurally read-only tools are auto-granted; every denial is
;;;; journaled via the safety-boundary action log and emitted on the bus as
;;;; tool.denied. Fixture-driven — the only "tool execution" is a /bin/true
;;;; stub; no real AI CLI or provider is ever invoked.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.scoping
  :description "Wave C item 5 — AI Tool Hub least-agency tool scoping (deny-by-default)"
  :in :hngh)

(in-suite :hngh.scoping)

;;; --- Fixture: isolated temp hngh-home (prod init order) ----------------

(defvar *scoping-tmp-home* nil
  "Temp hngh-home for the current scoping test fixture.")

(defvar *scoping-saved-config* nil
  "Saved hngh.core.config:*config* for restore on teardown.")

(defun scoping-setup ()
  "Init event bus, state store, safety boundary, secrets manager, AI Tool Hub
in production order against an isolated temp home. The config plist is
isolated to fresh defaults — NO :tool-grants key, so the fixture's default
state IS the deny-by-default posture."
  (let ((home (make-tmp-home)))
    (setf *scoping-tmp-home* home
          *scoping-saved-config* hngh.core.config:*config*)
    (setf hngh.core.config:*config*
          (copy-list hngh.core.config:*default-config*))
    (ensure-directories-exist home)
    (hngh.core.event-bus:init :hngh-home home)
    (hngh.core.state-store:init :hngh-home home)
    (hngh.core.safety-boundary:init :hngh-home home)
    (hngh.plugins.secrets-manager:init :hngh-home home)
    (hngh.plugins.ai-tool-hub:init :hngh-home home)))

(defun scoping-teardown ()
  "Shut down in reverse order, restore the config plist, clean up temp home."
  (hngh.plugins.ai-tool-hub:shutdown)
  (hngh.plugins.secrets-manager:shutdown)
  (hngh.core.safety-boundary:shutdown)
  (hngh.core.state-store:shutdown)
  (hngh.core.event-bus:shutdown)
  (setf hngh.core.config:*config* *scoping-saved-config*)
  (when *scoping-tmp-home*
    (cleanup-tmp-home *scoping-tmp-home*)
    (setf *scoping-tmp-home* nil)))

(defun scoping-denied-targets ()
  "Collect :denied targets from the safety-boundary action log."
  (loop for entry in (hngh.core.safety-boundary:read-action-log)
        when (eq (getf entry :kind) :denied)
        collect (getf entry :target)))

(defun scoping-register-stub (tool-id &key (read-only-p nil))
  "Register a synthetic :agentic-cli tool-info that exits successfully
(/bin/true — never touches an AI provider). Returns the struct."
  (let ((tool
          (hngh.plugins.ai-tool-hub::make-tool-info
           :id tool-id
           :name (format nil "~A (test stub)" tool-id)
           :type :agentic-cli
           :command "/bin/true"
           :available-p t
           :capabilities '(:simple-output)
           :providers '(:local)
           :cost-model :free
           :context-format :cli-args
           :read-only-p read-only-p)))
    (bt:with-lock-held (hngh.plugins.ai-tool-hub::*tools-lock*)
      (push tool hngh.plugins.ai-tool-hub:*tools*))
    tool))

(defun scoping-assert-refused (tool-id task)
  "Assert invoke TOOL-ID TASK refuses: signals an error and creates no
invocation record. Returns T when refused."
  (let ((refused nil))
    (handler-case
        (progn
          (hngh.plugins.ai-tool-hub:invoke tool-id task)
          (is-false t
                    (format nil "invoke ~A should refuse an ungranted tool"
                            tool-id)))
      (error () (setf refused t)))
    (is-true refused
             (format nil "invoke ~A should signal on refusal" tool-id))
    (is (= 0 (length (hngh.plugins.ai-tool-hub:list-invocations)))
        "a refused invocation must not create an invocation record")
    refused))

;;; --- Tests: deny-by-default -------------------------------------------

(test scoping-default-deny-ungranted
  "Registered tools are denied by default; the grant set starts empty."
  (scoping-setup)
  (unwind-protect
       (progn
         (is (not (hngh.plugins.ai-tool-hub:tool-granted-p :opencode))
             "a registered tool must be denied by default")
         (is (not (hngh.plugins.ai-tool-hub:tool-granted-p :claude))
             "every registered tool must be denied by default")
         (is (not (hngh.plugins.ai-tool-hub:tool-granted-p :pi))
             "an unknown tool must be denied (fail closed on unknown)")
         (is (= 0 (length (hngh.plugins.ai-tool-hub:granted-tools-list)))
             "granted-tools-list must start empty"))
    (scoping-teardown)))

(test scoping-invoke-refuses-ungranted
  "Invoking a registered-but-ungranted tool fails closed: error, no
invocation record, no agent.spawned event."
  (scoping-setup)
  (unwind-protect
       (let ((spawned nil))
         (hngh.core.event-bus:subscribe
          "agent.spawned"
          (lambda (ev) (declare (ignore ev)) (setf spawned t)))
         (is (scoping-assert-refused :opencode "do the thing"))
         (is (not spawned)
             "a refused invocation must not emit agent.spawned")
         (let ((st (hngh.plugins.ai-tool-hub:status)))
           (is (= 0 (getf st :active-invocations))
               "refusal must not spawn an agent")))
    (scoping-teardown)))

(test scoping-invoke-refuses-every-ungranted
  "No registry default grants: every registered tool is refused until granted."
  (scoping-setup)
  (unwind-protect
       (progn
         (dolist (tool (hngh.plugins.ai-tool-hub:list-tools))
           (is (not (hngh.plugins.ai-tool-hub:tool-granted-p
                     (hngh.plugins.ai-tool-hub:tool-info-id tool)))
               "no tool may be pre-granted by the registry")))
    (scoping-teardown)))

;;; --- Tests: grants are config data ------------------------------------

(test scoping-config-seeds-grants
  "init seeds the grant set from the owner config plist key :tool-grants."
  (let* ((base (merge-pathnames
                (format nil "hngh-scoping-config-~D-~D-/"
                        (get-universal-time) (random 1000000))
                (uiop:temporary-directory)))
         (home (merge-pathnames "home/" base))
         (saved-config hngh.core.config:*config*))
    (ensure-directories-exist home)
    (setf hngh.core.config:*config* '(:tool-grants (:opencode)))
    (hngh.core.config:save-config :hngh-home home)
    (hngh.core.config:load-config :hngh-home home)
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home home)
           (hngh.core.state-store:init :hngh-home home)
           (hngh.core.safety-boundary:init :hngh-home home)
           (hngh.plugins.secrets-manager:init :hngh-home home)
           (hngh.plugins.ai-tool-hub:init :hngh-home home)
           (is (hngh.plugins.ai-tool-hub:tool-granted-p :opencode)
               "a tool listed in :tool-grants config must be granted at init")
           (is (member :opencode (hngh.plugins.ai-tool-hub:granted-tools-list))
               "granted-tools-list must reflect the config seed")
           (is (not (hngh.plugins.ai-tool-hub:tool-granted-p :claude))
               "tools not in the config grant set stay denied"))
      (hngh.plugins.ai-tool-hub:shutdown)
      (hngh.plugins.secrets-manager:shutdown)
      (hngh.core.safety-boundary:shutdown)
      (hngh.core.state-store:shutdown)
      (hngh.core.event-bus:shutdown)
      (setf hngh.core.config:*config* saved-config)
      (uiop:delete-directory-tree base :validate #'identity))))

(test scoping-runtime-grants-live-only
  "Runtime grants are session-only; the config file is the durable source."
  (scoping-setup)
  (unwind-protect
       (progn
         (hngh.plugins.ai-tool-hub:grant-tool :opencode)
         (is (hngh.plugins.ai-tool-hub:tool-granted-p :opencode)
             "grant-tool must open the gate for the session")
         (hngh.plugins.ai-tool-hub:shutdown)
         (hngh.plugins.ai-tool-hub:init :hngh-home *scoping-tmp-home*)
         (is (not (hngh.plugins.ai-tool-hub:tool-granted-p :opencode))
             "a runtime grant must NOT survive restart (config is the source)"))
    (scoping-teardown)))

;;; --- Tests: explicit grant passes (stub tool, no real CLI) ------------

(test scoping-granted-stub-completes
  "A granted tool completes end-to-end (stub /bin/true); a granted run adds
no denial; granted-but-unavailable still refuses at the availability gate."
  (scoping-setup)
  (unwind-protect
       (progn
         (scoping-register-stub :stub-tool)
         ;; ungranted stub is refused first (deny-by-default for stubs too)
         (scoping-assert-refused :stub-tool "deny me first")
         (let ((denied-before (length (scoping-denied-targets))))
           (hngh.plugins.ai-tool-hub:grant-tool :stub-tool)
           (let ((inv (hngh.plugins.ai-tool-hub:invoke :stub-tool "do the thing")))
             (is (eq :completed
                     (hngh.plugins.ai-tool-hub:invocation-info-status inv))
                 "a granted stub must complete")
             (is (= denied-before (length (scoping-denied-targets)))
                 "a granted run must not add a denial")))
         ;; granted-but-unavailable: grant gate passes, availability refuses
         (hngh.plugins.ai-tool-hub:grant-tool :google-api)
         (let ((refused-for-availability nil))
           (handler-case
               (progn
                 (hngh.plugins.ai-tool-hub:invoke :google-api "call")
                 (is-false t
                           "invoke should refuse an unavailable granted tool"))
             (error (c)
               (setf refused-for-availability
                     (search "not available" (princ-to-string c)))))
           (is-true refused-for-availability
                    "granted-but-unavailable must fail at the availability gate, not the grant gate")))
    (scoping-teardown)))

(test scoping-revoke-restores-deny
  "Revoking a grant restores deny-by-default."
  (scoping-setup)
  (unwind-protect
       (progn
         (hngh.plugins.ai-tool-hub:grant-tool :opencode)
         (is (hngh.plugins.ai-tool-hub:revoke-tool :opencode)
             "revoke-tool should return T when the tool was granted")
         (is (not (hngh.plugins.ai-tool-hub:tool-granted-p :opencode))
             "revoking a grant must restore deny-by-default")
         (is (not (hngh.plugins.ai-tool-hub:revoke-tool :opencode))
             "revoke-tool should return NIL when the tool was not granted"))
    (scoping-teardown)))

(test scoping-read-only-tool-auto-granted
  "A structurally read-only tool (read-only-p t) is auto-granted — the
read-only/observe half of the least-agency invariant."
  (scoping-setup)
  (unwind-protect
       (progn
         (scoping-register-stub :observe-tool :read-only-p t)
         (is (hngh.plugins.ai-tool-hub:tool-granted-p :observe-tool)
             "read-only tools must pass the grant gate without a grant")
         (is (not (hngh.plugins.ai-tool-hub:tool-granted-p :stub-tool))
             "mutable tools stay denied"))
    (scoping-teardown)))

;;; --- Tests: denial journaling + bus emission --------------------------

(test scoping-denial-journaled
  "A refusal is journaled via the safety-boundary action log (:kind :denied,
:target = tool id)."
  (scoping-setup)
  (unwind-protect
       (progn
         (scoping-assert-refused :opencode "journal me")
         (let ((targets (scoping-denied-targets)))
           (is (member "opencode" targets :test #'string=)
               "a refused tool must appear as a :denied action-log entry")
           (is (= 1 (length targets))
               "exactly one denial is journaled")))
    (scoping-teardown)))

(test scoping-denial-emits-bus-event
  "A refusal is emitted on the bus as a tool.denied event (the situation
surface)."
  (scoping-setup)
  (unwind-protect
       (let ((captured nil))
         (hngh.core.event-bus:subscribe
          "tool.denied"
          (lambda (ev)
            (setf captured
                  (list :topic (hngh.core.event-bus:event-topic ev)
                        :payload (hngh.core.event-bus:event-payload ev)))))
         (scoping-assert-refused :opencode "bus me")
         (is-true captured "a refusal must emit a tool.denied bus event")
         (is (string= "tool.denied" (getf captured :topic))
             "emitted topic must be tool.denied")
         (is (eq :opencode (getf (getf captured :payload) :tool))
             "the event payload must name the refused tool")
         (is (eq :not-granted (getf (getf captured :payload) :reason))
             "the event payload must carry :reason :not-granted"))
    (scoping-teardown)))

;;; --- Tests: selection respects grants ---------------------------------

(test scoping-select-tool-filters-ungranted
  "select-tool must never choose a tool invoke would refuse."
  (scoping-setup)
  (unwind-protect
       (progn
         (is (null (hngh.plugins.ai-tool-hub:select-tool "a task"))
             "select-tool must not choose an ungranted tool")
         (hngh.plugins.ai-tool-hub:grant-tool :opencode)
         (is (eq :opencode
                 (hngh.plugins.ai-tool-hub:select-tool
                  "a task" :prefer-tool :opencode))
             "a granted, available preferred tool must be selectable")
         (let ((chosen (hngh.plugins.ai-tool-hub:select-tool "a task")))
           (is (member chosen (list :opencode nil))
               "auto-selection must only ever return granted tools")))
    (scoping-teardown)))