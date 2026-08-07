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
      :options '(("local-only" "Local only, zero cost (Qwen-AgentWorld-35B queued)")
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
     ("hermes" . "unsloth/Qwen-AgentWorld-35B-A3B-GGUF")
     ("opencode" . "unsloth-local/unsloth/Qwen-AgentWorld-35B-A3B-GGUF"))
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

(defvar *optmem-wake-cache* nil
  "Cached OptMem wake output. Refreshed once per plugin lifetime so
repeated fills (T11 loops 36 skeletons, five of them PM) don't spawn a
subprocess per fill. OptMem notes change rarely; the cache is honest.")

(defun %run-optmem-wake ()
  "Run `python3 ~/.optmem/memo wake` and return the last 20 lines of output.
Returns an empty string when the command fails or is unavailable."
  (or *optmem-wake-cache*
      (setf *optmem-wake-cache*
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
                (error () "")))))

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
  "Backward-compatible entry point. Delegates to generate-prompt with
:role :pm :scenario :startup."
  (declare (ignore model-config))
  (let ((dimensions (make-prompt-dimensions
                     :role :pm
                     :scenario :startup
                     :strategy (select-strategy-from-goal goal)
                     :resources :budget-50
                     :squad-count 1
                     :roles-active '(:pm)
                     :lifetime lifetime
                     :directory (select-directory cwd)
                     :system (select-system)
                     :purpose goal)))
    (generate-prompt dimensions :squad-name squad-name)))

;;; --- W5: Prompt matrix (skeleton-bones-flesh) ------------------------------
;;;
;;;; Implements docs/design/prompt-matrix.md: generate-prompt, the 36-skeleton
;;;; library, deterministic bone fillers, the optional flesh pass, per-role
;;;; model selection synced to D-040, and the prompt cache.
;;;; Attribution: W5 build — deepseek-v4-flash-0731 via deepseek (Hermes TUI)

(defstruct prompt-dimensions
  role          ; keyword: :pm | :designer | :coder | :artist | :accountant | :worker
  scenario      ; keyword: :startup | :task-assign | :status-check | :review | :shutdown | :unblock
  strategy      ; keyword: :duo-review | :feature-sprint | :design-fork | :nightly-audit
  resources     ; keyword: :local-only | :budget-50 | :budget-200 | :unlimited
  squad-count   ; integer
  roles-active  ; list of keywords
  lifetime      ; keyword: :ephemeral | :continual | :purpose-bounded
  directory     ; plist: (:cwd path :agents-md-sections list :plans list :designs list)
  system        ; plist: (:gpu-count n :vram-total-mb n :vram-free-mb n :local-models list :systemd-units list)
  purpose)      ; string: the goal

;;; --- Skeleton library ------------------------------------------------------

(defparameter *skeleton-library* (make-hash-table :test 'equal)
  "Key: (role . scenario) cons. Value: template string with {{slot}} markers.")

(defun skeleton-key (role scenario)
  (cons role scenario))

(defun get-skeleton (role scenario)
  "Return the template string for ROLE×SCENARIO, or NIL if undefined."
  (gethash (skeleton-key role scenario) *skeleton-library*))

(defparameter *skeleton-templates*
  '(((:pm . :startup)
     . "# {{role}} First Prompt — Squad: {{squad-name}}

## 1. Orientation

Look around. Read AGENTS.md, check OptMem, check tasks. You are the PM.
Your job: orient, decompose, dispatch, monitor, review.

## 2. Context Summary

### Repo
Working directory: {{cwd}}

### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Plans (.hermes/plans/)
{{plans}}

### Design Docs (docs/design/)
{{design-docs}}

### System Context
{{system-context}}

## 3. Roadmap State
{{roadmap-status}}

## 4. OptMem Notes
{{optmem-notes}}

## 5. Intent
Goal: {{goal}}

This squad exists to accomplish the above goal. Understand the context,
decompose the work, and coordinate the squad to deliver.

## 6. Lifetime Policy
{{lifetime-policy}}

## 7. Model Recommendations
{{model-recommendations}}

## 8. Coordination Protocol
{{coordination-protocol}}

## 9. Bean Vocabulary
{{bean-vocabulary}}")
    ((:designer . :startup)
     . "# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Designer. Read AGENTS.md, understand the squad goal, check
your inbox for task beans. Your role: decompose goals into specs, design
systems, write design docs.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Design Request
{{task-title}}

## 4. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Plans
{{plans}}

### Design Docs
{{design-docs}}

### Roadmap
{{roadmap-status}}

### System
{{system-context}}

## 5. Dependencies
{{task-preconditions}}

## 6. Aesthetic Direction
{{aesthetic-brief}}

## 7. Bean Vocabulary
{{bean-vocabulary}}

## 8. Model Assignment
{{model-recommendations}}

## 9. Build & Test
{{build-test-commands}}

## 10. Attribution
{{task-attribution}}")
    ((:coder . :startup)
     . "# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Coder. Read AGENTS.md, check your inbox for task beans, run
`make build && make test` to verify the baseline. Your role: implement
from specs, write tests, keep make test green.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Task Spec
{{task-title}}

## 4. Preconditions
{{task-preconditions}}

## 5. Files
{{task-files}}

## 6. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Plans
{{plans}}

### Roadmap
{{roadmap-status}}

### System
{{system-context}}

## 7. Conventions
{{build-test-commands}}
{{coordination-protocol}}

## 8. Bean Vocabulary
{{bean-vocabulary}}

## 9. Model Assignment
{{model-recommendations}}

## 10. Attribution
{{task-attribution}}")
    ((:artist . :startup)
     . "# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Artist. Read AGENTS.md, check your inbox for design beans.
Your role: transmute design concepts into visual artifacts — ASCII art,
diagrams, aesthetic assets.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Aesthetic Brief
{{aesthetic-brief}}

## 4. Visual References
{{visual-references}}

## 5. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Design Docs
{{design-docs}}

### Roadmap
{{roadmap-status}}

### System
{{system-context}}

## 6. Constraints
{{constraints}}

## 7. Bean Vocabulary
{{bean-vocabulary}}

## 8. Model Assignment
{{model-recommendations}}

## 9. Attribution
{{task-attribution}}")
    ((:accountant . :startup)
     . "# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Accountant. Read AGENTS.md, check your inbox for audit
requests. Your role: track costs, audit husks, monitor squad health,
detect spoilage and feral outbreaks.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Cost Audit Request
{{cost-audit-request}}

## 4. Resource Snapshot
### System
{{system-context}}

### Budget
{{budget}}

## 5. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Roadmap
{{roadmap-status}}

## 6. Bean Vocabulary
{{bean-vocabulary}}

## 7. Model Assignment
{{model-recommendations}}

## 8. Attribution
{{task-attribution}}")
    ((:worker . :startup)
     . "# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Worker. Read AGENTS.md, check your inbox for task beans.
Your role: forage batch tasks, digest them, produce status beans.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Task Batch
{{task-batch}}

## 4. Preconditions
{{task-preconditions}}

## 5. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Roadmap
{{roadmap-status}}

## 6. Conventions
{{build-test-commands}}
{{coordination-protocol}}

## 7. Bean Vocabulary
{{bean-vocabulary}}

## 8. Model Assignment
{{model-recommendations}}

## 9. Attribution
{{task-attribution}}")
    ((:pm . :task-assign)
     . "# {{role}} Task Dispatch — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}
Assigned to: {{role}}
Files: {{task-files}}

## Acceptance Criteria
{{task-acceptance}}

## Preconditions
{{task-preconditions}}

## Context
{{agents-md-sections}}
{{roadmap-status}}
{{optmem-notes}}

## Attribution
{{task-attribution}}")
    ((:designer . :task-assign)
     . "# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Files
{{task-files}}

## Acceptance Criteria
{{task-acceptance}}

## Preconditions
{{task-preconditions}}

## Context
Working directory: {{cwd}}
{{agents-md-sections}}
{{design-docs}}
{{roadmap-status}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}")
    ((:coder . :task-assign)
     . "# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Files
{{task-files}}

## Acceptance Criteria
{{task-acceptance}}

## Preconditions
{{task-preconditions}}

## Context
Working directory: {{cwd}}
{{agents-md-key-facts}}
{{build-test-commands}}
{{coordination-protocol}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}")
    ((:artist . :task-assign)
     . "# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Aesthetic Brief
{{aesthetic-brief}}

## Visual References
{{visual-references}}

## Acceptance Criteria
{{task-acceptance}}

## Constraints
{{constraints}}

## Context
Working directory: {{cwd}}
{{design-docs}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}")
    ((:accountant . :task-assign)
     . "# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Cost Audit Scope
{{cost-audit-request}}

## Resource Snapshot
{{resource-snapshot}}
{{budget}}

## Acceptance Criteria
{{task-acceptance}}

## Context
Working directory: {{cwd}}
{{agents-md-sections}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}")
    ((:worker . :task-assign)
     . "# {{role}} Task — Squad: {{squad-name}}

## Task Batch
ID: {{task-id}}
{{task-batch}}

## Preconditions
{{task-preconditions}}

## Acceptance Criteria
{{task-acceptance}}

## Context
Working directory: {{cwd}}
{{agents-md-key-facts}}
{{build-test-commands}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}")
    ((:pm . :status-check)
     . "# {{role}} Status Check — Squad: {{squad-name}}

## Roles
{{roles-active}}

## System
{{system-context}}
{{budget}}

## OptMem
{{optmem-notes}}

## Roadmap
{{roadmap-status}}

## Action Required
Review dispatch tree, check for stale beans, re-dispatch or adjust.")
    ((:designer . :status-check)
     . "# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Report your current state: digesting, fallow, or blocked.

## Context
{{cwd}}
{{design-docs}}
{{roadmap-status}}")
    ((:coder . :status-check)
     . "# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Run `make test`. Report: green/red, what changed, what's next.

## Context
{{cwd}}
{{build-test-commands}}")
    ((:artist . :status-check)
     . "# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Report: transmuting, rendering, or fallow.

## Context
{{design-docs}}")
    ((:accountant . :status-check)
     . "# {{role}} Status Check — Squad: {{squad-name}}

## Audit Status
Report: husk pile depth, spoilage detected, budget consumed.

## Resource Snapshot
{{resource-snapshot}}
{{budget}}")
    ((:worker . :status-check)
     . "# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Report: foraging, digesting, or fallow.

## Context
{{cwd}}")
    ((:pm . :review)
     . "# {{role}} Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Severity Levels
{{severity-levels}}

## Verdict Format
{{verdict-format}}

## Context
{{roadmap-status}}
{{optmem-notes}}")
    ((:designer . :review)
     . "# {{role}} Design Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Severity Levels
{{severity-levels}}

## Context
{{design-docs}}
{{roadmap-status}}")
    ((:coder . :review)
     . "# {{role}} Code Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Severity Levels
{{severity-levels}}

## Context
{{cwd}}
{{build-test-commands}}")
    ((:artist . :review)
     . "# {{role}} Art Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Aesthetic Standards
{{aesthetic-brief}}

## Context
{{design-docs}}")
    ((:accountant . :review)
     . "# {{role}} Audit Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Cost Audit
{{cost-audit-request}}
{{budget}}")
    ((:worker . :review)
     . "# {{role}} Output Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Context
{{cwd}}")
    ((:pm . :shutdown)
     . "# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Final Status
Report: squad summary, what was accomplished, what remains.

## Attribution
{{task-attribution}}")
    ((:designer . :shutdown)
     . "# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Context
{{design-docs}}
{{roadmap-status}}

## Attribution
{{task-attribution}}")
    ((:coder . :shutdown)
     . "# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Final State
Run `make test`. Report final status.

## Context
{{cwd}}
{{build-test-commands}}

## Attribution
{{task-attribution}}")
    ((:artist . :shutdown)
     . "# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Context
{{design-docs}}

## Attribution
{{task-attribution}}")
    ((:accountant . :shutdown)
     . "# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Final Audit
Report: total cost, husk count, spoilage rate.

## Attribution
{{task-attribution}}")
    ((:worker . :shutdown)
     . "# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Context
{{cwd}}

## Attribution
{{task-attribution}}")
    ((:pm . :unblock)
     . "# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{optmem-notes}}
{{roadmap-status}}")
    ((:designer . :unblock)
     . "# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{design-docs}}
{{roadmap-status}}")
    ((:coder . :unblock)
     . "# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{cwd}}
{{build-test-commands}}")
    ((:artist . :unblock)
     . "# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{design-docs}}")
    ((:accountant . :unblock)
     . "# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}
{{budget}}

## Suggested Paths
{{suggested-paths}}")
    ((:worker . :unblock)
     . "# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{cwd}}"))
  "All 36 skeleton templates, keyed by (role . scenario).")

(defun initialize-skeletons ()
  "Populate *skeleton-library* from *skeleton-templates*."
  (dolist (pair *skeleton-templates*)
    (setf (gethash (car pair) *skeleton-library*) (cdr pair))))

(initialize-skeletons)

;;; --- Bean vocabulary and aesthetic briefs ----------------------------------

(defparameter *bean-vocabulary*
  '((:pm
     "You are the Planter. Plant beans in role pods. Cultivate, distribute, prune, cull stale chains. Vocabulary: plant, cultivate, distribute, prune, graft, cull.")
    (:designer
     "You are the Fermenter. Receive mixed beans, ferment them into design beans. Vocabulary: ferment, refine, distill, culture, age.")
    (:coder
     "You are the Mason. Digest task beans, lay them into structure. Vocabulary: lay, stack, mortar, fire, reject.")
    (:artist
     "You are the Transmuter. Consume design beans, transmute into artifact beans. Vocabulary: transmute, render, shape, kiln, glaze.")
    (:accountant
     "You are the Comptroller of Husks. Audit husk piles, track nutritional flow, detect spoilage and feral outbreaks. Vocabulary: audit, weigh, trace, cull, ration.")
    (:worker
     "You are the Forager. Digest whatever beans are planted. Vocabulary: forage, eat, gnaw, scavenge."))
  "Bean vernacular per role from beans-aesthetic.md.")

(defparameter *aesthetic-briefs*
  '((:pm "Dark palette. Monospace structural. The megastructure is the ecosystem. Pods are growth chambers.")
    (:designer "Beans are organic. Use biological language for machine processes. Dark palette, nutrient-dense, industrial.")
    (:coder "Stack digested bean-material into structure. Architectural vocabulary. Fire = compile/test.")
    (:artist "Glossy-organic meets matte-metal. Cysts, seeds, nutrient pellets in a biotech corridor. Dark palette.")
    (:accountant "The pathologist. Read husks to understand what the squad ate, what it refused, what made it sick.")
    (:worker "Forager aesthetic. High throughput, low specialization. Scavenge, gnaw, digest."))
  "Aesthetic direction per role from beans-aesthetic.md.")

(defparameter *role-token-estimates*
  '((:pm          . 50000)
    (:designer    . 50000)
    (:coder       . 100000)
    (:artist      . 20000)
    (:accountant  . 10000)
    (:worker      . 50000))
  "Rough token estimates per role for cost projection.")

(defun estimate-role-tokens (role dimensions)
  "Return estimated token count for ROLE in the given scenario."
  (declare (ignore dimensions))
  (or (getf *role-token-estimates* role) 30000))

;;; --- Model selection (D-040 synced) ----------------------------------------

(defparameter *per-role-fallback-chains*
  '((:pm
     ((:name "glm-5.2" :provider "openrouter" :input-cost 0.40 :output-cost 0.40 :capability 8.5 :local-p nil)
      (:name "deepseek-v4-flash-0731" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.5 :local-p nil)
      (:name "deepseek-v4-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.14 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "openai" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "nvidia/nemotron-3-ultra-550b-a55b:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 7.5 :local-p nil)
      (:name "google/gemma-4-31b-it:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 7.0 :local-p nil)))
    (:designer
     ((:name "glm-5.2" :provider "openrouter" :input-cost 0.40 :output-cost 0.40 :capability 8.5 :local-p nil)
      (:name "deepseek-v4-flash-0731" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.5 :local-p nil)
      (:name "deepseek-v4-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.14 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "openai" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "google/gemma-4-31b-it:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 7.0 :local-p nil)
      (:name "nvidia/nemotron-3-super-120b-a12b:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 7.0 :local-p nil)
      (:name "unsloth/Qwen-AgentWorld-35B-A3B-GGUF" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.5 :local-p t)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t)))
    (:coder
     ((:name "deepseek-v4-flash-0731" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.5 :local-p nil)
      (:name "deepseek-v4-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.14 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "openai" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "xiaomi/mimo-v2.5" :provider "openrouter" :input-cost 0.435 :output-cost 0.435 :capability 7.0 :local-p nil)
      (:name "minimax/minimax-m3" :provider "openrouter" :input-cost 0.20 :output-cost 0.20 :capability 7.0 :local-p nil)
      (:name "openai/gpt-oss-20b:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.5 :local-p nil)
      (:name "poolside/laguna-s-2.1:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.5 :local-p nil)
      (:name "cohere/north-mini-code:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.0 :local-p nil)
      (:name "unsloth/Qwen-AgentWorld-35B-A3B-GGUF" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.5 :local-p t)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t)))
    (:artist
     ((:name "deepseek-v4-flash-0731" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.5 :local-p nil)
      (:name "qwen3.7-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.0 :local-p nil)
      (:name "xiaomi/mimo-v2.5" :provider "openrouter" :input-cost 0.435 :output-cost 0.435 :capability 7.0 :local-p nil)
      (:name "minimax/minimax-m3" :provider "openrouter" :input-cost 0.20 :output-cost 0.20 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "openai" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "google/gemma-4-31b-it:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 7.0 :local-p nil)
      (:name "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.0 :local-p nil)
      (:name "nvidia/nemotron-nano-12b-v2-vl:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 5.5 :local-p nil)))
    (:accountant
     ((:name "deepseek-v4-flash-0731" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.5 :local-p nil)
      (:name "deepseek-v4-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.14 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "openai" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "openai/gpt-oss-20b:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.5 :local-p nil)
      (:name "google/gemma-4-26b-a4b-it:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.5 :local-p nil)
      (:name "unsloth/Qwen-AgentWorld-35B-A3B-GGUF" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.5 :local-p t)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t)))
    (:worker
     ((:name "deepseek-v4-flash-0731" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.5 :local-p nil)
      (:name "deepseek-v4-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.14 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "openai" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "xiaomi/mimo-v2.5" :provider "openrouter" :input-cost 0.435 :output-cost 0.435 :capability 7.0 :local-p nil)
      (:name "minimax/minimax-m3" :provider "openrouter" :input-cost 0.20 :output-cost 0.20 :capability 7.0 :local-p nil)
      (:name "google/gemma-4-26b-a4b-it:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.5 :local-p nil)
      (:name "cohere/north-mini-code:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.0 :local-p nil)
      (:name "inclusionai/ling-3.0-tiny:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 5.5 :local-p nil)
      (:name "unsloth/Qwen-AgentWorld-35B-A3B-GGUF" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.5 :local-p t)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t))))
  "Per-role model fallback chains from model-pareto.md §3 (2026-08-05 mandate,
2026-08-06 free-tier refresh). Paid heads first, then the best free models
distributed across vendors (OpenRouter :free catalog, checked 2026-08-06),
then local. Ordered by capability within each tier. Artist has no local
fallback (never local).")

(defun estimate-model-cost (model role)
  "Estimate the cost in dollars of MODEL running ROLE's token budget."
  (* (getf model :input-cost)
     (/ (or (getf *role-token-estimates* role) 30000) 1000000.0)))

(defun role-allows-local-p (role scenario &optional (resources nil))
  "Return T when the role allows local models for this scenario.
When RESOURCES is :local-only, local is the last resort (no remotes),
so any local-capable role may use it regardless of scenario."
  (if (eq resources :local-only)
      (member role '(:designer :coder :accountant :worker))
      (case role
        (:pm nil)  ; never (last resort, handled by caller)
        (:artist nil)  ; never
        (:designer (member scenario '(:status-check :shutdown)))
        (:coder (member scenario '(:status-check :shutdown)))
        (:accountant (member scenario '(:status-check :shutdown)))
        (:worker (member scenario '(:status-check :shutdown :task-assign)))
        (t nil))))

(defun budget-from-resources (resources)
  "Derive the dollar budget from the RESOURCES dimension keyword.
:local-only → 0, :budget-50 → 0.50, :budget-200 → 2.00, :unlimited → NIL."
  (case resources
    (:local-only 0)
    (:budget-50 0.50)
    (:budget-200 2.00)
    (:unlimited nil)
    (otherwise nil)))

(defun check-model-gates (model scenario budget-remaining vram-free role resources)
  "Return T when MODEL passes all dispatch gates for this ROLE/SCENARIO."
  (cond
    ;; Local model: check VRAM + role policy
    ((getf model :local-p)
     (and (or (and vram-free
                   (>= vram-free (hngh.plugins.squad-resources:model-vram-mb
                                  (getf model :name))))
              (null vram-free))  ; no telemetry → don't block
          (role-allows-local-p role scenario resources)))
    ;; Remote model: local-only blocks ALL remotes (free or paid);
    ;; otherwise check budget
    ((eq resources :local-only)
     nil)
    (t
     (let ((est-cost (estimate-model-cost model role)))
       (or (null budget-remaining)  ; unknown budget → don't block
           (>= budget-remaining est-cost))))))

(defun evaluate-fallback-chain (role dimensions)
  "Try each model in the role's fallback chain. Return the first that passes
all gates, or NIL if exhausted."
  (let ((chain (second (assoc role *per-role-fallback-chains*)))
        (scenario (prompt-dimensions-scenario dimensions))
        (vram-free (getf (prompt-dimensions-system dimensions) :vram-free-mb))
        (resources (prompt-dimensions-resources dimensions))
        (budget (budget-from-resources (prompt-dimensions-resources dimensions))))
    (loop for model in chain
          for passes = (check-model-gates model scenario budget vram-free role resources)
          when passes return model
          finally (return nil))))

(defun select-role-model (role dimensions)
  "Select the best model for ROLE from the Pareto table, checking VRAM,
budget, and time-sensitivity.

Returns a plist: (:name <string> :provider <string> :input-cost <number>
                  :output-cost <number> :capability <number> :local-p <boolean>)
or NIL if no model can be assigned."
  (evaluate-fallback-chain role dimensions))

;;; --- Dimension selection ---------------------------------------------------

(defun select-directory (cwd)
  "Scan CWD into a directory dimension plist."
  (list :cwd cwd
        :agents-md-sections
        (let ((ctx (gather-agents-md-context cwd)))
          (when ctx (getf ctx :sections)))
        :plans (%scan-plans cwd)
        :designs (%scan-design-docs cwd)))

(defvar *systemd-units-cache* nil
  "Cached running-user-service list. Refreshed once per plugin lifetime;
the unit set changes rarely and caching keeps repeated prompt fills cheap.")

(defun %running-user-services ()
  "List running user systemd services, or NIL when systemctl is unavailable."
  (or *systemd-units-cache*
      (setf *systemd-units-cache*
            (handler-case
                (let ((output (uiop:run-program
                               '("systemctl" "--user" "list-units" "--type=service"
                                 "--state=running" "--no-legend")
                               :output :string :error-output :string
                               :ignore-error-status t)))
                  (loop for line in (hngh.plugins.agents-md::split-lines output)
                        for unit = (first (cl-ppcre:split "\\s+" (string-trim " " line)))
                        when (and unit (search ".service" unit)) collect unit))
              (error () nil)))))

(defun select-system ()
  "Gather the system dimension plist: GPU/VRAM plus running user services."
  (let ((ctx (%gather-system-context)))
    (list :gpu-count (getf ctx :gpu-count)
          :gpu-name (getf ctx :gpu-name)
          :vram-total-mb (getf ctx :vram-total-mb)
          :vram-free-mb (getf ctx :vram-free-mb)
          :local-models (list "unsloth/Qwen-AgentWorld-35B-A3B-GGUF"
                              "unsloth/Ornith-1.0-35B-GGUF"
                              "unsloth/Ornith-1.0-9B-GGUF"
                              "unsloth/gemma-4-12b-it-qat-GGUF")
          :systemd-units (%running-user-services))))

(defun select-strategy-from-goal (goal)
  "Map a goal string to a strategy keyword."
  (cond
    ((or (search "review" goal) (search "audit" goal)) :duo-review)
    ((or (search "implement" goal) (search "build" goal)) :feature-sprint)
    ((or (search "design" goal) (search "decide" goal)) :design-fork)
    ((or (search "monitor" goal) (search "overnight" goal)) :nightly-audit)
    (t :duo-review)))

;;; --- Bone fillers ----------------------------------------------------------

(defun %directory-cwd (dimensions)
  "Return the working directory pathname from DIMENSIONS, or the process cwd."
  (or (getf (prompt-dimensions-directory dimensions) :cwd)
      (uiop:getcwd)))

(defun fill-role (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (string-downcase (prompt-dimensions-role dimensions)))

(defun fill-squad-name (dimensions task-spec squad-name)
  (declare (ignore dimensions task-spec))
  (or squad-name "squad"))

(defun fill-model (dimensions task-spec squad-name)
  (declare (ignore squad-name))
  (or (getf task-spec :model)
      (getf (select-role-model (prompt-dimensions-role dimensions) dimensions)
            :name)
      "unavailable"))

(defun fill-provider (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (getf (select-role-model (prompt-dimensions-role dimensions) dimensions)
        :provider))

(defun fill-cwd (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (namestring (%directory-cwd dimensions)))

(defun fill-agents-md-sections (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((ctx (gather-agents-md-context (%directory-cwd dimensions))))
    (if ctx
        (let ((sections (getf ctx :sections)))
          (if sections
              (with-output-to-string (s)
                (dolist (sec sections)
                  (format s "- ~A~%" (car sec))))
              "- (no AGENTS.md sections found)"))
        "- (no AGENTS.md found)")))

(defun fill-agents-md-key-facts (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((ctx (gather-agents-md-context (%directory-cwd dimensions))))
    (if ctx
        (let ((facts (getf ctx :facts)))
          (if facts
              (with-output-to-string (s)
                (dolist (fact facts)
                  (format s "- ~A: ~A~%" (car fact) (cdr fact))))
              "- (no key facts found)"))
        "- (no AGENTS.md found)")))

(defun fill-plans (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((plans (%scan-plans (%directory-cwd dimensions))))
    (if plans
        (with-output-to-string (s)
          (dolist (plan plans)
            (format s "- ~A — ~A~%" (car plan) (cdr plan))))
        "- (no plans found)")))

(defun fill-design-docs (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((docs (%scan-design-docs (%directory-cwd dimensions))))
    (if docs
        (with-output-to-string (s)
          (dolist (doc docs)
            (format s "- ~A~%" doc)))
        "- (no design docs found)")))

(defun fill-roadmap-status (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (or (%read-roadmap-status (%directory-cwd dimensions))
      "(roadmap.md not found)"))

(defun fill-system-context (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((sys (prompt-dimensions-system dimensions)))
    (if (and sys (getf sys :gpu-count))
        (format nil "GPU count: ~A~%GPU name: ~A~%VRAM total: ~A MB~%VRAM free: ~A MB"
                (getf sys :gpu-count)
                (or (getf sys :gpu-name) "unknown")
                (or (getf sys :vram-total-mb) 0)
                (or (getf sys :vram-free-mb) 0))
        (let ((ctx (%gather-system-context)))
          (format nil "GPU count: ~A~%GPU name: ~A~%VRAM total: ~A MB~%VRAM free: ~A MB"
                  (getf ctx :gpu-count)
                  (getf ctx :gpu-name)
                  (getf ctx :vram-total-mb)
                  (getf ctx :vram-free-mb))))))

(defun fill-optmem-notes (dimensions task-spec squad-name)
  (declare (ignore dimensions task-spec squad-name))
  (let ((notes (%run-optmem-wake)))
    (if (and notes (string/= notes ""))
        notes
        "(no OptMem notes available)")))

(defun fill-goal (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (or (prompt-dimensions-purpose dimensions) "(no goal specified)"))

(defun fill-lifetime-policy (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (%format-lifetime-policy (prompt-dimensions-lifetime dimensions)))

(defun fill-task-id (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :id) "(no task assigned)"))

(defun fill-task-title (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :title) "(no task assigned)"))

(defun fill-task-files (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (let ((files (getf task-spec :files)))
    (if files
        (with-output-to-string (s)
          (dolist (f files)
            (format s "- ~A~%" f)))
        "- (none specified)")))

(defun fill-task-acceptance (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :acceptance) "(none specified)"))

(defun fill-task-preconditions (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :preconditions) "(none)"))

(defun fill-task-attribution (dimensions task-spec squad-name)
  (declare (ignore squad-name))
  (let ((role (string-capitalize (fill-role dimensions nil nil)))
        (model (or (getf task-spec :model)
                   (getf (select-role-model (prompt-dimensions-role dimensions)
                                            dimensions)
                         :name)
                   "unavailable")))
    (format nil "~A — ~A, Hermes harness" role model)))

(defun fill-bean-vocabulary (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (or (getf *bean-vocabulary* (prompt-dimensions-role dimensions))
      "(no bean vocabulary for this role)"))

(defun %role-display-name (role)
  "Render a role keyword as a display name: :pm → \"PM\", :coder → \"Coder\"."
  (case role
    (:pm "PM")
    (t (string-capitalize (string-downcase role)))))

(defun fill-model-recommendations (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((roles (prompt-dimensions-roles-active dimensions))
        (rows '()))
    (dolist (role roles)
      (let* ((model (select-role-model role dimensions))
             (model-name (getf model :name))
             (cost-per-m (getf model :input-cost))
             (est-tokens (estimate-role-tokens role dimensions))
             (est-cost (if (and cost-per-m model-name)
                           (/ (* cost-per-m est-tokens) 1000000.0)
                           0)))
        (push (list role model-name cost-per-m est-tokens est-cost) rows)))
    (setf rows (nreverse rows))
    (with-output-to-string (s)
      (format s "## Model recommendations~%~%")
      (format s "| Role | Model | $/M | Est. tokens | Est. cost |~%")
      (format s "|---|---|---|---|---|~%")
      (let ((total 0))
        (dolist (row rows)
          (let ((role-name (%role-display-name (first row))))
            (if (second row)
                (format s "| ~A | ~A | ~,2F | ~DK | $~,3F |~%"
                        role-name (second row) (third row)
                        (floor (fourth row) 1000) (fifth row))
                (format s "| ~A | unavailable | — | — | — |~%" role-name)))
          (incf total (fifth row)))
        (format s "~%Total estimated cost: $~,3F~%" total)
        (let ((budget (budget-from-resources (prompt-dimensions-resources dimensions))))
          (format s "Budget gate: ~A~%"
                  (cond
                    ((and budget (> budget total))
                     (format nil "passes ($~,3F available, $~,3F needed)" budget total))
                    ((null budget)
                     "unknown (no budget tracking)")
                    (t "FAILED — downgrade models along fallback chain"))))))))

(defun fill-coordination-protocol (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((body (%section-body-matching
               (gather-agents-md-context (%directory-cwd dimensions))
               "coordination")))
    (if body
        body
        (format nil "~%After orientation, seed guidance for other roles:~%
- Write role-specific instructions to AGENTS.md sections~%
- Use OptMem notes for durable, shared context~%
- Each role reads AGENTS.md and OptMem on startup~%
- Files are shared state; events are messages~%"))))

(defun fill-build-test-commands (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((body (%section-body-matching
               (gather-agents-md-context (%directory-cwd dimensions))
               "repo notes")))
    (if (and body (search "make" body))
        (with-output-to-string (s)
          (dolist (line (hngh.plugins.agents-md::split-lines body))
            (when (search "make" line)
              (format s "~A~%" (string-trim '(#\Space #\Tab) line)))))
        "Build: make build. Test: make test.")))

(defun fill-review-criteria (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :review-criteria) "(use standard code review criteria)"))

(defun fill-severity-levels (dimensions task-spec squad-name)
  (declare (ignore dimensions task-spec squad-name))
  "blocker — must fix before merge
major — should fix before merge
minor — can fix later
nit — optional")

(defun fill-verdict-format (dimensions task-spec squad-name)
  (declare (ignore dimensions task-spec squad-name))
  "Verdict: APPROVE | REQUEST_CHANGES | BLOCK
Reasoning: <one paragraph>
Issues: <list or none>")

(defun fill-blocker-description (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :blocker) "(no blocker described)"))

(defun fill-available-resources (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (format nil "~A~%Budget: ~A"
          (fill-system-context dimensions nil nil)
          (fill-budget dimensions nil nil)))

(defun fill-suggested-paths (dimensions task-spec squad-name)
  (declare (ignore dimensions task-spec squad-name))
  "1. Re-read AGENTS.md for updated context
2. Check OptMem for shared notes
3. Request help from a sibling role
4. Escalate to PM")

(defun fill-fragment-journal (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :fragment-journal-path) "(no journal path)"))

(defun fill-resume-hint (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :resume-hint)
      "Re-read your last inbox messages and continue."))

(defun fill-value-captured (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :value-captured) "(summarize what was accomplished)"))

(defun fill-aesthetic-brief (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (or (getf *aesthetic-briefs* (prompt-dimensions-role dimensions))
      "(no aesthetic brief for this role)"))

(defun fill-visual-references (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :visual-references) "(none provided)"))

(defun fill-constraints (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :constraints) "(none specified)"))

(defun fill-cost-audit-request (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (or (getf task-spec :audit-scope)
      "Audit: squad cost tracking, husk quality, spoilage detection."))

(defun fill-resource-snapshot (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (format nil "~A~%~A"
          (fill-system-context dimensions nil nil)
          (fill-budget dimensions nil nil)))

(defun fill-budget (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((budget (budget-from-resources (prompt-dimensions-resources dimensions))))
    (if budget
        (format nil "Budget remaining: $~,2F / $1.00 daily" budget)
        "(budget tracking unavailable)")))

(defun fill-task-batch (dimensions task-spec squad-name)
  (declare (ignore dimensions squad-name))
  (let ((batch (getf task-spec :batch)))
    (if batch
        (with-output-to-string (s)
          (loop for item in batch
                for i from 1
                do (format s "~D. ~A~%" i item)))
        "(no batch tasks)")))

(defun fill-roles-active (dimensions task-spec squad-name)
  (declare (ignore task-spec squad-name))
  (let ((roles (prompt-dimensions-roles-active dimensions)))
    (if roles
        (with-output-to-string (s)
          (dolist (r roles)
            (format s "- ~A~%" (string-downcase r))))
        "- (no active roles)")))

(defparameter *bone-fillers*
  '((:role                . fill-role)
    (:squad-name           . fill-squad-name)
    (:model                . fill-model)
    (:provider             . fill-provider)
    (:cwd                  . fill-cwd)
    (:agents-md-sections   . fill-agents-md-sections)
    (:agents-md-key-facts  . fill-agents-md-key-facts)
    (:plans                . fill-plans)
    (:design-docs          . fill-design-docs)
    (:roadmap-status       . fill-roadmap-status)
    (:system-context       . fill-system-context)
    (:optmem-notes         . fill-optmem-notes)
    (:goal                 . fill-goal)
    (:lifetime-policy      . fill-lifetime-policy)
    (:task-id              . fill-task-id)
    (:task-title           . fill-task-title)
    (:task-files           . fill-task-files)
    (:task-acceptance      . fill-task-acceptance)
    (:task-preconditions   . fill-task-preconditions)
    (:task-attribution     . fill-task-attribution)
    (:bean-vocabulary      . fill-bean-vocabulary)
    (:model-recommendations . fill-model-recommendations)
    (:coordination-protocol . fill-coordination-protocol)
    (:build-test-commands  . fill-build-test-commands)
    (:review-criteria      . fill-review-criteria)
    (:severity-levels      . fill-severity-levels)
    (:verdict-format       . fill-verdict-format)
    (:blocker-description  . fill-blocker-description)
    (:available-resources  . fill-available-resources)
    (:suggested-paths      . fill-suggested-paths)
    (:fragment-journal     . fill-fragment-journal)
    (:resume-hint          . fill-resume-hint)
    (:value-captured       . fill-value-captured)
    (:aesthetic-brief      . fill-aesthetic-brief)
    (:visual-references    . fill-visual-references)
    (:constraints          . fill-constraints)
    (:cost-audit-request   . fill-cost-audit-request)
    (:resource-snapshot    . fill-resource-snapshot)
    (:budget               . fill-budget)
    (:task-batch           . fill-task-batch)
    (:roles-active         . fill-roles-active))
  "Maps slot keyword → filler function symbol.
Each filler takes (DIMENSIONS TASK-SPEC SQUAD-NAME) and returns a string.")

(defun %replace-all (string old new)
  "Replace every occurrence of OLD with NEW in STRING. Returns a new string."
  (let ((result string)
        (pos (search old string)))
    (loop while pos
          do (setf result (concatenate 'string
                                       (subseq result 0 pos)
                                       new
                                       (subseq result (+ pos (length old)))))
             (setf pos (search old result)))
    result))

(defun fill-bones (template dimensions &optional task-spec squad-name)
  "Fill all {{slot}} placeholders in TEMPLATE using bone fillers.
Returns the filled string with all slots replaced."
  (let ((result template))
    (dolist (entry *bone-fillers*)
      (let* ((slot-key (car entry))
             (filler (symbol-function (cdr entry)))
             (slot-name (format nil "{{~A}}"
                                (substitute #\- #\_
                                            (string-downcase
                                             (symbol-name slot-key)))))
             (value (handler-case
                        (funcall filler dimensions task-spec squad-name)
                      (error () "(fill failed)"))))
        (setf result (%replace-all result slot-name (or value "")))))
    result))

;;; --- Flesh pass ------------------------------------------------------------

(defparameter *flesh-model-chain*
  '((:name "deepseek-v4-flash-0731" :provider "openrouter" :est-cost 0.001)
    (:name "gpt-5.6-luna" :provider "openai" :est-cost 0.001)
    (:name "google/gemma-4-31b-it:free" :provider "openrouter" :est-cost 0)
    (:name "unsloth/Qwen-AgentWorld-35B-A3B-GGUF" :provider "unsloth-local" :est-cost 0))
  "Cheapest-first model chain for flesh pass. The last entry is local —
only used as a final fallback and only if the role allows local models.")

(defun local-model-p (model)
  "Return T when MODEL runs on local VRAM."
  (hngh.plugins.squad-resources:local-model-p model))

(defun should-flesh-p (dimensions model budget-remaining estimated-cost)
  "Return T when the flesh pass should run."
  (declare (ignore dimensions))
  (and
   ;; Not local model
   (not (local-model-p model))
   ;; Budget allows
   (and budget-remaining
        (> budget-remaining estimated-cost))
   ;; Not cache hit (checked by caller)
   t))

(defun select-flesh-model (budget-remaining)
  "Select the cheapest available non-local model for the flesh pass.
Returns a model spec plist or NIL."
  (loop for model in *flesh-model-chain*
        when (and (not (local-model-p (getf model :name)))
                  (or (null budget-remaining)
                      (> budget-remaining (getf model :est-cost))))
          return model
        finally (return nil)))

(defparameter *flesh-system-prompt*
  "You are a prompt editor. You receive a structured prompt assembled from
templates and context data. Your job: edit for coherence, tighten language,
add missing transitions, fix tone. DO NOT restructure the prompt. DO NOT
add new sections. DO NOT remove sections. Preserve all {{slot}} values that
have been filled — they are factual, not stylistic. Return only the edited
prompt text. No commentary.")

(defun count-section-headers (string)
  "Count '## ' section header lines in STRING."
  (loop for line in (hngh.plugins.agents-md::split-lines string)
        count (and (>= (length line) 4)
                   (string= "## " (subseq line 0 3))
                   (not (string= "### " (subseq line 0 4))))))

(defun count-top-headers (string)
  "Count top-level '# ' header lines in STRING (not '## ')."
  (loop for line in (hngh.plugins.agents-md::split-lines string)
        count (and (>= (length line) 3)
                   (string= "# " (subseq line 0 2))
                   (not (string= "## " (subseq line 0 3))))))

(defun validate-flesh-output (pre-flesh post-flesh)
  "Return T when POST-FLESH is an acceptable edit of PRE-FLESH."
  (and
   (stringp post-flesh)
   (> (length post-flesh) 0)
   ;; Section count preserved
   (= (count-section-headers pre-flesh)
      (count-section-headers post-flesh))
   ;; No new top-level headers
   (<= (count-top-headers post-flesh)
       (count-top-headers pre-flesh))
   ;; Not absurdly longer
   (< (length post-flesh) (* 2 (length pre-flesh)))))

(defun invoke-flesh-model (model-spec prompt-text)
  "Send PROMPT-TEXT to the model in MODEL-SPEC for editing.
Returns the edited text, or NIL if invocation fails."
  (declare (ignore model-spec))
  (handler-case
      (let ((inv (hngh.plugins.ai-tool-hub:invoke
                  nil prompt-text
                  :context (list :system-prompt *flesh-system-prompt*))))
        (getf (hngh.plugins.ai-tool-hub::invocation-info-result inv) :output))
    (error () nil)))

(defun run-flesh-pass (assembled-prompt dimensions model budget-remaining)
  "Run the LLM once-over on ASSEMBLED-PROMPT.
Returns the edited prompt string, or the original if flesh fails/is skipped."
  (declare (ignore dimensions model))
  (let ((flesh-model (select-flesh-model budget-remaining)))
    (if (null flesh-model)
        assembled-prompt  ; No model available — skip
        (let ((edited (invoke-flesh-model flesh-model assembled-prompt)))
          (if (validate-flesh-output assembled-prompt edited)
              edited
              (progn
                (hngh.core:log-warn "Flesh pass validation failed, using pre-flesh prompt")
                assembled-prompt))))))

;;; --- Prompt cache ----------------------------------------------------------

(defparameter *prompt-cache* (make-hash-table :test 'equal)
  "Cache of generated prompts keyed by dimension hash.")

(defun prompt-cache-key (dimensions task-spec squad-name)
  "Compute a cache key from DIMENSIONS, TASK-SPEC and SQUAD-NAME.
Returns a string suitable as a hash table key."
  (format nil "~A:~A:~A:~A:~A:~A:~A:~A"
          (prompt-dimensions-role dimensions)
          (prompt-dimensions-scenario dimensions)
          (prompt-dimensions-strategy dimensions)
          (prompt-dimensions-resources dimensions)
          (prompt-dimensions-lifetime dimensions)
          (prompt-dimensions-purpose dimensions)
          (or (getf task-spec :id) "")
          squad-name))

(defun cache-get (dimensions task-spec squad-name)
  "Return cached prompt for this dimension combo, or NIL."
  (gethash (prompt-cache-key dimensions task-spec squad-name) *prompt-cache*))

(defun cache-put (dimensions task-spec squad-name prompt)
  "Store PROMPT in the cache for this dimension combo."
  (setf (gethash (prompt-cache-key dimensions task-spec squad-name) *prompt-cache*)
        prompt))

(defun cache-clear ()
  "Clear the prompt cache."
  (clrhash *prompt-cache*))

;;; --- generate-prompt -------------------------------------------------------

(defun generate-prompt (dimensions &key (task-spec nil) (squad-name "squad")
                                       (budget-remaining nil) (force-flesh nil))
  "Procedurally assemble a role prompt from the prompt matrix.

DIMENSIONS — a prompt-dimensions struct with role, scenario, strategy,
  resources, squad-count, roles-active, lifetime, directory, system, purpose.
TASK-SPEC — optional plist with task details (:id, :title, :files, :acceptance,
  :preconditions, :review-criteria, :blocker, :fragment-journal-path, etc.).
  May be NIL for startup scenarios.
SQUAD-NAME — string, the squad identifier.
BUDGET-REMAINING — optional number, dollars remaining in daily budget.
  When NIL, flesh pass is skipped (no budget tracking).
FORCE-FLESH — when T, force the flesh pass even if cache-hit (for testing).

Returns a string containing the assembled prompt."
  (let* ((role (prompt-dimensions-role dimensions))
         (scenario (prompt-dimensions-scenario dimensions))
         (skeleton (or (get-skeleton role scenario)
                       (get-skeleton role :startup)
                       (get-skeleton :pm :startup)))
         (cached (and (not force-flesh) (cache-get dimensions task-spec squad-name))))
    (if cached
        cached
        (let* ((assembled (fill-bones skeleton dimensions task-spec squad-name))
               (model (select-role-model role dimensions))
               (model-name (getf model :name))
               (est-cost (if (and model-name budget-remaining)
                             (estimate-model-cost model role)
                             0.001))
               (fleshed (if (and model-name
                                 (should-flesh-p dimensions model-name
                                                 budget-remaining est-cost))
                            (run-flesh-pass assembled dimensions model
                                            budget-remaining)
                            assembled)))
          (cache-put dimensions task-spec squad-name fleshed)
          fleshed))))

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
