;;;; plugins/hngh-up.lisp — Goal-driven squad spin-up with procedural questionnaire
;;;;
;;;; Implements: hngh up <goal> — questionnaire, spec derivation, squad launch.
;;;; This plugin is a local command — it does not require the daemon to be running.
;;;; It gathers project/system context, generates an adaptive questionnaire (max 5
;;;; questions), derives a squad spec from the answers, and launches via the existing
;;;; `squad up` shell script.
;;;;
;;;; C7 (Wave 1): generate-pm-prompt — procedurally assembles the PM's first
;;;; prompt from AGENTS.md discovery, plans/design docs, system context, roadmap
;;;; status, OptMem notes, and squad intent/lifetime policy.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
;;;; Attribution: PM — z-ai/glm-5.2 via openrouter, Hermes harness

(in-package :hngh.plugins.hngh-up)

;;; --- State ------------------------------------------------------------------

(defvar *running* nil
  "Whether the hngh-up plugin is active.")

;;; --- Built-in strategies ----------------------------------------------------

(defparameter *built-in-strategies*
  '((:name "duo-review"
     :description "Two-agent code review: coordinator + reviewer"
     :defaults ((:squad-type . :squad)
                (:model-tier . :budget-50)))
    (:name "feature-sprint"
     :description "Hierarchy: lead + 2 devs for implementation"
     :defaults ((:squad-type . :hierarchy)
                (:model-tier . :budget-200)))
    (:name "design-fork"
     :description "Democratic: 3 peers for architecture decisions"
     :defaults ((:squad-type . :democratic)
                (:model-tier . :budget-200)))
    (:name "nightly-audit"
     :description "Organism: queue + planner + detox for overnight runs"
     :defaults ((:squad-type . :organism)
                (:model-tier . :local-only))))
  "Built-in strategy definitions.")

;;; --- Context gathering ------------------------------------------------------

(defun gather-context (goal)
  "Gather project/system context for questionnaire generation.
Returns a plist of context signals."
  (let ((context (list :goal goal))
        (cwd (uiop:getcwd)))
    (setf (getf context :project-root) cwd)
    (setf (getf context :agents-md-exists)
          (probe-file (merge-pathnames "AGENTS.md" cwd)))
    (setf (getf context :makefile-exists)
          (probe-file (merge-pathnames "Makefile" cwd)))
    (setf (getf context :unsloth-studio-active)
          (zerop (nth-value 2 (uiop:run-program
                                '("systemctl" "--user" "is-active" "unsloth-studio")
                                :output :string :error-output :string
                                :ignore-error-status t))))
    context))

;;; --- AGENTS.md answerability (C3) ------------------------------------------

(defun gather-agents-md-context (cwd)
  "Merge the nearest-first AGENTS.md chain for CWD, or NIL when none exists."
  (let ((paths (hngh.plugins.agents-md:discover-agents-md cwd)))
    (when paths
      (hngh.plugins.agents-md:merge-agents-md paths))))

(defun %section-body-matching (merged-context pattern)
  "Return the body of the first merged AGENTS.md section whose header
contains PATTERN (case-insensitive), or NIL."
  (let ((sections (getf merged-context :sections)))
    (loop for (header . body) in sections
          when (search (string-downcase pattern) (string-downcase header))
            return body)))

(defun %parse-iso-date (string)
  "Parse STRING as YYYY-MM-DD into a universal time (noon UTC), or NIL."
  (when (and (= 10 (length string))
             (char= (char string 4) #\-)
             (char= (char string 7) #\-))
    (let ((year (parse-integer string :start 0 :end 4 :junk-allowed t))
          (month (parse-integer string :start 5 :end 7 :junk-allowed t))
          (day (parse-integer string :start 8 :end 10 :junk-allowed t)))
      (when (and year month day)
        (encode-universal-time 0 0 12 day month year)))))

(defun %date-age-days (date-string)
  "Age of DATE-STRING (YYYY-MM-DD) in whole days, or NIL if unparseable."
  (let ((then (%parse-iso-date date-string)))
    (when then
      (floor (- (get-universal-time) then) 86400))))

(defun answer-from-agents-md (question-id merged-context)
  "Auto-answer QUESTION-ID from MERGED-CONTEXT (a merge-agents-md plist),
per the answerability table in docs/design/squad-autonomy.md §5.

Returns (values answer reason) where ANSWER is a string matching the
questionnaire's option values, or (values nil nil) when AGENTS.md cannot
answer the question. The REASON is logged so auto-answers are never
silent guesses."
  (case question-id
    (:squad-type
     (let* ((repo-notes (%section-body-matching merged-context "repo notes"))
            (coordination (%section-body-matching merged-context "coordination"))
            (haystack (format nil "~A~%~A" (or repo-notes "") (or coordination ""))))
       (when (or (search "coordinator" haystack)
                 (search "agent-call" haystack)
                 (search "memo" haystack))
         (values "squad"
                 "AGENTS.md coordination/repo-notes implies fireteam layout"))))
    (:model-tier
     (let ((body (and (%section-body-matching merged-context "local-model")
                      (string-downcase
                       (%section-body-matching merged-context "local-model")))))
       (cond
         ((and body (search "prefer local" body))
          (values "local-only" "AGENTS.md local-model policy prefers local models"))
         ((and body (search "not the daily driver" body))
          (values "budget-50" "AGENTS.md names a remote primary driver; locals are fallbacks"))
         ((and body (search "daily driver" body))
          (values "local-only" "AGENTS.md names a local daily-driver model"))
         ((and body (search "primary driver" body))
          (values "budget-50" "AGENTS.md names a remote primary driver"))
         ((and body (search "$20" body))
          (values "budget-200" "AGENTS.md caps remote spend at $20/week"))
         ((and body (search "$1" body))
          (values "budget-50" "AGENTS.md caps remote spend under $1/day"))
         (t nil))))
    (:continue-policy
     (let ((freshness (getf merged-context :freshness)))
       (when freshness
         (let ((age (%date-age-days freshness)))
           (cond
             ((and age (<= age 1))
              (values "token-aware"
                      (format nil "AGENTS.md current state is ~A day(s) fresh" age)))
             ((and age (> age 7))
              (values "manual"
                      (format nil "AGENTS.md current state is ~A day(s) stale" age)))
             (t nil))))))
    (:journal-detail
     (let ((facts (getf merged-context :facts)))
       (when (or (%section-body-matching merged-context "doc convention")
                 (%section-body-matching merged-context "journal")
                 (loop for (key . value) in facts
                       thereis (or (search "doc convention" (string-downcase key))
                                   (search "journal" (string-downcase key))))
                 (loop for (key . value) in facts
                       thereis (search "journal" (string-downcase (or value "")))))
         (values "standard" "AGENTS.md has a doc-convention/journal section"))))
    (otherwise nil)))

;;; --- Questionnaire ---------------------------------------------------------

(defstruct question
  id
  prompt
  options
  default
  inferred-from)

(defun generate-questionnaire (context)
  "Generate an adaptive questionnaire (max 5 questions) from CONTEXT.
Returns a list of QUESTION structs."
  (let ((goal (getf context :goal ""))
        (unsloth-active (getf context :unsloth-studio-active)))
    (list
     (make-question
      :id :squad-type
      :prompt "Squad layout?"
      :options '(("squad" "Fireteam: coordinator + worker + reviewer")
                 ("hierarchy" "PM -> devs, top-down")
                 ("democratic" "Consensus circle")
                 ("organism" "Specialized organs, event-bus"))
      :default (cond
                 ((or (search "review" goal) (search "audit" goal)) "squad")
                 ((or (search "implement" goal) (search "build" goal)) "hierarchy")
                 ((or (search "design" goal) (search "decide" goal)) "democratic")
                 ((or (search "monitor" goal) (search "overnight" goal)) "organism")
                 (t "squad"))
      :inferred-from (list :goal goal))
     (make-question
      :id :model-tier
      :prompt "Model tier?"
      :options '(("local-only" "Local only, zero cost (gemma-4-12b queued)")
                 ("budget-50" "Up to 50c remote (deepseek-v4-flash-0731)")
                 ("budget-200" "Up to $2 remote (glm-5.2 deep tier / deepseek-v4-flash-0731)"))
      :default (if unsloth-active "local-only" "budget-50")
      :inferred-from (list :unsloth-active unsloth-active))

     (make-question
      :id :continue-policy
      :prompt "Autonomous continuation?"
      :options '(("manual" "Stop after first deliverable; human gates each phase")
                 ("token-aware" "Continue while token budget < 80%; pause at 90%")
                 ("full-auto" "Run to completion; report only blockers"))
      :default "manual"
      :inferred-from nil)

     (make-question
      :id :journal-detail
      :prompt "Journal verbosity?"
      :options '(("minimal" "Projected + actual paths only")
                 ("standard" "Projected + actual + per-member timeline (default)")
                 ("verbose" "Full token accounting, diffs, decision rationale"))
      :default "standard"
      :inferred-from nil)

     (make-question
      :id :strategy-name
      :prompt "Save as named strategy? (empty = skip)"
      :options nil
      :default ""
      :inferred-from nil))))

(defun render-questionnaire (questions &optional (agents-md nil))
  "Render questionnaire to terminal, collect answers as a plist.
When AGENTS-MD is a merged-agents-md plist, questions it can answer are
auto-answered (C3) and skipped — the human is only prompted where
AGENTS.md cannot answer."
  (format t "~%hngh-up — Squad Spin-Up~%")
  (format t "--------------------------------~%")
  (let ((answers '()))
    (dolist (q questions)
      (multiple-value-bind (auto-answer reason)
          (if agents-md
              (answer-from-agents-md (question-id q) agents-md)
              (values nil nil))
        (if auto-answer
            (progn
              (format t "~%~A [auto: ~A]~%" (question-prompt q) auto-answer)
              (format t "  (~A)~%" reason)
              (push (question-id q) answers)
              (push auto-answer answers))
            (progn
              (format t "~%~A [~A]: " (question-prompt q) (question-default q))
              (when (question-options q)
                (format t "~%")
                (dolist (opt (question-options q))
                  (format t "  ~A — ~A~%" (first opt) (second opt))))
              (format t "> ")
              (force-output)
              (let* ((raw (handler-case (read-line) (end-of-file () "")))
                     (input (string-trim '(#\Space #\Tab) raw))
                     (answer (if (zerop (length input))
                                 (question-default q)
                                 input)))
                (push (question-id q) answers)
                (push answer answers))))))
    (format t "--------------------------------~%")
    (nreverse answers)))

;;; --- Spec derivation -------------------------------------------------------

(defparameter *model-mapping*
  '((:local-only
     ("hermes" . "unsloth/gemma-4-12b-it-qat-GGUF")
     ("opencode" . "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"))
    (:budget-50
     ("hermes" . "deepseek/deepseek-v4-flash-0731")
     ("opencode" . "deepseek/deepseek-v4-flash-0731"))
    (:budget-200
     ("hermes" . "z-ai/glm-5.2")
     ("opencode" . "deepseek/deepseek-v4-flash-0731"))))

(defparameter *role-layouts*
  '((:squad
     ("coordinator" . "coordinator-base")
     ("worker" . "worker-base")
     ("reviewer" . "reviewer-base"))
    (:hierarchy
     ("lead" . "coordinator-base")
     ("dev-1" . "worker-base")
     ("dev-2" . "worker-base"))
    (:democratic
     ("peer-1" . "coordinator-base")
     ("peer-2" . "coordinator-base")
     ("peer-3" . "coordinator-base"))
    (:organism
     ("queue" . "coordinator-base")
     ("planner" . "worker-base")
     ("detox" . "reviewer-base"))))

(defun keywordify (string)
  "Convert a string like \"squad\" to keyword :squad."
  (intern (string-upcase string) :keyword))

(defun derive-squad-spec (answers goal context)
  "Derive a squad spec plist from questionnaire ANSWERS, GOAL, and CONTEXT."
  (let* ((squad-type-str (or (getf answers :squad-type) "squad"))
         (squad-type (keywordify squad-type-str))
         (model-tier-str (or (getf answers :model-tier) "local-only"))
         (model-tier (keywordify model-tier-str))
         (strategy-name (or (getf answers :strategy-name) ""))
         (models (cdr (assoc model-tier *model-mapping*)))
         (roles (cdr (assoc squad-type *role-layouts*)))
         (project-root (getf context :project-root (uiop:getcwd)))
         (members '()))
    (loop for role-template in roles
          for i from 0
          for role = (car role-template)
          for template = (cdr role-template)
          for cli-model = (nth (mod i (length models)) models)
          for cli = (car cli-model)
          for model = (cdr cli-model)
          do (push (list :role role
                         :cli cli
                         :model model
                         :cwd (namestring project-root)
                         :wake-template template)
                   members))
    (setf members (nreverse members))
    (list :name (generate-squad-name goal strategy-name)
          :version 1
          :description goal
          :layout (case squad-type
                    (:squad :vertical)
                    (:hierarchy :tiled)
                    (:democratic :horizontal)
                    (:organism :vertical)
                    (t :vertical))
          :preflight (build-preflight model-tier)
          :members members
          :journal '((:projected-path . "hngh/journal/squads/{{squad}}-{{timestamp}}-projected.md")
                     (:actual-path . "hngh/journal/squads/{{squad}}-{{timestamp}}-actual.md")))))

(defun build-preflight (model-tier)
  "Build preflight gates for the spec."
  (let ((gates '((require-systemd :units ("unsloth-studio")))))
    (case model-tier
      (:local-only (push '(quota-gate :max-remote-cents 0) gates))
      (:budget-50 (push '(quota-gate :max-remote-cents 50) gates))
      (:budget-200 (push '(quota-gate :max-remote-cents 200) gates)))
    (nreverse gates)))

(defun generate-squad-name (goal strategy-name)
  "Generate a squad name slug from GOAL and optional STRATEGY-NAME."
  (let ((slug (substitute-if #\-
                            (lambda (c) (not (alphanumericp c)))
                           (subseq goal 0 (min 30 (length goal))))))
    (if (and strategy-name (string/= strategy-name ""))
        (format nil "~A-~A" strategy-name
                (subseq (format nil "~A" (get-universal-time)) 0 10))
        (format nil "squad-~A-~A" slug
                (subseq (format nil "~A" (get-universal-time)) 0 10)))))

;;; --- Strategy management ---------------------------------------------------

(defun strategies-dir (&optional (hngh-home hngh:*hngh-home*))
  "Return the user strategies directory path."
  (merge-pathnames "squad-strategies/" hngh-home))

(defun list-strategies ()
  "Return combined list of built-in + user strategies."
  (let ((user-dir (strategies-dir)))
    (append *built-in-strategies*
            (when (probe-file user-dir)
              (loop for f in (uiop:directory-files user-dir "*.lisp")
                    collect (handler-case
                                (with-open-file (s f :direction :input)
                                  (let ((*read-eval* nil))
                                    (read s nil nil)))
                              (error () nil)))))))

(defun save-strategy (name spec)
  "Save a squad configuration as a reusable strategy file."
  (let ((dir (strategies-dir)))
    (ensure-directories-exist dir)
    (let ((path (merge-pathnames (format nil "~A.lisp" name) dir)))
      (with-open-file (stream path :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create)
        (let ((*print-readably* t))
          (prin1 (list :strategy
                       :name name
                       :version 1
                       :description (getf spec :description)
                       :defaults (list (cons :squad-type (getf spec :layout)))
                       :members (getf spec :members))
                 stream)
          (terpri stream)))
      (format t "Saved strategy: ~A -> ~A~%" name path))))

(defun load-strategy (name)
  "Load a strategy by NAME from built-in or user strategies."
  (or (find name *built-in-strategies*
            :key (lambda (s) (getf s :name)) :test #'string=)
      (let ((path (merge-pathnames (format nil "~A.lisp" name) (strategies-dir))))
        (when (probe-file path)
          (handler-case
              (with-open-file (s path :direction :input)
                (let ((*read-eval* nil))
                  (read s nil nil)))
            (error () nil))))))

;;; --- Launch ---------------------------------------------------------------

(defun launch-squad (spec)
  "Write SPEC to a temp file in the project's squads/ dir as a valid (squad ...) form."
  (let* ((project-root (uiop:getcwd))
         (squads-dir (merge-pathnames "squads/" project-root))
         (spec-path (merge-pathnames (format nil "hngh-up-~A.tmp"
                                             (random 1000000))
                                     squads-dir)))
    (ensure-directories-exist squads-dir)
    (with-open-file (stream spec-path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (format stream "(squad~%")
      (format stream "  :name ~S~%" (getf spec :name))
      (format stream "  :version ~D~%" (getf spec :version))
      (format stream "  :description ~S~%" (getf spec :description))
      (format stream "  :layout ~A~%" (string-downcase (getf spec :layout)))
      ;; Preflight
      (format stream "  :preflight~%    (")
      (loop for gate in (getf spec :preflight)
            for first = t then nil
            unless first do (format stream "~%     ")
            do (format stream "(~A~{ ~S~})"
                       (string-downcase (first gate))
                       (loop for (k v) on (rest gate) by #'cddr
                             collect k collect v)))
      (format stream ")~%")
      ;; Members
      (format stream "  :members~%    (")
      (loop for member in (getf spec :members)
            for first = t then nil
            unless first do (format stream "~%     ")
            do (format stream "(:role ~S :cli ~S :model ~S :cwd ~S :wake-template ~S)"
                       (getf member :role)
                       (getf member :cli)
                       (getf member :model)
                       (getf member :cwd)
                       (getf member :wake-template)))
      (format stream ")~%")
      ;; Journal
      (let ((journal (getf spec :journal)))
        (when journal
          (format stream "  :journal~%    (")
          (loop for entry in journal
                for first = t then nil
                unless first do (format stream "~%     ")
                do (format stream "(~S ~S)"
                           (car entry)
                           (cdr entry)))
          (format stream ")~%")))
      (format stream ")~%"))
    (format t "Launching squad: ~A~%" (getf spec :name))
    (format t "Spec written to: ~A~%" spec-path)
    (multiple-value-bind (output err-out exit-code)
        (uiop:run-program (list "squad" "up" (namestring spec-path))
                          :output :string :error-output :string
                          :ignore-error-status t)
      (format t "~A" output)
      (unless (zerop exit-code)
        (format t "~A" err-out)
        (format t "Squad launch failed (exit ~D)~%" exit-code))
      (ignore-errors (when (zerop exit-code) (delete-file spec-path)))
      exit-code)))

;;; --- C7: PM-first-prompt generator -----------------------------------------

(defun %scan-plans (cwd)
  "List files in CWD/.hermes/plans/ and return a list of (title . first-line) conses.
Returns NIL when the plans directory does not exist."
  (let ((plans-dir (merge-pathnames ".hermes/plans/" cwd)))
    (when (probe-file plans-dir)
      (loop for f in (sort (uiop:directory-files plans-dir "*.md") #'string<
                           :key #'namestring)
            collect (let ((content (handler-case
                                       (uiop:read-file-string f)
                                     (error () ""))))
                      (let* ((lines (hngh.plugins.agents-md::split-lines content))
                             (title (first lines))
                             (first-line (second lines)))
                        (cons (or title (file-namestring f))
                              (or first-line ""))))))))

(defun %scan-design-docs (cwd)
  "List files in CWD/docs/design/ and return a list of filenames.
Returns NIL when the design directory does not exist."
  (let ((design-dir (merge-pathnames "docs/design/" cwd)))
    (when (probe-file design-dir)
      (loop for f in (sort (uiop:directory-files design-dir "*.md") #'string<
                           :key #'namestring)
            collect (file-namestring f)))))

(defun %read-roadmap-status (cwd)
  "Read the first Status line from CWD/docs/project/roadmap.md.
Returns the status string (without the **Status**: prefix), or NIL."
  (let ((roadmap-path (merge-pathnames "docs/project/roadmap.md" cwd)))
    (when (probe-file roadmap-path)
      (handler-case
          (let ((content (uiop:read-file-string roadmap-path)))
            (loop for line in (hngh.plugins.agents-md::split-lines content)
                  for trimmed = (string-trim '(#\Space #\Tab #\Return) line)
                  when (search "**Status**:" trimmed)
                    return (string-trim '(#\Space #\Tab #\Return)
                                        (subseq trimmed
                                                (+ (search "**Status**:" trimmed)
                                                   (length "**Status**:"))))))
        (error () nil)))))

(defun %gather-system-context ()
  "Gather system context (GPU/VRAM) from the resource manager.
Returns a plist with :gpu-count, :gpu-name, :vram-total-mb, :vram-free-mb,
or a minimal plist when the resource manager is unavailable."
  (handler-case
      (let ((hw (hngh.core.resource-manager:hardware-info)))
        (if hw
            (let ((gpus (hngh.core.resource-manager:hardware-info-gpus hw)))
              (list :gpu-count (length gpus)
                    :gpu-name (if gpus
                                  (slot-value (first gpus) 'hngh.core.resource-manager::name)
                                  "none")
                    :vram-total-mb (if gpus
                                       (floor (slot-value (first gpus)
                                                          'hngh.core.resource-manager::vram-total)
                                              1048576)
                                       0)
                    :vram-free-mb (if gpus
                                     (floor (slot-value (first gpus)
                                                        'hngh.core.resource-manager::vram-free)
                                            1048576)
                                     0)))
            (list :gpu-count 0 :gpu-name "unknown"
                  :vram-total-mb 0 :vram-free-mb 0)))
    (error ()
      (list :gpu-count 0 :gpu-name "unknown"
            :vram-total-mb 0 :vram-free-mb 0))))

(defun %run-optmem-wake ()
  "Run `python3 ~/.optmem/memo wake` and return the last 20 lines of output.
Returns an empty string when the command fails or is unavailable."
  (handler-case
      (multiple-value-bind (output err-out exit-code)
          (uiop:run-program
           (list "python3" (namestring
                            (merge-pathnames ".optmem/memo"
                                             (user-homedir-pathname)))
                 "wake")
           :output :string :error-output :string
           :ignore-error-status t)
        (declare (ignore err-out))
        (if (zerop exit-code)
            (let* ((lines (hngh.plugins.agents-md::split-lines output))
                   (total (length lines)))
              (format nil "~{~A~^~%~}"
                      (nthcdr (max 0 (- total 20)) lines)))
            ""))
    (error () "")))

(defun %format-lifetime-policy (lifetime)
  "Return a human-readable description of the LIFETIME keyword."
  (case lifetime
    (:ephemeral
     "Ephemeral — this squad runs until the immediate goal is met, then stops.
Do not persist context beyond what is needed for the deliverable.")
    (:continual
     "Continual — this squad runs indefinitely, pausing only on budget limits,
resource pressure, or explicit human stop. Maintain durable state.")
    (:purpose-bounded
     "Purpose-bounded — this squad runs until the stated purpose is achieved
or explicitly determined to be unachievable, then shuts down cleanly.")
    (otherwise
     (format nil "~A — unknown lifetime policy" lifetime))))

(defun generate-pm-prompt (goal &key (cwd (uiop:getcwd))
                                 (lifetime :ephemeral)
                                 (squad-name "squad")
                                 (model-config nil))
  "Procedurally assemble the PM's first prompt from project/system/OptMem context.

Gathers AGENTS.md discovery/merge, plans and design docs, system context
(GPU/VRAM), roadmap status, and OptMem notes, then assembles a structured
prompt with orientation directive, context summary, roadmap state, OptMem
notes, intent, lifetime policy, and coordination protocol.

Returns a string containing the structured prompt."
  (declare (ignore model-config))
  (let* ((agents-paths (hngh.plugins.agents-md:discover-agents-md cwd))
         (merged-agents (when agents-paths
                          (hngh.plugins.agents-md:merge-agents-md agents-paths)))
         (sections (when merged-agents
                     (getf merged-agents :sections)))
         (facts (when merged-agents
                  (getf merged-agents :facts)))
         (freshness (when merged-agents
                      (getf merged-agents :freshness)))
         (plans (%scan-plans cwd))
         (design-docs (%scan-design-docs cwd))
         (roadmap-status (%read-roadmap-status cwd))
         (system-ctx (%gather-system-context))
         (optmem-notes (%run-optmem-wake))
         (parts '()))
    (push
     (format nil "# PM First Prompt — Squad: ~A~%" squad-name)
     parts)
    (push
     (format nil
             "## 1. Orientation~%~%Look around. Read AGENTS.md, check OptMem, check tasks.~%")
     parts)
    (push
     (with-output-to-string (s)
       (format s "~%## 2. Context Summary~%")
       (format s "~%### Repo~%")
       (format s "Working directory: ~A~%" (namestring cwd))
       (format s "~%### AGENTS.md Sections~%")
       (if sections
           (dolist (sec sections)
             (format s "- ~A~%" (car sec)))
           (format s "- (no AGENTS.md found)~%"))
       (when freshness
         (format s "~%Freshness date: ~A~%" freshness))
       (when facts
         (format s "~%### Key Facts~%")
         (dolist (fact facts)
           (format s "- ~A: ~A~%" (car fact) (cdr fact))))
       (format s "~%### Plans (.hermes/plans/)~%")
       (if plans
           (dolist (plan plans)
             (format s "- ~A — ~A~%" (car plan) (cdr plan)))
           (format s "- (no plans found)~%"))
       (format s "~%### Design Docs (docs/design/)~%")
       (if design-docs
           (dolist (doc design-docs)
             (format s "- ~A~%" doc))
           (format s "- (no design docs found)~%"))
       (format s "~%### System Context~%")
       (format s "GPU count: ~A~%" (getf system-ctx :gpu-count))
       (format s "GPU name: ~A~%" (getf system-ctx :gpu-name))
       (format s "VRAM total: ~A MB~%" (getf system-ctx :vram-total-mb))
       (format s "VRAM free: ~A MB~%" (getf system-ctx :vram-free-mb)))
     parts)
    (push
     (format nil "~%## 3. Roadmap State~%~%~A~%"
             (or roadmap-status "(roadmap.md not found)"))
     parts)
    (push
     (format nil "~%## 4. OptMem Notes~%~%~A~%"
             (if (and optmem-notes (string/= optmem-notes ""))
                 optmem-notes
                 "(no OptMem notes available)"))
     parts)
    (push
     (format nil "~%## 5. Intent~%~%Goal: ~A~%~%This squad exists to accomplish the above goal. ~
Understand the context, decompose the work, and coordinate the squad to deliver.~%"
             goal)
     parts)
    (push
     (format nil "~%## 6. Lifetime Policy~%~%~A~%"
             (%format-lifetime-policy lifetime))
     parts)
    (push
     (with-output-to-string (s)
       (format s "~%## 7. Coordination Protocol~%")
       (format s "~%After orientation, seed guidance for other roles:~%")
       (format s "- Write role-specific instructions to AGENTS.md sections~%")
       (format s "- Use OptMem notes for durable, shared context~%")
       (format s "- Each role reads AGENTS.md and OptMem on startup~%")
       (format s "- Files are shared state; events are messages~%"))
     parts)
    (apply #'concatenate 'string (nreverse parts))))

;;; --- Command entry point ---------------------------------------------------

(defun cmd-up (goal &key hngh-home strategy-name (dry-run nil) (list-strategies-p nil))
  "Main entry point for `hngh up <goal>`."
  (when list-strategies-p
    (format t "Built-in strategies:~%")
    (dolist (s *built-in-strategies*)
      (format t "  ~A — ~A~%" (getf s :name) (getf s :description)))
    (let ((user-dir (strategies-dir hngh-home)))
      (when (probe-file user-dir)
        (format t "~%User strategies:~%")
        (dolist (f (uiop:directory-files user-dir "*.lisp"))
          (format t "  ~A~%" (pathname-name f)))))
    (return-from cmd-up t))

  (unless (and goal (string/= goal ""))
    (format t "Error: goal required~%")
    (return-from cmd-up nil))

  (let* ((context (gather-context goal))
         (agents-md (gather-agents-md-context (getf context :project-root)))
         (questions (generate-questionnaire context))
         (answers (render-questionnaire questions agents-md)))
    ;; Apply strategy override if specified
    (when strategy-name
      (let ((strategy (load-strategy strategy-name)))
        (when strategy
          (let ((defaults (getf strategy :defaults)))
            (when defaults
              (dolist (pair defaults)
                (setf (getf answers (car pair)) (cdr pair))))))))

    (let ((spec (derive-squad-spec answers goal context)))
      (format t "~%Derived squad spec:~%")
      (format t "  Name: ~A~%" (getf spec :name))
      (format t "  Layout: ~A~%" (getf spec :layout))
      (format t "  Members:~%")
      (dolist (m (getf spec :members))
        (format t "    ~A — ~A/~A @ ~A~%"
                (getf m :role) (getf m :cli) (getf m :model) (getf m :cwd)))

      (cond
        (dry-run
         (format t "~%Dry run — not launching.~%")
         (format t "~%--- PM First Prompt ---~%")
         (format t "~A~%"
                 (generate-pm-prompt goal
                                     :cwd (getf context :project-root)
                                     :squad-name (getf spec :name))))
        (t
         (launch-squad spec)))

      spec)))

;;; --- Plugin lifecycle ------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the hngh-up plugin."
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Hngh-up plugin initialized")
  t)

(defun shutdown ()
  "Shut down the hngh-up plugin."
  (setf *running* nil)
  (hngh.core:log-info "Hngh-up plugin shut down")
  t)

(defun running-p ()
  "Return T if the plugin is active."
  *running*)

(defun status ()
  "Return a plist with plugin status."
  (list :running *running*))
